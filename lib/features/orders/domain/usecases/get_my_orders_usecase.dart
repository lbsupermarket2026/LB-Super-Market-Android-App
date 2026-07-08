import '../../../../core/error/result.dart';
import '../entities/order_entity.dart';
import '../repositories/order_repository.dart';

class GetMyOrdersUseCase {
  final OrderRepository _repository;
  const GetMyOrdersUseCase(this._repository);

  Future<Result<List<OrderEntity>>> call(String userId) => _repository.getMyOrders(userId);
}
