import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../providers/employee_order_providers.dart';

class EmployeeHomeScreen extends ConsumerWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(currentUserProvider);
    final ordersAsync = ref.watch(myAssignedOrdersProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('My Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push('/employee/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(signOutUseCaseProvider).call(),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load your deliveries: $e')),
        data: (orders) {
          final active = orders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).toList();
          final completed = orders.where((o) => o.status == OrderStatus.delivered).toList();

          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Hi, ${user?.name ?? ''}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink)),
                    const SizedBox(height: AppSpacing.md),
                    Icon(Icons.local_shipping_outlined, size: 48, color: colors.muted),
                    const SizedBox(height: AppSpacing.sm),
                    Text('No deliveries assigned to you yet.', textAlign: TextAlign.center, style: TextStyle(color: colors.muted)),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myAssignedOrdersProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text('Hi, ${user?.name ?? ''}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.ink)),
                const SizedBox(height: AppSpacing.lg),
                if (active.isNotEmpty) ...[
                  Text('To Deliver', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: colors.ink)),
                  const SizedBox(height: AppSpacing.sm),
                  ...active.map((o) => _DeliveryCard(order: o)),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (completed.isNotEmpty) ...[
                  Text('Completed (${completed.length})', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: colors.ink)),
                  const SizedBox(height: AppSpacing.sm),
                  ...completed.map((o) => _DeliveryCard(order: o)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeliveryCard extends ConsumerWidget {
  final OrderEntity order;
  const _DeliveryCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isDelivered = order.status == OrderStatus.delivered;
    final isMarking = ref.watch(markDeliveredProvider);
    final statusColor = isDelivered ? colors.green : colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(order.status.label,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(order.deliveryAddress, style: TextStyle(color: colors.ink)),
          const SizedBox(height: 4),
          Text('${order.itemCount} items • ₹${order.totalAmount.toStringAsFixed(0)} • ${order.paymentMethod.label}',
              style: TextStyle(color: colors.muted, fontSize: 12)),
          if (!isDelivered) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (order.customerPhone?.isNotEmpty == true)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: colors.green, side: BorderSide(color: colors.green)),
                      onPressed: () async {
                        final uri = Uri.parse('tel:${order.customerPhone}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                    ),
                  ),
                if (order.customerPhone?.isNotEmpty == true) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: colors.green, foregroundColor: Colors.white),
                    onPressed: isMarking
                        ? null
                        : () async {
                            final success = await ref.read(markDeliveredProvider.notifier).markDelivered(order.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(success ? 'Marked as delivered.' : 'Could not update.')),
                              );
                            }
                          },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Delivered'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
