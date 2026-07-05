import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/repositories_impl/product_repository_impl.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/get_featured_products_usecase.dart';
import '../../domain/usecases/get_trending_products_usecase.dart';
import '../../domain/usecases/get_best_sellers_usecase.dart';
import '../../domain/usecases/get_products_by_category_usecase.dart';
import '../../domain/usecases/get_product_by_id_usecase.dart';

final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>((ref) {
  return ProductRemoteDataSource();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(ref.watch(productRemoteDataSourceProvider));
});

final getFeaturedProductsUseCaseProvider = Provider<GetFeaturedProductsUseCase>((ref) {
  return GetFeaturedProductsUseCase(ref.watch(productRepositoryProvider));
});

final getTrendingProductsUseCaseProvider = Provider<GetTrendingProductsUseCase>((ref) {
  return GetTrendingProductsUseCase(ref.watch(productRepositoryProvider));
});

final getBestSellersUseCaseProvider = Provider<GetBestSellersUseCase>((ref) {
  return GetBestSellersUseCase(ref.watch(productRepositoryProvider));
});

final getProductsByCategoryUseCaseProvider = Provider<GetProductsByCategoryUseCase>((ref) {
  return GetProductsByCategoryUseCase(ref.watch(productRepositoryProvider));
});

final getProductByIdUseCaseProvider = Provider<GetProductByIdUseCase>((ref) {
  return GetProductByIdUseCase(ref.watch(productRepositoryProvider));
});

// ---- Home-page section providers ----

final featuredProductsProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final result = await ref.watch(getFeaturedProductsUseCaseProvider).call();
  return result.match((failure) => throw failure, (products) => products);
});

final trendingProductsProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final result = await ref.watch(getTrendingProductsUseCaseProvider).call();
  return result.match((failure) => throw failure, (products) => products);
});

final bestSellersProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final result = await ref.watch(getBestSellersUseCaseProvider).call();
  return result.match((failure) => throw failure, (products) => products);
});

// ---- Single product (for a future product detail screen) ----

final productByIdProvider = FutureProvider.family<ProductEntity, String>((ref, productId) async {
  final result = await ref.watch(getProductByIdUseCaseProvider).call(productId);
  return result.match((failure) => throw failure, (product) => product);
});
