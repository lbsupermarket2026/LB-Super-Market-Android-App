import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_providers.dart';

class SearchState {
  final String query;
  final AsyncValue<List<ProductEntity>> results;

  const SearchState({this.query = '', this.results = const AsyncData([])});

  SearchState copyWith({String? query, AsyncValue<List<ProductEntity>>? results}) =>
      SearchState(query: query ?? this.query, results: results ?? this.results);
}

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(results: const AsyncData([]));
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    state = state.copyWith(results: const AsyncLoading());
    final result = await ref.read(searchProductsUseCaseProvider).call(query.trim().toLowerCase());
    state = state.copyWith(
      results: result.match(
        (failure) => AsyncError(failure.message, StackTrace.current),
        (products) => AsyncData(products),
      ),
    );
  }
}

final searchNotifierProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
