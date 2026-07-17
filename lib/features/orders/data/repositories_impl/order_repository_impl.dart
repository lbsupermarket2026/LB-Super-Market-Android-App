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
    String paymentMethod = 'cod',
    String? razorpayPaymentId,
  }) {
    return guard(() => _remote.createOrder(
          userId: userId,
          items: items,
          totalAmount: totalAmount,
          deliveryAddress: deliveryAddress,
          customerPhone: customerPhone,
          paymentMethod: paymentMethod,
          razorpayPaymentId: razorpayPaymentId,
        ));
  }

  @override
  Future<Result<void>> submitRating(String orderId, double rating, String? comment) {
    return guard(() => _remote.submitRating(orderId, rating, comment));
  }

  @override
  Future<Result<void>> cancelOrder(String orderId) {
    return guard(() => _remote.cancelOrder(orderId));
  }
}
