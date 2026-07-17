/// ============================================================
/// Razorpay test key is already set below. When you're ready to
/// accept real money later: complete Razorpay's KYC/activation,
/// generate a Live Key (starts with rzp_live_...), and swap it in
/// here instead.
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
