import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../wishlist/presentation/widgets/wishlist_button.dart';
import '../providers/product_providers.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: productAsync.when(
        data: (product) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.primaryImage.isNotEmpty
                        ? CachedNetworkImage(
                        imageUrl: product.primaryImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF3F3F3),
                          child: const Icon(Icons.image_not_supported_outlined, color: Colors.black38, size: 40),
                        ),
                      )
                        : Container(color: const Color(0xFFF3F3F3)),
                    if (product.hasDiscount)
                      Positioned(
                        top: 90,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '${product.discountPercent.toStringAsFixed(0)}% OFF',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: WishlistButton(productId: product.id, size: 20),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (product.brand?.isNotEmpty == true)
                    Text(product.brand!, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(product.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
                  const SizedBox(height: AppSpacing.xs),
                  if (product.unit.isNotEmpty) Text(product.unit, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        '₹${product.displayPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _green),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '₹${product.basePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (product.isInStock ? _green : _red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.isInStock ? 'In stock' : 'Out of stock',
                      style: TextStyle(
                        color: product.isInStock ? _green : _red,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (product.ratingCount > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text('${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount} reviews)',
                            style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                  ],
                  if (product.description?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Container(width: 32, height: 3, color: const Color(0xFFEF6C00)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(product.description!, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                  ],
                  if (product.variants.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Options', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: product.variants
                          .map((v) => Chip(
                                label: Text('${v.label} ${v.priceDelta > 0 ? '+₹${v.priceDelta.toStringAsFixed(0)}' : ''}'),
                                backgroundColor: _green.withOpacity(0.08),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(product.isInStock ? 'Add to Cart' : 'Out of Stock',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      onPressed: product.isInStock
                          ? () {
                              ref.read(cartProvider.notifier).addProduct(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${product.name} added to cart')),
                              );
                            }
                          : null,
                    ),
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
