import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product_entity.dart';
import 'product_providers.dart';

/// Sentinel key for the "All" tab in Browse — keeps this notifier keyed
/// by a single non-nullable String (Riverpod family keys work best that
/// way) while still meaning "no category filter" underneath.
const String kAllProductsKey = '__all__';

class BrowseProductsState {
  final List<ProductEntity> items;
  final bool isLoadingMore;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final String? errorMessage;

  const BrowseProductsState({
    this.items = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDocument,
    this.errorMessage,
  });

  BrowseProductsState copyWith({
    List<ProductEntity>? items,
    bool? isLoadingMore,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    String? errorMessage,
  }) =>
      BrowseProductsState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        lastDocument: lastDocument ?? this.lastDocument,
        errorMessage: errorMessage,
      );
}

class BrowseProductsNotifier extends FamilyAsyncNotifier<BrowseProductsState, String> {
  static const _pageSize = 20;

  @override
  Future<BrowseProductsState> build(String categoryKey) async {
    return _fetchPage(categoryKey);
  }

  Future<BrowseProductsState> _fetchPage(String categoryKey, {DocumentSnapshot<Map<String, dynamic>>? after}) async {
    final result = categoryKey == kAllProductsKey
        ? await ref.read(getAllProductsUseCaseProvider).call(limit: _pageSize, startAfter: after)
        : await ref.read(getProductsByCategoryUseCaseProvider).call(
              categoryId: categoryKey,
              limit: _pageSize,
              startAfter: after,
            );

    return result.match(
      (failure) => BrowseProductsState(errorMessage: failure.message),
      (page) => BrowseProductsState(items: page.items, lastDocument: page.lastDocument, hasMore: page.hasMore),
    );
  }

  Future<void> loadMore(String categoryKey) async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final next = await _fetchPage(categoryKey, after: current.lastDocument);

    state = AsyncData(current.copyWith(
      items: [...current.items, ...next.items],
      lastDocument: next.lastDocument ?? current.lastDocument,
      hasMore: next.hasMore,
      isLoadingMore: false,
      errorMessage: next.errorMessage,
    ));
  }
}

final browseProductsProvider =
    AsyncNotifierProvider.family<BrowseProductsNotifier, BrowseProductsState, String>(
  BrowseProductsNotifier.new,
);
