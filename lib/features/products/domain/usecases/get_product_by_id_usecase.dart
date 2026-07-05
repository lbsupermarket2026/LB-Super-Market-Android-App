import '../../../../core/error/result.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetProductByIdUseCase {
  final ProductRepository _repository;
  const GetProductByIdUseCase(this._repository);

  Future<Result<ProductEntity>> call(String productId) => _repository.getProductById(productId);
}
