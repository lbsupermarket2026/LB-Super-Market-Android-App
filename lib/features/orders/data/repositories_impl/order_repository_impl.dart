import '../../../../core/error/result.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource _remote;
  const OrderRepositoryImpl(this._remote);

  @override
  Future<Result<List<OrderEntity>>> getMyOrders(String userId) {
    return guard(() async {
      final models = await _remote.getMyOrders(userId);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Result<OrderEntity>> getOrderById(String orderId) {
    return guard(() async {
      final model = await _remote.getOrderById(orderId);
      return model.toEntity();
    });
  }

  @override
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
  }) {
    return guard(() => _remote.createOrder(
          userId: userId,
          items: items,
          totalAmount: totalAmount,
          deliveryAddress: deliveryAddress,
          customerPhone: customerPhone,
          deliveryLatitude: deliveryLatitude,
          deliveryLongitude: deliveryLongitude,
          paymentMethod: paymentMethod,
          razorpayPaymentId: razorpayPaymentId,
          paymentPending: paymentPending,
        ));
  }

  @override
  Future<Result<void>> markPaymentConfirmed(String orderId, String razorpayPaymentId) {
    return guard(() => _remote.markPaymentConfirmed(orderId, razorpayPaymentId));
  }

  @override
  Future<Result<void>> submitRating(String orderId, double rating, String? comment) {
    return guard(() => _remote.submitRating(orderId, rating, comment));
  }

  @override
  Future<Result<void>> updateOrderItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String deliveryAddress,
  }) {
    return guard(() => _remote.updateOrderItems(
          orderId: orderId,
          items: items,
          totalAmount: totalAmount,
          deliveryAddress: deliveryAddress,
        ));
  }

  @override
  Future<Result<void>> cancelOrder(String orderId) {
    return guard(() => _remote.cancelOrder(orderId));
  }
}
