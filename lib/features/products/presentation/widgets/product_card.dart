import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../wishlist/presentation/widgets/wishlist_button.dart';
import '../../domain/entities/product_entity.dart';

class ProductCard extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onTap;
  final bool showWishlist;

  const ProductCard({super.key, required this.product, required this.onTap, this.showWishlist = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          // Hardcoded white/dark-text, same reasoning as CategoryCard —
          // this should always look like the (light-themed) website,
          // regardless of the phone's system theme.
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
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
                            placeholder: (context, url) => Container(color: const Color(0xFFF3F3F3)),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFFF3F3F3),
                              child: const Icon(Icons.image_not_supported_outlined, color: Colors.black38),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF3F3F3),
                            child: const Icon(Icons.image_outlined, color: Colors.black38),
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
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${product.discountPercent.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                if (showWishlist)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: WishlistButton(productId: product.id, size: 16),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87),
                  ),
                  if (product.unit.isNotEmpty)
                    Text(product.unit, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${product.displayPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${product.basePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade500,
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
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700),
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
