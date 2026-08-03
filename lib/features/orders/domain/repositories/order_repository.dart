import '../../../../core/error/result.dart';
import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<Result<List<OrderEntity>>> getMyOrders(String userId);

  Future<Result<OrderEntity>> getOrderById(String orderId);

  Future<Result<String>> createOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String deliveryAddress,
    String? customerPhone,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String paymentMethod = 'cod',
    String? razorpayPaymentId,
    bool paymentPending = false,
  });

  /// Clears paymentPending and attaches the real payment ID once
  /// Razorpay verification succeeds.
  Future<Result<void>> markPaymentConfirmed(String orderId, String razorpayPaymentId);

  Future<Result<void>> submitRating(String orderId, double rating, String? comment);

  Future<Result<void>> updateOrderItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String deliveryAddress,
  });

  Future<Result<void>> cancelOrder(String orderId);
}
