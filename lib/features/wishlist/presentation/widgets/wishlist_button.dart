import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wishlist_providers.dart';

/// Small reusable heart toggle — drop this into any product card or
/// detail screen (e.g. ProductCard, ProductDetailScreen) to let users
/// wishlist a product from wherever they see it, not just from here.
class WishlistButton extends ConsumerWidget {
  final String productId;
  final double size;

  const WishlistButton({super.key, required this.productId, this.size = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final isWishlisted = wishlistAsync.valueOrNull?.contains(productId) ?? false;

    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => ref.read(wishlistProvider.notifier).toggle(productId),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            isWishlisted ? Icons.favorite : Icons.favorite_border,
            size: size,
            color: isWishlisted ? Colors.red : Colors.black54,
          ),
        ),
      ),
    );
  }
}
