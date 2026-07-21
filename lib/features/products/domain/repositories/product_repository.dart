import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/result.dart';
import '../entities/product_entity.dart';

/// Wraps a page of results plus the last document cursor, so the caller
/// (ViewModel) can request the next page without the domain layer ever
/// exposing a raw Firestore type beyond this cursor pass-through.
class ProductPage {
  final List<ProductEntity> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const ProductPage({required this.items, this.lastDocument, this.hasMore = false});
}

abstract class ProductRepository {
  Future<Result<List<ProductEntity>>> getFeaturedProducts({int limit = 10});
  Future<Result<List<ProductEntity>>> getTrendingProducts({int limit = 10});
  Future<Result<List<ProductEntity>>> getBestSellers({int limit = 10});

  Future<Result<ProductPage>> getProductsByCategory({
    required String categoryId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  });

  Future<Result<ProductEntity>> getProductById(String productId);

  Future<Result<int>> getProductCountForCategory(String categoryId);

  Future<Result<ProductPage>> getAllProducts({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  });

  Future<Result<List<ProductEntity>>> searchProducts(String query, {int limit = 20});

  Future<Result<List<ProductEntity>>> getProductsByOffer(String offerId);
}
