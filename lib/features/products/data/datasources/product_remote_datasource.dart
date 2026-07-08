import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../models/product_model.dart';

class ProductRemoteDataSource {
  final FirebaseFirestore _firestore;
  ProductRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.products);

  /// Each home-page section is a single small, indexed query — never a
  /// full collection scan — per the performance strategy in the
  /// architecture doc. Requires a composite index on
  /// (isFeatured/isTrending/isBestSeller + isActive), predefined in
  /// firestore.indexes.json.
  Future<List<ProductModel>> getFeaturedProducts({int limit = 10}) async {
    final snapshot = await _collection
        .where('isFeatured', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(ProductModel.fromFirestore).toList();
  }

  Future<List<ProductModel>> getTrendingProducts({int limit = 10}) async {
    final snapshot = await _collection
        .where('isTrending', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(ProductModel.fromFirestore).toList();
  }

  Future<List<ProductModel>> getBestSellers({int limit = 10}) async {
    final snapshot = await _collection
        .where('isBestSeller', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(ProductModel.fromFirestore).toList();
  }

  /// Cursor-based pagination — never fetch a full category's products
  /// in one go. Caller passes the last DocumentSnapshot from the
  /// previous page to get the next one.
  Future<({List<ProductModel> items, DocumentSnapshot<Map<String, dynamic>>? lastDoc, bool hasMore})>
      getProductsByCategory({
    required String categoryId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _collection
        .where('categoryId', isEqualTo: categoryId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final items = snapshot.docs.map(ProductModel.fromFirestore).toList();
    return (
      items: items,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<ProductModel> getProductById(String productId) async {
    final doc = await _collection.doc(productId).get();
    if (!doc.exists) {
      throw const NotFoundException('Product not found.');
    }
    return ProductModel.fromFirestore(doc);
  }

  /// Uses a server-side aggregate count instead of fetching every document —
  /// cheap regardless of how many products are in the category, and exactly
  /// what the Categories grid's "N items" label needs.
  Future<int> getProductCountForCategory(String categoryId) async {
    final query = _collection.where('categoryId', isEqualTo: categoryId).where('isActive', isEqualTo: true);
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  /// Same cursor-based pagination as getProductsByCategory, just without
  /// the categoryId filter — powers the "All" tab in Browse.
  Future<({List<ProductModel> items, DocumentSnapshot<Map<String, dynamic>>? lastDoc, bool hasMore})>
      getAllProducts({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query =
        _collection.where('isActive', isEqualTo: true).orderBy('createdAt', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final items = snapshot.docs.map(ProductModel.fromFirestore).toList();
    return (
      items: items,
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  /// Simple prefix/keyword search against the denormalized
  /// `searchKeywords` array field (see final schema §4). Sufficient for
  /// exact-token matching; if fuzzy/typo-tolerant search is needed later,
  /// that's the point to bring in Algolia/Typesense as flagged during
  /// architecture planning — this stays as the Firestore-native fallback.
  Future<List<ProductModel>> searchProducts(String query, {int limit = 20}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .where('searchKeywords', arrayContains: normalized)
        .limit(limit)
        .get();
    return snapshot.docs.map(ProductModel.fromFirestore).toList();
  }
}
