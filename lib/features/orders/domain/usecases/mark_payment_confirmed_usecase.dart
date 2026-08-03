import '../../../../core/error/result.dart';
import '../repositories/order_repository.dart';

class MarkPaymentConfirmedUseCase {
  final OrderRepository _repository;
  const MarkPaymentConfirmedUseCase(this._repository);

  Future<Result<void>> call(String orderId, String razorpayPaymentId) {
    return _repository.markPaymentConfirmed(orderId, razorpayPaymentId);
  }
}
