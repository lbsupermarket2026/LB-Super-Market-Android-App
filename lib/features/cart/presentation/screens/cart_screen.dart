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
const _ink = Color(0xFF232620);
const _muted = Color(0xFF8A8D82);

// Kept as simple constants for now — becomes real config (or gets
// dropped entirely) once actual delivery/tax logic exists.
const _taxAmount = 0.0;
const _freeDeliveryThreshold = 0.0; // delivery is free regardless, for now

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load cart: $e')),
          data: (items) {
            if (items.isEmpty) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('My cart', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
                    ),
                  ),
                  const Expanded(
                    child: EmptyStateWidget(
                      message: 'Your cart is empty. Add products from Browse to get started.',
                      icon: Icons.shopping_cart_outlined,
                    ),
                  ),
                ],
              );
            }

            final grandTotal = total + _taxAmount;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('My cart · ${items.length} items',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: item.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: item.imageUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.image_outlined, color: Colors.black38, size: 20)),
                                      )
                                    : Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.image_outlined, color: Colors.black38, size: 20)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink)),
                                  if (item.unit.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                                      child: Text(item.unit, style: const TextStyle(fontSize: 10.5, color: _muted)),
                                    ),
                                  _QuantityStepper(productId: item.productId, quantity: item.quantity),
                                ],
                              ),
                            ),
                            Text('₹${item.lineTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(AppSpacing.md),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEECE2))),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Item total', value: '₹${total.toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      const _SummaryRow(label: 'Delivery fee', value: 'Free', valueColor: _green),
                      const SizedBox(height: 8),
                      _SummaryRow(label: 'Taxes', value: '₹${_taxAmount.toStringAsFixed(0)}'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Colors.grey.shade300),
                      ),
                      _SummaryRow(label: 'To pay', value: '₹${grandTotal.toStringAsFixed(0)}', bold: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final orderId = await showDialog<String>(context: context, builder: (_) => const PlaceOrderDialog());
                        if (orderId != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
                          context.push('/orders/$orderId');
                        }
                      },
                      child: const Text('Proceed to checkout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _SummaryRow({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? _ink : Colors.grey.shade700)),
        Text(value, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: valueColor ?? (bold ? _ink : Colors.grey.shade700))),
      ],
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
        _StepperButton(icon: Icons.remove, onTap: () => ref.read(cartProvider.notifier).setQuantity(productId, quantity - 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('$quantity', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
        ),
        _StepperButton(icon: Icons.add, onTap: () => ref.read(cartProvider.notifier).setQuantity(productId, quantity + 1)),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFDDDDDD))),
        child: Icon(icon, size: 13, color: _ink),
      ),
    );
  }
}
