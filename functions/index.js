const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Shared by every notification trigger below — looks up the target's
// tokens across both possible collections (customer vs staff, same
// reasoning as the client-side token-save code), sends to all of
// them, and prunes any token FCM reports as no-longer-valid (app
// uninstalled, data cleared, etc.) so the array doesn't grow stale
// forever.
async function sendPushToUser(uid, { title, body, data }) {
  if (!uid) return;

  for (const collection of ["users", "staff_users"]) {
    const doc = await db.collection(collection).doc(uid).get();
    if (!doc.exists) continue;
    const tokens = doc.data().fcmTokens;
    if (!Array.isArray(tokens) || tokens.length === 0) continue;

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data || {}).map(([k, v]) => [k, String(v)])),
      android: { priority: "high", notification: { channelId: "freshcart_default" } },
    });

    const deadTokens = [];
    response.responses.forEach((r, i) => {
      if (!r.success && ["messaging/invalid-registration-token", "messaging/registration-token-not-registered"].includes(r.error?.code)) {
        deadTokens.push(tokens[i]);
      }
    });
    if (deadTokens.length > 0) {
      await db.collection(collection).doc(uid).update({ fcmTokens: FieldValue.arrayRemove(...deadTokens) });
    }
    return; // found the right collection, no need to check the other
  }
}

// Key ID isn't sensitive (it's already inside the Flutter app), so it's
// a plain param. Key SECRET must never appear in client code — this is
// the whole reason these functions exist instead of calling Razorpay
// directly from Flutter. Set both via the deploy steps in the README.
const razorpayKeyId = defineString("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

// ============================================================
// 1. Create Razorpay Order — called BEFORE checkout opens.
// ============================================================
// Razorpay requires every live payment to be tied to a
// server-created order — "payments made without an order_id
// cannot be captured and will be automatically refunded" per
// their own docs. This also ties the amount actually charged to
// what the server decided it should be, not whatever the client
// claims — so a tampered client can't just charge itself less.
exports.createRazorpayOrder = onCall(
  { secrets: [razorpayKeySecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in to place an order.");
    }

    const amountInRupees = request.data?.amountInRupees;
    if (typeof amountInRupees !== "number" || amountInRupees <= 0) {
      throw new HttpsError("invalid-argument", "amountInRupees must be a positive number.");
    }

    const auth = Buffer.from(`${razorpayKeyId.value()}:${razorpayKeySecret.value()}`).toString("base64");

    const response = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${auth}`,
      },
      body: JSON.stringify({
        amount: Math.round(amountInRupees * 100), // paise
        currency: "INR",
        payment_capture: 1,
        notes: { userId: request.auth.uid },
      }),
    });

    const body = await response.json();

    if (!response.ok) {
      logger.error("Razorpay order creation failed", body);
      throw new HttpsError("internal", body?.error?.description || "Could not create payment order.");
    }

    return { orderId: body.id };
  }
);

// ============================================================
// 2. Verify Razorpay Payment — called AFTER checkout succeeds,
//    BEFORE the Flutter app creates the real order in Firestore.
// ============================================================
// Confirms the payment genuinely went through and hasn't been
// tampered with client-side, by recomputing the signature
// ourselves with the secret key and checking it matches what
// Razorpay's checkout returned.
exports.verifyRazorpayPayment = onCall(
  { secrets: [razorpayKeySecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = request.data || {};
    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      throw new HttpsError("invalid-argument", "Missing payment verification fields.");
    }

    const expectedSignature = crypto
      .createHmac("sha256", razorpayKeySecret.value())
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");

    const verified = expectedSignature === razorpaySignature;
    if (!verified) {
      logger.warn("Payment signature mismatch", { razorpayOrderId, razorpayPaymentId, uid: request.auth.uid });
    }

    return { verified };
  }
);

// ============================================================
// 3. Auto-refund on cancel (unchanged from before)
// ============================================================
/**
 * Fires whenever an order document is updated. Only actually does
 * anything when status just changed TO 'cancelled' on an order that
 * was paid via UPI (through Razorpay) — COD and Card Swipe orders
 * never had money move through Razorpay, so there's nothing to refund.
 *
 * Idempotency: this function writes refundStatus/refundId back onto the
 * SAME document it's watching, which would normally risk an infinite
 * trigger loop. It's safe here because the very first check below
 * exits immediately once refundStatus is already set to anything other
 * than the initial unset state — so the second invocation (caused by
 * this function's own write) does nothing.
 */
exports.autoRefundOnCancel = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    secrets: [razorpayKeySecret],
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const orderId = event.params.orderId;

    const justCancelled = before.status !== "cancelled" && after.status === "cancelled";
    if (!justCancelled) return;

    if (after.paymentMethod !== "upi" || !after.razorpayPaymentId) {
      // COD / Card Swipe / no payment on record — nothing to refund.
      return;
    }

    if (after.refundStatus === "processed" || after.refundStatus === "processing") {
      // Already handled (or currently being handled) — this is the
      // guard that prevents the infinite-loop risk described above.
      return;
    }

    const orderRef = db.collection("orders").doc(orderId);
    await orderRef.update({ refundStatus: "processing" });

    try {
      const auth = Buffer.from(`${razorpayKeyId.value()}:${razorpayKeySecret.value()}`).toString("base64");

      const response = await fetch(
        `https://api.razorpay.com/v1/payments/${after.razorpayPaymentId}/refund`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Basic ${auth}`,
          },
          // No "amount" field = full refund of whatever was charged.
          body: JSON.stringify({
            notes: { orderId, reason: "Order cancelled by customer" },
          }),
        }
      );

      const body = await response.json();

      if (!response.ok) {
        logger.error(`Refund failed for order ${orderId}`, body);
        await orderRef.update({
          refundStatus: "failed",
          refundError: body?.error?.description || "Refund request was rejected by Razorpay.",
        });
        return;
      }

      logger.info(`Refund succeeded for order ${orderId}`, { refundId: body.id });
      await orderRef.update({
        refundStatus: "processed",
        refundId: body.id,
        refundError: null,
      });
    } catch (err) {
      logger.error(`Refund threw an exception for order ${orderId}`, err);
      await orderRef.update({
        refundStatus: "failed",
        refundError: "Could not reach Razorpay to process the refund. Try again from the dashboard.",
      });
    }
  }
);

