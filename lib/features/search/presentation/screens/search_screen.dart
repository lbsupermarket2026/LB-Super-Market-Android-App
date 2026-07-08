import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/loaders/shimmer_skeletons.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../cart/presentation/widgets/cart_bar.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/browse_products_notifier.dart';
import '../../../products/presentation/widgets/browse_product_tile.dart';
import '../providers/search_providers.dart';

enum _SortOption { popular, priceLowHigh, priceHighLow, nameAz }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedCategoryKey = kAllProductsKey;
  _SortOption _sort = _SortOption.popular;
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (ref.read(searchNotifierProvider).query.trim().isNotEmpty) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(browseProductsProvider(_selectedCategoryKey).notifier).loadMore(_selectedCategoryKey);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<ProductEntity> _applyFilters(List<ProductEntity> products) {
    var result = _selectedBrand == null ? products : products.where((p) => p.brand == _selectedBrand).toList();

    switch (_sort) {
      case _SortOption.priceLowHigh:
        result = [...result]..sort((a, b) => a.displayPrice.compareTo(b.displayPrice));
        break;
      case _SortOption.priceHighLow:
        result = [...result]..sort((a, b) => b.displayPrice.compareTo(a.displayPrice));
        break;
      case _SortOption.nameAz:
        result = [...result]..sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortOption.popular:
        break; // keep server order (most recently added first)
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(searchNotifierProvider);
    final isSearching = searchState.query.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(theme),
                _buildFilterChips(theme),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCategoryRail(),
                      Expanded(
                        child: isSearching ? _buildSearchResults(searchState) : _buildBrowseGrid(),
                      ),
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

  Widget _buildTopBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.error.withOpacity(0.4)),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search in Browse...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchNotifierProvider.notifier).onQueryChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  ref.read(searchNotifierProvider.notifier).onQueryChanged(value);
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final brandsAsync = ref.watch(browseProductsProvider(_selectedCategoryKey));
    final brands = brandsAsync.valueOrNull?.items
            .map((p) => p.brand)
            .whereType<String>()
            .where((b) => b.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          PopupMenuButton<_SortOption>(
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _SortOption.popular, child: Text('Popular')),
              PopupMenuItem(value: _SortOption.priceLowHigh, child: Text('Price: Low to High')),
              PopupMenuItem(value: _SortOption.priceHighLow, child: Text('Price: High to Low')),
              PopupMenuItem(value: _SortOption.nameAz, child: Text('Name: A-Z')),
            ],
            child: Chip(
              avatar: const Icon(Icons.swap_vert, size: 16),
              label: Text('Sort: ${_sortLabel(_sort)}'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PopupMenuButton<String?>(
            onSelected: (v) => setState(() => _selectedBrand = v),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('All Brands')),
              ...brands.map((b) => PopupMenuItem(value: b, child: Text(b))),
            ],
            child: Chip(
              avatar: const Icon(Icons.sell_outlined, size: 16),
              label: Text(_selectedBrand ?? 'Brand'),
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(_SortOption option) {
    switch (option) {
      case _SortOption.popular:
        return 'Popular';
      case _SortOption.priceLowHigh:
        return 'Price ↑';
      case _SortOption.priceHighLow:
        return 'Price ↓';
      case _SortOption.nameAz:
        return 'A-Z';
    }
  }

  Widget _buildCategoryRail() {
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);

    return Container(
      width: 84,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor))),
      child: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (categories) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            _RailItem(
              label: 'All',
              isSelected: _selectedCategoryKey == kAllProductsKey,
              onTap: () => setState(() => _selectedCategoryKey = kAllProductsKey),
            ),
            ...categories.map((c) => _RailItem(
                  label: c.name,
                  imageUrl: c.imageUrl ?? c.iconUrl,
                  isSelected: _selectedCategoryKey == c.id,
                  onTap: () => setState(() => _selectedCategoryKey = c.id),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseGrid() {
    final stateAsync = ref.watch(browseProductsProvider(_selectedCategoryKey));

    return stateAsync.when(
      loading: () => _gridSkeleton(),
      error: (error, _) => ErrorStateWidget(
        message: 'Could not load products.',
        onRetry: () => ref.invalidate(browseProductsProvider(_selectedCategoryKey)),
      ),
      data: (state) {
        final filtered = _applyFilters(state.items);
        if (filtered.isEmpty) {
          return const EmptyStateWidget(message: 'No products found.', icon: Icons.shopping_bag_outlined);
        }
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.72,
          ),
          itemCount: filtered.length + (state.isLoadingMore ? 2 : 0),
          itemBuilder: (context, index) {
            if (index >= filtered.length) return const ProductCardSkeleton();
            final product = filtered[index];
            return BrowseProductTile(product: product, onTap: () => context.push('/product/${product.id}'));
          },
        );
      },
    );
  }

  Widget _buildSearchResults(SearchState searchState) {
    return searchState.results.when(
      data: (products) {
        final filtered = _applyFilters(products);
        if (filtered.isEmpty) {
          return const EmptyStateWidget(message: 'No products found.', icon: Icons.search_off);
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.72,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            return BrowseProductTile(product: product, onTap: () => context.push('/product/${product.id}'));
          },
        );
      },
      loading: () => _gridSkeleton(),
      error: (error, _) => ErrorStateWidget(
        message: 'Search failed. Please try again.',
        onRetry: () => ref.read(searchNotifierProvider.notifier).onQueryChanged(_controller.text),
      ),
    );
  }

  Widget _gridSkeleton() => GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      );
}

class _RailItem extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _RailItem({required this.label, this.imageUrl, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? cs.error.withOpacity(0.08) : null,
          border: Border(left: BorderSide(color: isSelected ? cs.error : Colors.transparent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.category_outlined, size: 20),
                    )
                  : Icon(
                      label == 'All' ? Icons.apps : Icons.category_outlined,
                      size: 20,
                      color: isSelected ? cs.error : null,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? cs.error : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
