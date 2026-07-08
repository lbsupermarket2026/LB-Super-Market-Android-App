import '../../../../core/error/result.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class GetOrderByIdUseCase {
  final OrderRepository _repository;
  const GetOrderByIdUseCase(this._repository);

  Future<Result<OrderEntity>> call(String orderId) => _repository.getOrderById(orderId);
}
