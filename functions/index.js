const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();

// Key ID isn't sensitive (it's already inside the Flutter app), so it's
// a plain param. Key SECRET must never appear in client code — this is
// the whole reason this function exists instead of calling Razorpay
// directly from Flutter. Set both via the deploy steps in the README.
const razorpayKeyId = defineString("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");

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
