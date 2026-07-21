import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/widgets/loaders/shimmer_skeletons.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../../core/widgets/search/search_bar_launcher.dart';
import '../../../../core/widgets/auto_scroll_row.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../wishlist/presentation/providers/wishlist_providers.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../categories/presentation/widgets/category_tile.dart';
import '../../../offers/presentation/providers/offer_card_providers.dart';
import '../../../offers/presentation/widgets/offer_card_carousel.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../products/presentation/widgets/product_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
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
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(enabledOfferCardsProvider);
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (defaultAddress != null)
                            GestureDetector(
                              onTap: () => context.push(RouteNames.addresses),
                              child: Row(
                                children: [
                                  Text('Deliver to ', style: TextStyle(fontSize: 12, color: colors.muted)),
                                  Flexible(
                                    child: Text(
                                      '${defaultAddress.label} · ${defaultAddress.city}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: colors.ink, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down, size: 16, color: colors.muted),
                                ],
                              ),
                            ),
                          Text(
                            '$greeting, ${user?.name?.split(' ').first ?? 'there'} 👋',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.ink),
                          ),
                        ],
                      ),
                    ),
                    const _WishlistIconButton(),
                    const SizedBox(width: 8),
                    const _CartIconButton(),
                  ],
                ),
              ),
              SearchBarLauncher(onTap: () => context.push('/search')),
              const _ActiveOrderCard(),
              const SizedBox(height: AppSpacing.md),
              _OfferCardsSection(ref: ref),
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

class _WishlistIconButton extends ConsumerWidget {
  const _WishlistIconButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final count = ref.watch(wishlistProvider).valueOrNull?.length ?? 0;

    return GestureDetector(
      onTap: () => context.push(RouteNames.wishlist),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(Icons.favorite_border, color: colors.ink, size: 20),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(color: colors.red, shape: BoxShape.circle),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartIconButton extends ConsumerWidget {
  const _CartIconButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final count = ref.watch(cartItemCountProvider);

    return GestureDetector(
      onTap: () => context.push('/cart'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(Icons.shopping_cart_outlined, color: colors.ink, size: 20),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(color: colors.red, shape: BoxShape.circle),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small "full box" tracker for whatever order is currently in
/// progress — sits between the search bar and Shop by Category, but
/// only when there's genuinely an active order. With none, nothing
/// renders here and Home looks exactly as it always has.
class _ActiveOrderCard extends ConsumerWidget {
  const _ActiveOrderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final ordersAsync = ref.watch(myOrdersProvider);
    final activeOrder = ordersAsync.valueOrNull?.where((o) => o.status.isActive).toList() ?? [];

    if (activeOrder.isEmpty) return const SizedBox.shrink();

    final order = activeOrder.first;
    final orange = colors.orange;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: GestureDetector(
        onTap: () => context.push('/orders/${order.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: orange.withOpacity(0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: orange.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.local_shipping_outlined, color: orange, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.id.substring(0, order.id.length.clamp(0, 6))} · ${order.status.label}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.ink)),
                    Text('${order.itemCount} items · ₹${order.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: colors.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.muted),
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
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.ink)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text('See all', style: TextStyle(fontSize: 12, color: colors.green, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class _OfferCardsSection extends ConsumerWidget {
  final WidgetRef ref;
  const _OfferCardsSection({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final cardsAsync = ref.watch(enabledOfferCardsProvider);

    return cardsAsync.when(
      data: (cards) {
        if (cards.isEmpty) return const SizedBox.shrink();
        return OfferCardCarousel(
          cards: cards,
          onCardTap: (card) => context.push('/offer-products/${card.id}', extra: card.title),
        );
      },
      loading: () => const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
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
