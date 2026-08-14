import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../providers/cart_providers.dart';
import '../widgets/place_order_dialog.dart';
import '../../domain/utils/checkout_calculator.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../admin/delivery_settings/presentation/providers/delivery_settings_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final itemsAsync = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load cart: $e')),
          data: (items) {
            if (items.isEmpty) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('My cart', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.ink)),
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

            // FIXED: delivery fee and taxes were hardcoded to
            // "Free" / ₹0 here regardless of actual configured
            // delivery charge or each item's category GST rate —
            // leftover placeholders from before CheckoutCalculator
            // existed. Now computed for real, matching exactly what
            // the Place Order dialog will actually charge.
            final categoriesAsync = ref.watch(topLevelCategoriesProvider);
            final categoriesById = <String, CategoryEntity>{
              for (final cat in categoriesAsync.valueOrNull ?? <CategoryEntity>[]) cat.id: cat,
            };
            final deliverySettingsAsync = ref.watch(deliverySettingsProvider);
            final deliveryCharge = deliverySettingsAsync.valueOrNull?.flatDeliveryCharge ?? 0;
            final originalTotal = items.fold(0.0, (sum, item) => sum + item.originalLineTotal);
            final discountAmount = originalTotal - total;
            final gstAmount = items.fold(0.0, (sum, item) {
              final category = item.categoryId != null ? categoriesById[item.categoryId] : null;
              final gstPercent = category?.gstPercent ?? 0;
              return sum + (item.lineTotal * gstPercent / 100);
            });
            final sgstAmount = gstAmount / 2;
            final cgstAmount = gstAmount / 2;
            final grandTotal = total + gstAmount + deliveryCharge;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('My cart · ${items.length} items',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.ink)),
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
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.divider))),
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
                                        errorWidget: (_, __, ___) => Container(color: colors.chipBackground, child: Icon(Icons.image_outlined, color: colors.muted, size: 20)),
                                      )
                                    : Container(color: colors.chipBackground, child: Icon(Icons.image_outlined, color: colors.muted, size: 20)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.ink)),
                                  if (item.unit.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                                      child: Text(item.unit, style: TextStyle(fontSize: 10.5, color: colors.muted)),
                                    ),
                                  _QuantityStepper(productId: item.productId, quantity: item.quantity),
                                ],
                              ),
                            ),
                            Text('₹${item.lineTotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.ink)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(AppSpacing.md),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.cardBorder)),
                  child: Column(
                    children: [
                      if (discountAmount > 0) ...[
                        _SummaryRow(label: 'Original price', value: '₹${originalTotal.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'Discount', value: '-₹${discountAmount.toStringAsFixed(0)}', valueColor: colors.green),
                        const SizedBox(height: 8),
                      ],
                      _SummaryRow(label: 'Discounted price', value: '₹${total.toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Delivery charge',
                        value: deliveryCharge > 0 ? '₹${deliveryCharge.toStringAsFixed(0)}' : 'Free',
                        valueColor: deliveryCharge > 0 ? null : colors.green,
                      ),
                      if (sgstAmount > 0) ...[
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'SGST', value: '₹${sgstAmount.toStringAsFixed(2)}'),
                      ],
                      if (cgstAmount > 0) ...[
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'CGST', value: '₹${cgstAmount.toStringAsFixed(2)}'),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: colors.divider),
                      ),
                      _SummaryRow(label: 'Total amount', value: '₹${grandTotal.toStringAsFixed(0)}', bold: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final orderId = await showDialog<String>(context: context, builder: (_) => const PlaceOrderDialog());
                        if (orderId != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
                          // FIXED: was context.push('/orders/$orderId'),
                          // landing on the order detail screen (stacked
                          // on top of Cart, which was itself stacked on
                          // Home) — per request, go back to Home
                          // instead. context.go() (not push) also
                          // correctly clears that stack, since Home is
                          // a shell tab.
                          context.go(RouteNames.home);
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
    final colors = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? colors.ink : colors.muted)),
        Text(value, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: valueColor ?? (bold ? colors.ink : colors.muted))),
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
    final colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(icon: Icons.remove, onTap: () => ref.read(cartProvider.notifier).setQuantity(productId, quantity - 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('$quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.ink)),
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
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.divider)),
        child: Icon(icon, size: 13, color: colors.ink),
      ),
    );
  }
}
