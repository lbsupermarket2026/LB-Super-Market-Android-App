import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../providers/product_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));

    return Scaffold(
      body: productAsync.when(
        data: (product) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: product.primaryImage.isNotEmpty
                    ? CachedNetworkImage(imageUrl: product.primaryImage, fit: BoxFit.cover)
                    : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (product.brand?.isNotEmpty == true)
                    Text(product.brand!, style: Theme.of(context).textTheme.bodySmall),
                  Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.xs),
                  if (product.unit.isNotEmpty)
                    Text(product.unit, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        '₹${product.displayPrice.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '₹${product.basePrice.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${product.discountPercent.toStringAsFixed(0)}% OFF',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    product.isInStock ? 'In stock' : 'Out of stock',
                    style: TextStyle(
                      color: product.isInStock ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (product.ratingCount > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text('${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount} reviews)'),
                      ],
                    ),
                  ],
                  if (product.description?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('Description', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(product.description!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (product.variants.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('Options', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: product.variants
                          .map((v) => Chip(label: Text('${v.label} ${v.priceDelta > 0 ? '+₹${v.priceDelta.toStringAsFixed(0)}' : ''}')))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  // Cart module isn't built yet — this becomes a real
                  // add-to-cart action once that module is in place.
                  PrimaryButton(
                    label: product.isInStock ? 'Add to Cart' : 'Out of Stock',
                    onPressed: product.isInStock
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cart module coming next — this will add the item then.')),
                            )
                        : null,
                  ),
                ]),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load this product.',
          onRetry: () => ref.invalidate(productByIdProvider(productId)),
        ),
      ),
    );
  }
}
