import '../../../../core/error/result.dart';
import '../entities/category_entity.dart';

abstract class CategoryRepository {
  /// Top-level categories only (parentCategoryId == null), active, sorted.
  Future<Result<List<CategoryEntity>>> getTopLevelCategories();

  /// Subcategories of a given parent category.
  Future<Result<List<CategoryEntity>>> getSubcategories(String parentCategoryId);

  Future<Result<CategoryEntity>> getCategoryById(String categoryId);
}
