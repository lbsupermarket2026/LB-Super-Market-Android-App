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
    String paymentMethod = 'cod',
    String? razorpayPaymentId,
  });

  Future<Result<void>> submitRating(String orderId, double rating, String? comment);

  Future<Result<void>> cancelOrder(String orderId);
}
