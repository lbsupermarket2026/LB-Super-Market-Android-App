import '../../../../core/error/result.dart';
import '../repositories/order_repository.dart';

class SubmitOrderRatingUseCase {
  final OrderRepository _repository;
  const SubmitOrderRatingUseCase(this._repository);

  Future<Result<void>> call(String orderId, double rating, String? comment) {
    return _repository.submitRating(orderId, rating, comment);
  }
}
