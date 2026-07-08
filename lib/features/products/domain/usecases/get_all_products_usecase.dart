import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/result.dart';
import '../repositories/product_repository.dart';

class GetAllProductsUseCase {
  final ProductRepository _repository;
  const GetAllProductsUseCase(this._repository);

  Future<Result<ProductPage>> call({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    return _repository.getAllProducts(limit: limit, startAfter: startAfter);
  }
}
