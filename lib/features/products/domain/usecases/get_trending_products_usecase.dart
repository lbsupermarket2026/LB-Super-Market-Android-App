import '../../../../core/error/result.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetTrendingProductsUseCase {
  final ProductRepository _repository;
  const GetTrendingProductsUseCase(this._repository);

  Future<Result<List<ProductEntity>>> call({int limit = 10}) => _repository.getTrendingProducts(limit: limit);
}
