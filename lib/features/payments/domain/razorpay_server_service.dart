import 'package:cloud_functions/cloud_functions.dart';

/// Calls the two server-side payment functions — createRazorpayOrder and
/// verifyRazorpayPayment (see functions/index.js). Neither the Razorpay
/// Key Secret nor any signature-checking logic lives in the app; both
/// happen on the server, which is what keeps a modified client from
/// being able to fake a successful payment.
class RazorpayServerService {
  final FirebaseFunctions _functions;
  RazorpayServerService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  /// Returns the Razorpay order_id to pass into checkout. Throws if the
  /// call fails — callers should treat that as "can't proceed with UPI
  /// right now" rather than silently falling back to an unprotected flow.
  Future<String> createOrder(double amountInRupees) async {
    final callable = _functions.httpsCallable('createRazorpayOrder');
    final result = await callable.call({'amountInRupees': amountInRupees});
    final orderId = result.data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) {
      throw Exception('Server did not return a payment order id.');
    }
    return orderId;
  }

  /// Returns true only if the server independently recomputed the
  /// signature and it matched — this is the actual proof the payment
  /// is genuine, not just something the client is claiming happened.
  Future<bool> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final callable = _functions.httpsCallable('verifyRazorpayPayment');
    final result = await callable.call({
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
    return result.data['verified'] as bool? ?? false;
  }
}
