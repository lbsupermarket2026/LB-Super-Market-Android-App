import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../providers/offer_products_providers.dart';

class OfferProductsScreen extends ConsumerWidget {
  final String offerId;
  final String offerTitle;

  const OfferProductsScreen({super.key, required this.offerId, required this.offerTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsByOfferProvider(offerId));
    final categoriesAsync = ref.watch(categoriesByOfferProvider(offerId));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: Text(offerTitle)),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: 'Could not load this offer.',
          onRetry: () => ref.invalidate(productsByOfferProvider(offerId)),
        ),
        data: (products) {
          final categories = categoriesAsync.valueOrNull ?? [];

          if (products.isEmpty && categories.isEmpty) {
            return const EmptyStateWidget(
              message: 'Nothing is tagged to this offer yet.',
              icon: Icons.local_offer_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (categories.isNotEmpty) ...[
                const Text('Categories in this offer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => _CategoryChip(category: categories[index]),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (products.isNotEmpty) ...[
                Text('Products (${products.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(product: product, onTap: () => context.push('/product/${product.id}'));
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final CategoryEntity category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/category/${category.id}', extra: category.name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E2D6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category.imageUrl?.isNotEmpty == true)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(imageUrl: category.imageUrl!, width: 20, height: 20, fit: BoxFit.cover),
              ),
            if (category.imageUrl?.isNotEmpty == true) const SizedBox(width: 6),
            Text(category.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
