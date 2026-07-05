import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_radii_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/product_entity.dart';

class ProductCard extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? Colors.white,
          borderRadius: AppRadii.card,
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: product.primaryImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.primaryImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainerHighest),
                            errorWidget: (context, url, error) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.image_outlined),
                          ),
                  ),
                ),
                if (product.hasDiscount)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${product.discountPercent.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (product.unit.isNotEmpty)
                    Text(product.unit, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${product.displayPrice.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${product.basePrice.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!product.isInStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Out of stock',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
