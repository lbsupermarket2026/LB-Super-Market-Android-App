import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/config/payment_config.dart';

/// Thin wrapper around the Razorpay Flutter SDK. The order_id passed
/// into checkout comes from a server-created Razorpay Order (see
/// RazorpayServerService) — Razorpay ties the payment to that specific
/// order, which is what makes it tamper-resistant: a modified client
/// can't just claim a different amount was paid, since the order
/// (and its amount) was decided server-side before checkout even opened.
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
  /// internally — callers always pass a plain rupee amount. [orderId]
  /// is the id returned by RazorpayServerService.createOrder — required
  /// now, since Razorpay auto-refunds any live payment that isn't tied
  /// to a server-created order.
  void openUpiCheckout({
    required double amountInRupees,
    required String orderId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String description = 'FreshCart order',
  }) {
    final options = {
      'key': PaymentConfig.razorpayKeyId,
      'amount': (amountInRupees * 100).round(), // paise
      'order_id': orderId,
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
