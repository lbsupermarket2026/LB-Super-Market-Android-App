/// ============================================================
/// Going LIVE: replace razorpayKeyId below with your Live Key
/// (starts with rzp_live_...) from the Razorpay Dashboard.
///
/// Also update RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in your
/// deployed Cloud Functions to the LIVE pair too — the Key ID here
/// and the ones the functions use must match each other and must
/// both be Live, not a mix of test and live. See the functions
/// README for the exact commands.
///
/// Server-side order creation + payment verification (Cloud
/// Functions) are already wired in, so this is safe to flip to
/// live once both sides use the matching Live key pair.
/// ============================================================
class PaymentConfig {
  PaymentConfig._();

  static const String razorpayKeyId = 'rzp_test_TEXKRMkg62Lws0';

  // Checks the key actually looks like a real Razorpay key (correct
  // prefix + reasonable length) instead of comparing against a
  // placeholder string — comparing against a placeholder meant that
  // string had to appear twice in this file, and editing the key
  // value naturally means replacing every occurrence of it, which
  // silently broke this check the moment a real key was pasted in.
  static bool get isConfigured =>
      (razorpayKeyId.startsWith('rzp_test_') || razorpayKeyId.startsWith('rzp_live_')) && razorpayKeyId.length > 15;
}
