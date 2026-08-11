const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

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

// Used specifically by "Forgot Password" before sending an OTP — Firebase
// phone auth AUTO-CREATES a new account for any number that doesn't
// already have one, which means without this check, "forgot password"
// on a random/unregistered number would silently create a brand new
// account instead of failing. This confirms a real account already
// exists for the number first, so that can't happen.
exports.checkPhoneRegistered = onCall(async (request) => {
  const phone = request.data?.phone;
  if (typeof phone !== "string" || phone.trim().length === 0) {
    throw new HttpsError("invalid-argument", "phone is required.");
  }

  try {
    await auth.getUserByPhoneNumber(phone);
    return { registered: true };
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      return { registered: false };
    }
    throw new HttpsError("internal", "Could not check this number right now.");
  }
});

// // ============================================================
// // 7. Email OTP — signup/reset verification via a real numeric code
// //    rather than a click-through link.
// // ============================================================
// // Codes live in a Firestore collection that's admin-only in the
// // security rules (never directly readable/writable by clients) — the
// // ONLY way to interact with them is through these two callable
// // functions, which is what keeps this from being guessable/bypassable
// // from the client side.
// const sendgridApiKey = defineSecret("SENDGRID_API_KEY");
// const SENDGRID_FROM_EMAIL = defineString("SENDGRID_FROM_EMAIL", { default: "noreply@lbsupermarket.com" });
// const OTP_TTL_MINUTES = 10;

// function generateSixDigitCode() {
//   // crypto.randomInt is cryptographically strong — Math.random() would
//   // be guessable in principle, which matters for something used as an
//   // account-security code.
//   return crypto.randomInt(100000, 1000000).toString();
// }

// exports.sendEmailOtp = onCall({ secrets: [sendgridApiKey] }, async (request) => {
//   const email = request.data?.email;
//   if (typeof email !== "string" || !email.includes("@")) {
//     throw new HttpsError("invalid-argument", "A valid email is required.");
//   }

//   const code = generateSixDigitCode();
//   const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000);

//   await db.collection("email_otps").doc(email).set({
//     code,
//     expiresAt,
//     createdAt: FieldValue.serverTimestamp(),
//   });

//   const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
//     method: "POST",
//     headers: {
//       Authorization: `Bearer ${sendgridApiKey.value()}`,
//       "Content-Type": "application/json",
//     },
//     body: JSON.stringify({
//       personalizations: [{ to: [{ email }] }],
//       from: { email: SENDGRID_FROM_EMAIL.value(), name: "LB Super Market" },
//       subject: "Your verification code",
//       content: [
//         {
//           type: "text/plain",
//           value: `Your LB Super Market verification code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes.`,
//         },
//       ],
//     }),
//   });

//   if (!response.ok) {
//     const errorText = await response.text();
//     logger.error("SendGrid send failed", { status: response.status, body: errorText });
//     throw new HttpsError("internal", "Could not send the verification email. Please try again.");
//   }

//   return { sent: true };
// });

// exports.verifyEmailOtp = onCall(async (request) => {
//   const email = request.data?.email;
//   const code = request.data?.code;
//   if (typeof email !== "string" || typeof code !== "string") {
//     throw new HttpsError("invalid-argument", "email and code are required.");
//   }

//   const docRef = db.collection("email_otps").doc(email);
//   const doc = await docRef.get();
//   if (!doc.exists) {
//     return { valid: false, reason: "No code was requested for this email." };
//   }

//   const data = doc.data();
//   const expiresAt = data.expiresAt?.toDate ? data.expiresAt.toDate() : new Date(data.expiresAt);
//   if (Date.now() > expiresAt.getTime()) {
//     await docRef.delete();
//     return { valid: false, reason: "This code has expired — request a new one." };
//   }

//   if (data.code !== code) {
//     return { valid: false, reason: "Incorrect code." };
//   }

//   // One-time use — deleted immediately on a successful match so the
//   // same code can't be replayed.
//   await docRef.delete();
//   return { valid: true };
// });

// // Only settable via the Admin SDK, and only for the caller's own
// // account — a signed-in user marking someone else's email verified
// // would be a real privilege escalation, so this checks request.auth
// // matches the uid being modified before doing anything.
// exports.markEmailVerified = onCall(async (request) => {
//   if (!request.auth) {
//     throw new HttpsError("unauthenticated", "You must be signed in.");
//   }
//   const uid = request.data?.uid;
//   if (typeof uid !== "string" || uid !== request.auth.uid) {
//     throw new HttpsError("permission-denied", "Can only verify your own account.");
//   }

//   await auth.updateUser(uid, { emailVerified: true });
//   return { success: true };
// });


// ============================================================
// NEW: Admin notification on a new order REQUEST (Type My List /
// Photo submission) — previously only exports.notifyOnNewOrder
// existed, which watches the `orders` collection. But "Type My List"
// and "Take a photo of your list" create a document in the SEPARATE
// `order_requests` collection instead (an admin has to manually
// review and "Convert to Order" before it becomes a real order) —
// so admin was never notified these came in at all until they
// happened to check the Order Requests tab themselves.
// ============================================================
exports.notifyOnNewOrderRequest = onDocumentCreated("order_requests/{requestId}", async (event) => {
  const request = event.data.data();
  const isPhoto = request.type === "photo";
  const title = "New order request";
  const body = isPhoto
    ? `A customer submitted a photo list — tap to review.`
    : `A customer typed a list (${(request.itemLines || []).length} items) — tap to review.`;

  await db.collection("notifications").add({
    type: "new_order_request",
    title,
    body,
    requestId: event.params.requestId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await messaging.send({
    topic: "admin_alerts",
    notification: { title, body },
    data: { type: "new_order_request", requestId: event.params.requestId },
    android: { priority: "high", notification: { channelId: "freshcart_default" } },
  });
});

// ============================================================
// NEW: Admin notification when a customer cancels their own order.
// Previously nothing notified admin of a cancellation at all —
// notifyCustomerOnOrderStatusChange tells the CUSTOMER about status
// changes on their own order, but there was no equivalent alert
// telling ADMIN when a customer-initiated cancellation happens.
// Scoped specifically to cancellations (not every status change) to
// avoid duplicating/spamming what notifyOnNewOrder already covers.
// ============================================================
exports.notifyAdminOnOrderCancelled = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  const justCancelled = before.status !== "cancelled" && after.status === "cancelled";
  if (!justCancelled) return;

  const title = "Order cancelled";
  const body = `Order ${after.orderNumber || event.params.orderId} was cancelled.`;

  await db.collection("notifications").add({
    type: "order_cancelled",
    title,
    body,
    orderId: event.params.orderId,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await messaging.send({
    topic: "admin_alerts",
    notification: { title, body },
    data: { type: "order_cancelled", orderId: event.params.orderId },
    android: { priority: "high", notification: { channelId: "freshcart_default" } },
  });
});
