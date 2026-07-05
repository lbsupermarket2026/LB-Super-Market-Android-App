import '../../../../core/error/result.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetBestSellersUseCase {
  final ProductRepository _repository;
  const GetBestSellersUseCase(this._repository);

  Future<Result<List<ProductEntity>>> call({int limit = 10}) => _repository.getBestSellers(limit: limit);
}
