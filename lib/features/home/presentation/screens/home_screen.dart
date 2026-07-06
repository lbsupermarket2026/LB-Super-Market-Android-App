import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/loaders/shimmer_skeletons.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/search/search_bar_launcher.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../categories/presentation/widgets/category_tile.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../providers/home_providers.dart';
import '../widgets/banner_carousel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.name?.split(' ').first ?? 'there'} 👋'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeBannersProvider);
          ref.invalidate(topLevelCategoriesProvider);
          ref.invalidate(featuredProductsProvider);
          ref.invalidate(trendingProductsProvider);
          ref.invalidate(bestSellersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            SearchBarLauncher(onTap: () => context.push('/search')),
            const SizedBox(height: AppSpacing.md),
            _BannerSection(ref: ref),
            const SizedBox(height: AppSpacing.lg),
            _CategorySection(ref: ref),
            const SizedBox(height: AppSpacing.lg),
            _ProductSection(
              title: 'Featured Products',
              provider: featuredProductsProvider,
              ref: ref,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProductSection(
              title: 'Trending Now',
              provider: trendingProductsProvider,
              ref: ref,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProductSection(
              title: 'Best Sellers',
              provider: bestSellersProvider,
              ref: ref,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _BannerSection extends ConsumerWidget {
  final WidgetRef ref;
  const _BannerSection({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final bannersAsync = ref.watch(homeBannersProvider);
    return bannersAsync.when(
      data: (banners) => BannerCarousel(banners: banners),
      loading: () => const AspectRatio(
        aspectRatio: 16 / 7,
        child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: CircularProgressIndicator())),
      ),
      error: (_, __) => const SizedBox.shrink(), // banners are non-critical; fail silently
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final WidgetRef ref;
  const _CategorySection({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Categories', onSeeAll: () => context.push(RouteNames.categories)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 100,
          child: categoriesAsync.when(
            data: (categories) => categories.isEmpty
                ? const Center(child: Text('No categories yet'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return CategoryTile(
                        category: category,
                        onTap: () => context.push('/category/${category.id}', extra: category.name),
                      );
                    },
                  ),
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, __) => const CategoryTileSkeleton(),
            ),
            error: (error, _) => Center(child: Text('Could not load categories', style: Theme.of(context).textTheme.bodySmall)),
          ),
        ),
      ],
    );
  }
}

class _ProductSection extends ConsumerWidget {
  final String title;
  final FutureProvider<List<ProductEntity>> provider;
  final WidgetRef ref;

  const _ProductSection({required this.title, required this.provider, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final productsAsync = ref.watch(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 240,
          child: productsAsync.when(
            data: (products) => products.isEmpty
                ? const Center(child: Text('Nothing here yet'))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => context.push('/product/${product.id}'),
                      );
                    },
                  ),
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            ),
            error: (error, _) => ErrorStateWidget(
              message: 'Could not load $title',
              onRetry: () => ref.invalidate(provider),
            ),
          ),
        ),
      ],
    );
  }
}
