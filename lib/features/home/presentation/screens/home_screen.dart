import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/loaders/shimmer_skeletons.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../../core/widgets/search/search_bar_launcher.dart';
import '../../../../core/widgets/auto_scroll_row.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../categories/presentation/widgets/category_tile.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../providers/home_providers.dart';
import '../widgets/banner_carousel.dart';

const _green = Color(0xFF2E7D32);
const _ink = Color(0xFF232620);
const _muted = Color(0xFF8A8D82);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final addressesAsync = ref.watch(addressListProvider);
    final defaultAddress = addressesAsync.valueOrNull?.isNotEmpty == true
        ? (addressesAsync.valueOrNull!.where((a) => a.isDefault).isNotEmpty
            ? addressesAsync.valueOrNull!.firstWhere((a) => a.isDefault)
            : addressesAsync.valueOrNull!.first)
        : null;

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeBannersProvider);
            ref.invalidate(topLevelCategoriesProvider);
            ref.invalidate(featuredProductsProvider);
            ref.invalidate(trendingProductsProvider);
            ref.invalidate(bestSellersProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (defaultAddress != null)
                      GestureDetector(
                        onTap: () => context.push(RouteNames.addresses),
                        child: Row(
                          children: [
                            const Text('Deliver to ', style: TextStyle(fontSize: 12, color: _muted)),
                            Flexible(
                              child: Text(
                                '${defaultAddress.label} · ${defaultAddress.city}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: _muted),
                          ],
                        ),
                      ),
                    Text(
                      '$greeting, ${user?.name?.split(' ').first ?? 'there'} 👋',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
                    ),
                  ],
                ),
              ),
              SearchBarLauncher(onTap: () => context.push('/search')),
              const SizedBox(height: AppSpacing.md),
              _BannerSection(ref: ref),
              const SizedBox(height: AppSpacing.lg),
              _CategorySection(ref: ref),
              const SizedBox(height: AppSpacing.lg),
              _ProductSection(title: 'Featured products', provider: featuredProductsProvider, ref: ref),
              const SizedBox(height: AppSpacing.lg),
              _ProductSection(title: 'Trending now', provider: trendingProductsProvider, ref: ref),
              const SizedBox(height: AppSpacing.lg),
              _ProductSection(title: 'Best sellers', provider: bestSellersProvider, ref: ref),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain bold title + green "See all" — matches the reference design's
/// section headers exactly (no two-tone accent/underline treatment).
class _PlainSectionHead extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _PlainSectionHead({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('See all', style: TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w700)),
            ),
        ],
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
      error: (_, __) => const SizedBox.shrink(),
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
        _PlainSectionHead(title: 'Shop by category', onSeeAll: () => context.push(RouteNames.categories)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 92,
          child: categoriesAsync.when(
            data: (categories) => categories.isEmpty
                ? const Center(child: Text('No categories yet'))
                : AutoScrollRow(
                    itemWidth: 82,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    children: categories
                        .map((category) => Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.md),
                              child: CategoryTile(
                                category: category,
                                onTap: () => context.push('/category/${category.id}', extra: category.name),
                              ),
                            ))
                        .toList(),
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
        _PlainSectionHead(title: title),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 210,
          child: productsAsync.when(
            data: (products) => products.isEmpty
                ? const Center(child: Text('Nothing here yet'))
                : AutoScrollRow(
                    itemWidth: 158,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    children: products
                        .map((product) => Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: ProductCard(product: product, onTap: () => context.push('/product/${product.id}')),
                            ))
                        .toList(),
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
