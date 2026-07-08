import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../domain/entities/product_entity.dart';

/// Compact tile for the Browse grid — discount badge, image, name, unit,
/// price with strikethrough MRP, and a quick "+" add-to-cart button.
/// Deliberately separate from ProductCard (used on Home/Category) so
/// changes here don't ripple into screens that weren't asked for.
class BrowseProductTile extends ConsumerWidget {
  final ProductEntity product;
  final VoidCallback onTap;

  const BrowseProductTile({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: product.primaryImage.isNotEmpty
                        ? CachedNetworkImage(imageUrl: product.primaryImage, fit: BoxFit.contain)
                        : Container(
                            color: cs.surfaceContainerHighest,
                            child: const Icon(Icons.image_outlined),
                          ),
                  ),
                ),
                if (product.hasDiscount)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '${product.discountPercent.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (product.unit.isNotEmpty)
              Text(product.unit, style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${product.displayPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(color: cs.error, fontWeight: FontWeight.w700),
                      ),
                      if (product.hasDiscount)
                        Text(
                          '₹${product.basePrice.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: cs.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                Material(
                  color: cs.error,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: product.isInStock ? () => ref.read(cartProvider.notifier).addProduct(product) : null,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
