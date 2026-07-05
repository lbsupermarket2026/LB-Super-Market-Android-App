import '../../../../core/error/result.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class GetSubcategoriesUseCase {
  final CategoryRepository _repository;
  const GetSubcategoriesUseCase(this._repository);

  Future<Result<List<CategoryEntity>>> call(String parentCategoryId) =>
      _repository.getSubcategories(parentCategoryId);
}
