import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../models/category_model.dart';

class CategoryRemoteDataSource {
  final FirebaseFirestore _firestore;
  CategoryRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.categories);

  /// Categories are modeled flat (parentCategoryId field, not a subcollection)
  /// per the final schema — null parentCategoryId means top-level.
  Future<List<CategoryModel>> getTopLevelCategories() async {
    final snapshot = await _collection
        .where('parentCategoryId', isNull: true)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .get();
    return snapshot.docs.map(CategoryModel.fromFirestore).toList();
  }

  Future<List<CategoryModel>> getSubcategories(String parentCategoryId) async {
    final snapshot = await _collection
        .where('parentCategoryId', isEqualTo: parentCategoryId)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .get();
    return snapshot.docs.map(CategoryModel.fromFirestore).toList();
  }

  Future<CategoryModel> getCategoryById(String categoryId) async {
    final doc = await _collection.doc(categoryId).get();
    if (!doc.exists) {
      throw const NotFoundException('Category not found.');
    }
    return CategoryModel.fromFirestore(doc);
  }

  /// No orderBy — single equality filter avoids needing a composite
  /// index, sorted client-side instead.
  Future<List<CategoryModel>> getCategoriesByOffer(String offerId) async {
    final snapshot = await _collection.where('offerId', isEqualTo: offerId).get();
    final categories = snapshot.docs.map(CategoryModel.fromFirestore).where((c) => c.isActive).toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }
}
