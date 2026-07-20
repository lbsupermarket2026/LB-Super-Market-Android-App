import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../categories/data/models/category_model.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../../../../products/data/models/product_model.dart';
import '../../../../products/domain/entities/product_entity.dart';

class AdminInventoryDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AdminInventoryDataSource({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _categories => _firestore.collection('categories');
  CollectionReference<Map<String, dynamic>> get _products => _firestore.collection('products');

  Future<String> uploadImage(String folder, String id, File file) async {
    final ref = _storage.ref('$folder/$id.jpg');
    final snapshot = await ref.putFile(file);
    if (snapshot.state != TaskState.success) {
      throw Exception('Image upload did not complete (state: ${snapshot.state}).');
    }
    return snapshot.ref.getDownloadURL();
  }

  // ---------- Categories (admin sees ALL, including inactive) ----------

  Future<List<CategoryEntity>> getAllCategories() async {
    final snapshot = await _categories.get();
    final categories = snapshot.docs.map((d) => CategoryModel.fromFirestore(d).toEntity()).toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  Future<String> createCategory({required String name, String? imageUrl, int sortOrder = 0}) async {
    final docRef = await _categories.add({
      'name': name,
      'imageUrl': imageUrl,
      'iconUrl': null,
      'parentCategoryId': null,
      'sortOrder': sortOrder,
      'isActive': true,
    });
    return docRef.id;
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{'name': name};
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (sortOrder != null) updates['sortOrder'] = sortOrder;
    if (isActive != null) updates['isActive'] = isActive;
    await _categories.doc(id).update(updates);
  }

  Future<void> deleteCategory(String id) async {
    await _categories.doc(id).delete();
  }

  // ---------- Products (admin sees ALL, including inactive) ----------

  // No orderBy('createdAt') here deliberately — Firestore silently
  // excludes any document missing the sorted field entirely, and
  // products added manually via the console (or from before this field
  // existed) might not have it. Fetch everything, sort client-side
  // instead, so nothing silently vanishes from the admin's view.
  Future<List<ProductEntity>> getAllProducts() async {
    final snapshot = await _products.get();
    final products = snapshot.docs.map((d) => ProductModel.fromFirestore(d).toEntity()).toList();
    products.sort((a, b) => a.name.compareTo(b.name));
    return products;
  }

  Future<String> createProduct({
    required String name,
    String? description,
    String? brand,
    required String categoryId,
    String? thumbnailUrl,
    required double basePrice,
    double? mrp,
    double discountPercent = 0,
    required String unit,
    required int stockQty,
    int lowStockThreshold = 5,
    bool isFeatured = false,
    bool isTrending = false,
    bool isBestSeller = false,
    bool isActive = true,
  }) async {
    final docRef = await _products.add({
      'name': name,
      'description': description,
      'brand': brand,
      'categoryId': categoryId,
      'subCategoryId': null,
      'images': <String>[],
      'thumbnailUrl': thumbnailUrl,
      'basePrice': basePrice,
      'mrp': mrp,
      'discountPercent': discountPercent,
      'taxPercent': 0,
      'unit': unit,
      'variants': <Map<String, dynamic>>[],
      'stockQty': stockQty,
      'lowStockThreshold': lowStockThreshold,
      'isFeatured': isFeatured,
      'isTrending': isTrending,
      'isBestSeller': isBestSeller,
      'isActive': isActive,
      'ratingAvg': 0,
      'ratingCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    String? description,
    String? brand,
    required String categoryId,
    String? thumbnailUrl,
    required double basePrice,
    double? mrp,
    double discountPercent = 0,
    required String unit,
    required int stockQty,
    int lowStockThreshold = 5,
    bool isFeatured = false,
    bool isTrending = false,
    bool isBestSeller = false,
    bool isActive = true,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'description': description,
      'brand': brand,
      'categoryId': categoryId,
      'basePrice': basePrice,
      'mrp': mrp,
      'discountPercent': discountPercent,
      'unit': unit,
      'stockQty': stockQty,
      'lowStockThreshold': lowStockThreshold,
      'isFeatured': isFeatured,
      'isTrending': isTrending,
      'isBestSeller': isBestSeller,
      'isActive': isActive,
    };
    if (thumbnailUrl != null) updates['thumbnailUrl'] = thumbnailUrl;
    await _products.doc(id).update(updates);
  }

  Future<void> deleteProduct(String id) async {
    await _products.doc(id).delete();
  }
}
