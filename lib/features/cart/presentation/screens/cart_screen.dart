import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../providers/cart_providers.dart';
import '../widgets/place_order_dialog.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load cart: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateWidget(
              message: 'Your cart is empty. Add products from Browse to get started.',
              icon: Icons.shopping_cart_outlined,
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: item.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                    imageUrl: item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFFF3F3F3),
                                      child: const Icon(Icons.image_not_supported_outlined, color: Colors.black38, size: 20),
                                    ),
                                  )
                                  : Container(
                                      color: const Color(0xFFF3F3F3),
                                      child: const Icon(Icons.image_outlined, color: Colors.black38),
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                                if (item.unit.isNotEmpty)
                                  Text(item.unit, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                Text(
                                  '₹${item.price.toStringAsFixed(2)}',
                                  style: const TextStyle(color: _green, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          _QuantityStepper(productId: item.productId, quantity: item.quantity),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final orderId = await showDialog<String>(
                            context: context,
                            builder: (_) => const PlaceOrderDialog(),
                          );
                          if (orderId != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Order placed successfully!')),
                            );
                            context.push('/orders/$orderId');
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Text('Place Order', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  final String productId;
  final int quantity;
  const _QuantityStepper({required this.productId, required this.quantity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: _red,
          onPressed: () => ref.read(cartProvider.notifier).setQuantity(productId, quantity - 1),
        ),
        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: _green,
          onPressed: () => ref.read(cartProvider.notifier).setQuantity(productId, quantity + 1),
        ),
      ],
    );
  }
}
