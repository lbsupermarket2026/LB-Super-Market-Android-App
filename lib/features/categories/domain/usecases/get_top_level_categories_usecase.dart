import '../../../../core/error/result.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class GetTopLevelCategoriesUseCase {
  final CategoryRepository _repository;
  const GetTopLevelCategoriesUseCase(this._repository);

  Future<Result<List<CategoryEntity>>> call() => _repository.getTopLevelCategories();
}
