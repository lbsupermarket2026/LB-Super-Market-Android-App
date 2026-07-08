import '../../../../core/error/result.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource _remote;
  const ProductRepositoryImpl(this._remote);

  @override
  Future<Result<List<ProductEntity>>> getFeaturedProducts({int limit = 10}) {
    return guard(() async {
      final models = await _remote.getFeaturedProducts(limit: limit);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Result<List<ProductEntity>>> getTrendingProducts({int limit = 10}) {
    return guard(() async {
      final models = await _remote.getTrendingProducts(limit: limit);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Result<List<ProductEntity>>> getBestSellers({int limit = 10}) {
    return guard(() async {
      final models = await _remote.getBestSellers(limit: limit);
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Result<ProductPage>> getProductsByCategory({
    required String categoryId,
    int limit = 20,
    startAfter,
  }) {
    return guard(() async {
      final result = await _remote.getProductsByCategory(categoryId: categoryId, limit: limit, startAfter: startAfter);
      return ProductPage(
        items: result.items.map((m) => m.toEntity()).toList(),
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
      );
    });
  }

  @override
  Future<Result<ProductEntity>> getProductById(String productId) {
    return guard(() async {
      final model = await _remote.getProductById(productId);
      return model.toEntity();
    });
  }

  @override
  Future<Result<int>> getProductCountForCategory(String categoryId) {
    return guard(() => _remote.getProductCountForCategory(categoryId));
  }

  @override
  Future<Result<ProductPage>> getAllProducts({
    int limit = 20,
    startAfter,
  }) {
    return guard(() async {
      final result = await _remote.getAllProducts(limit: limit, startAfter: startAfter);
      return ProductPage(
        items: result.items.map((m) => m.toEntity()).toList(),
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
      );
    });
  }

  @override
  Future<Result<List<ProductEntity>>> searchProducts(String query, {int limit = 20}) {
    return guard(() async {
      final models = await _remote.searchProducts(query, limit: limit);
      return models.map((m) => m.toEntity()).toList();
    });
  }
}
