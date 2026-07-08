import '../../../../core/error/result.dart';
import '../repositories/product_repository.dart';

class GetCategoryProductCountUseCase {
  final ProductRepository _repository;
  const GetCategoryProductCountUseCase(this._repository);

  Future<Result<int>> call(String categoryId) => _repository.getProductCountForCategory(categoryId);
}
