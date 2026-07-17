import '../../../../core/error/result.dart';
import '../repositories/order_repository.dart';

class CancelOrderUseCase {
  final OrderRepository _repository;
  const CancelOrderUseCase(this._repository);

  Future<Result<void>> call(String orderId) => _repository.cancelOrder(orderId);
}
