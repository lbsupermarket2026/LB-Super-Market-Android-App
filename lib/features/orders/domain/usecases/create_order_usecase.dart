import '../../../../core/error/result.dart';
import '../repositories/order_repository.dart';

class CreateOrderUseCase {
  final OrderRepository _repository;
  const CreateOrderUseCase(this._repository);

  Future<Result<String>> call({
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
    return _repository.createOrder(
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
    );
  }
}
