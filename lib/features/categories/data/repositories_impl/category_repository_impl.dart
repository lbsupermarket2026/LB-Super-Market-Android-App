import '../../../../core/error/result.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_datasource.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource _remote;
  const CategoryRepositoryImpl(this._remote);

  @override
  Future<Result<List<CategoryEntity>>> getTopLevelCategories() {
    return guard(() async {
      final models = await _remote.getTopLevelCategories();
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Result<List<CategoryEntity>>> getSubcategories(String parentCategoryId) {
    return guard(() async {
      final models = await _remote.getSubcategories(parentCategoryId);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Result<CategoryEntity>> getCategoryById(String categoryId) {
    return guard(() async {
      final model = await _remote.getCategoryById(categoryId);
      return model.toEntity();
    });
  }

  @override
  Future<Result<List<CategoryEntity>>> getCategoriesByOffer(String offerId) {
    return guard(() async {
      final models = await _remote.getCategoriesByOffer(offerId);
      return models.map((m) => m.toEntity()).toList();
    });
  }
}
