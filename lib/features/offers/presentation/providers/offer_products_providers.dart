import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/category_providers.dart';

final productsByOfferProvider = FutureProvider.autoDispose.family<List<ProductEntity>, String>((ref, offerId) async {
  final result = await ref.watch(productRepositoryProvider).getProductsByOffer(offerId);
  return result.match((failure) => throw failure, (products) => products);
});

final categoriesByOfferProvider =
    FutureProvider.autoDispose.family<List<CategoryEntity>, String>((ref, offerId) async {
  final result = await ref.watch(categoryRepositoryProvider).getCategoriesByOffer(offerId);
  return result.match((failure) => throw failure, (categories) => categories);
});
