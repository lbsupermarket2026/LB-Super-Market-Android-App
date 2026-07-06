import '../../../../core/error/result.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class SearchProductsUseCase {
  final ProductRepository _repository;
  const SearchProductsUseCase(this._repository);

  Future<Result<List<ProductEntity>>> call(String query, {int limit = 20}) =>
      _repository.searchProducts(query, limit: limit);
}
