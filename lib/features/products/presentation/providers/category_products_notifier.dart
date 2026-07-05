import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product_entity.dart';
import 'product_providers.dart';

class CategoryProductsState {
  final List<ProductEntity> items;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final String? errorMessage;

  const CategoryProductsState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDocument,
    this.errorMessage,
  });

  CategoryProductsState copyWith({
    List<ProductEntity>? items,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    String? errorMessage,
  }) =>
      CategoryProductsState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        lastDocument: lastDocument ?? this.lastDocument,
        errorMessage: errorMessage,
      );
}

class CategoryProductsNotifier extends FamilyAsyncNotifier<CategoryProductsState, String> {
  static const _pageSize = 20;

  @override
  Future<CategoryProductsState> build(String categoryId) async {
    return _fetchFirstPage(categoryId);
  }

  Future<CategoryProductsState> _fetchFirstPage(String categoryId) async {
    final result = await ref.read(getProductsByCategoryUseCaseProvider).call(categoryId: categoryId, limit: _pageSize);
    return result.match(
      (failure) => CategoryProductsState(errorMessage: failure.message),
      (page) => CategoryProductsState(items: page.items, lastDocument: page.lastDocument, hasMore: page.hasMore),
    );
  }

  Future<void> loadMore(String categoryId) async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final result = await ref.read(getProductsByCategoryUseCaseProvider).call(
          categoryId: categoryId,
          limit: _pageSize,
          startAfter: current.lastDocument,
        );

    state = AsyncData(result.match(
      (failure) => current.copyWith(isLoadingMore: false, errorMessage: failure.message),
      (page) => current.copyWith(
        items: [...current.items, ...page.items],
        lastDocument: page.lastDocument ?? current.lastDocument,
        hasMore: page.hasMore,
        isLoadingMore: false,
      ),
    ));
  }
}

final categoryProductsProvider =
    AsyncNotifierProvider.family<CategoryProductsNotifier, CategoryProductsState, String>(
  CategoryProductsNotifier.new,
);
