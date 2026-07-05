import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/result.dart';
import '../repositories/product_repository.dart';

class GetProductsByCategoryUseCase {
  final ProductRepository _repository;
  const GetProductsByCategoryUseCase(this._repository);

  Future<Result<ProductPage>> call({
    required String categoryId,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    return _repository.getProductsByCategory(categoryId: categoryId, limit: limit, startAfter: startAfter);
  }
}
