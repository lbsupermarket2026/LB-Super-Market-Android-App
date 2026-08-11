import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_providers.dart';

const _green = Color(0xFF2E7D32);

/// Sticky "View Cart" pill — only renders once there's at least one item,
/// so screens that include this don't need their own empty-cart check.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);
    final total = ref.watch(cartTotalProvider);

    if (count == 0) return const SizedBox.shrink();

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        // FIXED: was cs.error (red) — changed to the brand green to
        // match the rest of the app's palette, per request.
        color: _green,
        borderRadius: BorderRadius.circular(28),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => context.push('/cart'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white,
                  child: Text(
                    '$count',
                    style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'View Cart',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
