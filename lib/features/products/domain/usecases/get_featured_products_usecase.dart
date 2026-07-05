import '../../../../core/error/result.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetFeaturedProductsUseCase {
  final ProductRepository _repository;
  const GetFeaturedProductsUseCase(this._repository);

  Future<Result<List<ProductEntity>>> call({int limit = 10}) => _repository.getFeaturedProducts(limit: limit);
}
