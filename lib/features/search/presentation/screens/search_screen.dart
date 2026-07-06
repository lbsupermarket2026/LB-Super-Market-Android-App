import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/loaders/shimmer_skeletons.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus so the keyboard opens immediately — this screen is only
    // reached by intentionally tapping the search bar launcher.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search for products',
            border: InputBorder.none,
          ),
          onChanged: (value) => ref.read(searchNotifierProvider.notifier).onQueryChanged(value),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchNotifierProvider.notifier).onQueryChanged('');
                setState(() {});
              },
            ),
        ],
      ),
      body: searchState.query.trim().isEmpty
          ? const EmptyStateWidget(message: 'Start typing to search products.', icon: Icons.search)
          : searchState.results.when(
              data: (products) => products.isEmpty
                  ? const EmptyStateWidget(message: 'No products found.', icon: Icons.search_off)
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductCard(product: product, onTap: () => context.push('/product/${product.id}'));
                      },
                    ),
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.62,
                ),
                itemCount: 4,
                itemBuilder: (_, __) => const ProductCardSkeleton(),
              ),
              error: (error, _) => ErrorStateWidget(
                message: 'Search failed. Please try again.',
                onRetry: () => ref.read(searchNotifierProvider.notifier).onQueryChanged(_controller.text),
              ),
            ),
    );
  }
}