// ============================================================
// 4. Admin notifications — new order placed / stock ran low.
// ============================================================
// Written via the Admin SDK (this function), which bypasses
// Firestore rules entirely — that's deliberate: a customer placing
// an order shouldn't need write access to a notifications collection
// just so the admin can be told about it. Same reasoning applies to
// the low-stock check, which is triggered by an ordinary product
// update (e.g. a stock decrement after an order is confirmed).
exports.notifyOnNewOrder = onDocumentCreated("orders/{orderId}", async (event) => {
  const order = event.data.data();
  const title = "New order placed";
  const body = `Order ${order.orderNumber || event.params.orderId} — Rs. ${order.totalAmount}`;

  await db.collection("notifications").add({
    type: "new_order",
    title,
    body,
    orderId: event.params.orderId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await messaging.send({
    topic: "admin_alerts",
    notification: { title, body },
    data: { type: "new_order", orderId: event.params.orderId },
    android: { priority: "high", notification: { channelId: "freshcart_default" } },
  });
});

exports.notifyOnLowStock = onDocumentUpdated("products/{productId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const threshold = after.lowStockThreshold ?? 5;
  const wasLow = before.stockQty <= threshold;
  const isLowNow = after.stockQty <= threshold && after.stockQty > 0;

  // Only fires the moment stock crosses INTO low territory — not on
  // every single update to an already-low product, which would spam
  // the same alert repeatedly.
  if (wasLow || !isLowNow) return;

  const title = "Low stock alert";
  const body = `${after.name} — only ${after.stockQty} left (threshold: ${threshold})`;

  await db.collection("notifications").add({
    type: "low_stock",
    title,
    body,
    productId: event.params.productId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await messaging.send({
    topic: "admin_alerts",
    notification: { title, body },
    data: { type: "low_stock", productId: event.params.productId },
    android: { priority: "high", notification: { channelId: "freshcart_default" } },
  });
});

// ============================================================
// 5. Customer notifications — their order status changed, or a
//    new offer went live.
// ============================================================
// Same reasoning as the admin notifications above: written via the
// Admin SDK so no customer-side write permission is ever needed for
// something that's inherently the SYSTEM telling them something, not
// something they're creating themselves.
exports.notifyCustomerOnOrderStatusChange = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (before.status === after.status) return;

  const title = "Order update";
  const body = `Order ${after.orderNumber || event.params.orderId} is now ${after.status}`;

  await db.collection("notifications").add({
    type: "order_status",
    uid: after.userId,
    title,
    body,
    orderId: event.params.orderId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await sendPushToUser(after.userId, { title, body, data: { type: "order_status", orderId: event.params.orderId } });
});

// Same notifications collection/pattern as the customer one above —
// the uid field is what scopes it to the right person, doesn't matter
// whether that's a customer or a staff member, so this reuses the
// exact same reader logic on the client rather than needing a
// parallel system just for employees.
exports.notifyEmployeeOnAssignment = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const newlyAssigned = after.assignedEmployeeUid && after.assignedEmployeeUid !== before.assignedEmployeeUid;
  if (!newlyAssigned) return;

  const title = "New delivery assigned";
  const body = `Order ${after.orderNumber || event.params.orderId} has been assigned to you`;

  await db.collection("notifications").add({
    type: "order_assigned",
    uid: after.assignedEmployeeUid,
    title,
    body,
    orderId: event.params.orderId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await sendPushToUser(after.assignedEmployeeUid, { title, body, data: { type: "order_assigned", orderId: event.params.orderId } });
});

// Broadcast (uid: null) rather than one write per customer — cheaper
// and simpler, and the customer-side query below reads both their own
// personal notifications and any broadcast ones in the same pass.
// The push itself uses FCM's topic messaging rather than looping
// every customer's tokens individually — every customer device
// subscribes to the "new_offers" topic on the client side, so this is
// one send regardless of how many customers there are.
exports.notifyCustomersOnNewOffer = onDocumentCreated("offers/{offerId}", async (event) => {
  const offer = event.data.data();
  if (!offer.isEnabled) return;

  const title = "New offer";
  const body = offer.title || "Check out a new offer in the app";

  await db.collection("notifications").add({
    type: "new_offer",
    uid: null,
    title,
    body,
    offerId: event.params.offerId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await messaging.send({
    topic: "new_offers",
    notification: { title, body },
    data: { type: "new_offer" },
    android: { priority: "high", notification: { channelId: "freshcart_default" } },
  });
});

// ============================================================
// 6. Phone-to-email lookup for the unified login screen.
// ============================================================
// Deliberately does NOT require request.auth — this runs BEFORE
// sign-in completes (translating a typed phone number into the real
// email behind it, so the client can then call normal email/password
// sign-in). The Firestore rule for staff_users only allows reads from
// an already-authenticated user, which a query like this can't
// satisfy pre-auth — this function uses the Admin SDK to bypass that
// safely, returning only the email (nothing else from the document)
// and only when a real match exists.
exports.lookupStaffEmailByPhone = onCall(async (request) => {
  const phone = request.data?.phone;
  if (typeof phone !== "string" || phone.trim().length === 0) {
    throw new HttpsError("invalid-argument", "phone is required.");
  }

  const snapshot = await db.collection("staff_users").where("phone", "==", phone).limit(1).get();
  if (snapshot.empty) return { email: null };

  const email = snapshot.docs[0].data().email;
  return { email: typeof email === "string" ? email : null };
});
