import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../products/presentation/widgets/product_card.dart';
import '../providers/wishlist_providers.dart';
import '../widgets/wishlist_button.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load wishlist: $e')),
        data: (ids) {
          if (ids.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Your wishlist is empty.'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Tap the heart on any product to save it here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final idList = ids.toList();

          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.68,
            ),
            itemCount: idList.length,
            itemBuilder: (context, index) {
              final productId = idList[index];
              final productAsync = ref.watch(productByIdProvider(productId));

              return productAsync.when(
                loading: () => const Card(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline),
                        const SizedBox(height: 4),
                        const Text('Unavailable', textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () => ref.read(wishlistProvider.notifier).remove(productId),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (product) => Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ProductCard(
                        product: product,
                        onTap: () => context.push('/product/${product.id}'),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: WishlistButton(productId: product.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
