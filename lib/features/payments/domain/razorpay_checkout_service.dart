import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/config/payment_config.dart';

/// Thin wrapper around the Razorpay Flutter SDK. This is a client-side-only
/// integration (no backend order creation or signature verification) —
/// the right starting point to get UPI actually working in test mode
/// today. Before going live with real money, the honest next step is
/// adding a small server component (Cloud Function) that creates the
/// Razorpay Order and verifies the payment signature after success, so a
/// tampered client can't fake a successful payment. Fine to skip for
/// test-mode development; not fine to skip once real money is involved.
class RazorpayCheckoutService {
  final Razorpay _razorpay = Razorpay();

  void init({
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
    required void Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  /// [amountInRupees] gets converted to paise (Razorpay's smallest unit)
  /// internally — callers always pass a plain rupee amount.
  void openUpiCheckout({
    required double amountInRupees,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String description = 'FreshCart order',
  }) {
    final options = {
      'key': PaymentConfig.razorpayKeyId,
      'amount': (amountInRupees * 100).round(), // paise
      'name': 'LB Super Market',
      'description': description,
      'prefill': {
        'contact': customerPhone,
        'email': (customerEmail?.isNotEmpty == true) ? customerEmail : 'customer@lbsupermarket.com',
      },
      // Nudges Checkout to show UPI first, matching what this flow is
      // for — customer can still switch to another method on the sheet.
      'method': {'upi': true},
    };

    _razorpay.open(options);
  }

  void dispose() {
    _razorpay.clear();
  }
}
