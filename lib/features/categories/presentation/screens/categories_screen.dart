import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/widgets/loaders/shimmer_skeletons.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../cart/presentation/widgets/cart_bar.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/browse_products_notifier.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../providers/category_providers.dart';

/// Zepto/Blinkit-style layout — categories fixed on the left, products
/// for whichever one's selected on the right, with a tile/list toggle
/// for how those products are shown.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _selectedCategoryKey = kAllProductsKey;
  bool _isTileView = true;
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // NEW: title collapses to make room for the
                      // search field when expanded, so nothing
                      // overflows on narrow screens.
                      if (!_isSearchExpanded)
                        Text('Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.ink)),
                      if (_isSearchExpanded)
                        Expanded(
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            // Deliberately NOT a fully-rounded stadium
                            // shape — small corner radius rectangle
                            // instead, a different enough shape/paint
                            // path from the pill that kept rendering
                            // incorrectly on this device.
                            decoration: BoxDecoration(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.divider),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search, size: 18, color: colors.muted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    style: TextStyle(color: colors.ink, fontSize: 14),
                                    cursorColor: colors.ink,
                                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      hintText: 'Search products',
                                      hintStyle: TextStyle(fontSize: 13, color: colors.muted),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // NEW: replaces the always-visible search bar
                          // entirely — a small icon button, same style
                          // as the view-toggle button right next to it,
                          // that expands into the search field above
                          // when tapped, and collapses (clearing any
                          // query) when tapped again.
                          Material(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(10),
                            child: IconButton(
                              icon: Icon(_isSearchExpanded ? Icons.close : Icons.search, size: 20, color: colors.ink),
                              tooltip: _isSearchExpanded ? 'Close search' : 'Search products',
                              onPressed: () => setState(() {
                                _isSearchExpanded = !_isSearchExpanded;
                                if (!_isSearchExpanded) {
                                  _searchController.clear();
                                  _searchQuery = '';
                                }
                              }),
                            ),
                          ),
                          if (!_isSearchExpanded) ...[
                            const SizedBox(width: 8),
                            Material(
                              color: colors.card,
                              borderRadius: BorderRadius.circular(10),
                              child: IconButton(
                                icon: Icon(_isTileView ? Icons.view_list_outlined : Icons.grid_view_outlined, size: 20, color: colors.ink),
                                tooltip: _isTileView ? 'Switch to list view' : 'Switch to tile view',
                                onPressed: () => setState(() => _isTileView = !_isTileView),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CategoryRail(
                        selectedKey: _selectedCategoryKey,
                        onSelect: (key) => setState(() => _selectedCategoryKey = key),
                      ),
                      Expanded(child: _ProductsArea(categoryKey: _selectedCategoryKey, isTileView: _isTileView, searchQuery: _searchQuery)),
                    ],
                  ),
                ),
              ],
            ),
            const Align(alignment: Alignment.bottomCenter, child: CartBar()),
          ],
        ),
      ),
    );
  }
}

class _CategoryRail extends ConsumerWidget {
  final String selectedKey;
  final ValueChanged<String> onSelect;
  const _CategoryRail({required this.selectedKey, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);

    return Container(
      width: 84,
      decoration: BoxDecoration(color: colors.card, border: Border(right: BorderSide(color: colors.divider))),
      child: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (categories) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            _RailItem(
              label: 'All',
              isSelected: selectedKey == kAllProductsKey,
              onTap: () => onSelect(kAllProductsKey),
            ),
            ...categories.map((c) => _RailItem(
                  label: c.name,
                  imageUrl: c.imageUrl ?? c.iconUrl,
                  isSelected: selectedKey == c.id,
                  onTap: () => onSelect(c.id),
                )),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _RailItem({required this.label, this.imageUrl, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colors.green.withOpacity(0.1) : null,
          border: Border(left: BorderSide(color: isSelected ? colors.green : Colors.transparent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(Icons.category_outlined, size: 20, color: colors.muted),
                    )
                  : Icon(
                      label == 'All' ? Icons.apps : Icons.category_outlined,
                      size: 20,
                      color: isSelected ? colors.green : colors.muted,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? colors.green : colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductsArea extends ConsumerWidget {
  final String categoryKey;
  final bool isTileView;
  final String searchQuery;
  const _ProductsArea({required this.categoryKey, required this.isTileView, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(browseProductsProvider(categoryKey));

    return stateAsync.when(
      loading: () => _skeleton(isTileView),
      error: (error, _) => ErrorStateWidget(
        message: 'Could not load products.',
        onRetry: () => ref.invalidate(browseProductsProvider(categoryKey)),
      ),
      data: (state) {
        if (state.errorMessage != null && state.items.isEmpty) {
          return ErrorStateWidget(
            message: state.errorMessage!,
            onRetry: () => ref.invalidate(browseProductsProvider(categoryKey)),
          );
        }

        final items = searchQuery.isEmpty
            ? state.items
            : state.items.where((p) => p.name.toLowerCase().contains(searchQuery)).toList();

        if (items.isEmpty) {
          return EmptyStateWidget(
            message: searchQuery.isEmpty ? 'No products found.' : 'No products match "$searchQuery".',
            icon: Icons.shopping_bag_outlined,
          );
        }

        return isTileView
            ? GridView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 96),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.62,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final product = items[index];
                  return ProductCard(product: product, width: null, onTap: () => context.push('/product/${product.id}'));
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 96),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = items[index];
                  return _ProductListRow(product: product, onTap: () => context.push('/product/${product.id}'));
                },
              );
      },
    );
  }

  Widget _skeleton(bool tileView) {
    if (!tileView) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const SizedBox(height: 84, child: ProductCardSkeleton()),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}

/// Compact horizontal row for list view — image, name/unit, price, and
/// a quick add button, all in one line instead of a tile's stacked layout.
class _ProductListRow extends ConsumerWidget {
  final ProductEntity product;
  final VoidCallback onTap;
  const _ProductListRow({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: product.primaryImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.primaryImage,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: colors.chipBackground, child: Icon(Icons.image_outlined, color: colors.muted)),
                        )
                      : Container(color: colors.chipBackground, child: Icon(Icons.image_outlined, color: colors.muted)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: colors.ink)),
                    if (product.unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(product.unit, style: TextStyle(fontSize: 11, color: colors.muted)),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('₹${product.displayPrice.toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: colors.green)),
                        if (product.hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text('₹${product.basePrice.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: colors.muted)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: colors.green,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: product.isInStock ? () => ref.read(cartProvider.notifier).addProduct(product) : null,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
