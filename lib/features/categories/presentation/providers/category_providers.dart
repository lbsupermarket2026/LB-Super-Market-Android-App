import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/category_remote_datasource.dart';
import '../../data/repositories_impl/category_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/get_top_level_categories_usecase.dart';
import '../../domain/usecases/get_subcategories_usecase.dart';

final categoryRemoteDataSourceProvider = Provider<CategoryRemoteDataSource>((ref) {
  return CategoryRemoteDataSource();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(categoryRemoteDataSourceProvider));
});

final getTopLevelCategoriesUseCaseProvider = Provider<GetTopLevelCategoriesUseCase>((ref) {
  return GetTopLevelCategoriesUseCase(ref.watch(categoryRepositoryProvider));
});

final getSubcategoriesUseCaseProvider = Provider<GetSubcategoriesUseCase>((ref) {
  return GetSubcategoriesUseCase(ref.watch(categoryRepositoryProvider));
});

/// Top-level categories for the Home screen grid + Categories screen.
final topLevelCategoriesProvider = FutureProvider<List<CategoryEntity>>((ref) async {
  final result = await ref.watch(getTopLevelCategoriesUseCaseProvider).call();
  return result.match((failure) => throw failure, (categories) => categories);
});

/// Subcategories for a given parent — family provider keyed by parent id.
final subcategoriesProvider = FutureProvider.family<List<CategoryEntity>, String>((ref, parentId) async {
  final result = await ref.watch(getSubcategoriesUseCaseProvider).call(parentId);
  return result.match((failure) => throw failure, (categories) => categories);
});
