import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/loaders/shimmer_skeletons.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../providers/category_products_notifier.dart';
import '../widgets/product_card.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String? categoryName;

  const CategoryDetailScreen({super.key, required this.categoryId, this.categoryName});

  @override
  ConsumerState<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(categoryProductsProvider(widget.categoryId).notifier).loadMore(widget.categoryId);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(categoryProductsProvider(widget.categoryId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName ?? 'Products')),
      body: stateAsync.when(
        data: (state) {
          if (state.errorMessage != null && state.items.isEmpty) {
            return ErrorStateWidget(
              message: state.errorMessage!,
              onRetry: () => ref.invalidate(categoryProductsProvider(widget.categoryId)),
            );
          }
          if (state.items.isEmpty) {
            return const EmptyStateWidget(message: 'No products in this category yet.', icon: Icons.shopping_bag_outlined);
          }
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.62,
            ),
            itemCount: state.items.length + (state.isLoadingMore ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return const ProductCardSkeleton();
              }
              final product = state.items[index];
              return ProductCard(product: product, onTap: () => context.push('/product/${product.id}'));
            },
          );
        },
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.62,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => const ProductCardSkeleton(),
        ),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load products.',
          onRetry: () => ref.invalidate(categoryProductsProvider(widget.categoryId)),
        ),
      ),
    );
  }
}
