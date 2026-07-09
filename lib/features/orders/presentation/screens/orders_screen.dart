import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../order_requests/domain/entities/order_request_entity.dart';
import '../../../order_requests/presentation/providers/order_request_providers.dart';
import '../../domain/entities/order_entity.dart';
import '../providers/order_providers.dart';
import '../widgets/order_status_stepper.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load your orders.',
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                _PlaceOrderEntryButton(),
                SizedBox(height: AppSpacing.md),
                _WhatsAppOrderCard(),
                SizedBox(height: AppSpacing.md),
                _PendingOrderRequestsSection(),
                SizedBox(height: AppSpacing.lg),
                EmptyStateWidget(
                  message: 'Your orders will show up here once you place one.',
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            );
          }

          final activeOrder = orders.where((o) => o.status.isActive).toList();
          final theme = Theme.of(context);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myOrdersProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  orders.length == 1 ? 'You have 1 order' : 'You have ${orders.length} orders',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: AppSpacing.md),
                const _PlaceOrderEntryButton(),
                const SizedBox(height: AppSpacing.md),
                const _WhatsAppOrderCard(),
                const SizedBox(height: AppSpacing.md),
                const _PendingOrderRequestsSection(),
                const SizedBox(height: AppSpacing.md),
                if (activeOrder.isNotEmpty) ...[
                  _ActiveOrderCard(order: activeOrder.first),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Order History', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                ],
                ...orders.map((order) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _OrderCard(order: order),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WhatsAppOrderCard extends StatelessWidget {
  const _WhatsAppOrderCard();

  // Fixed store number for phone/WhatsApp orders — update here if it
  // ever changes, this is the only place it's defined.
  static const _whatsappNumber = '917989694819';

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent("Hi, I'd like to place an order.")}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF25D366), // WhatsApp brand green
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openWhatsApp,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.chat, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order via WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('Chat with us to place an order directly',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceOrderEntryButton extends StatelessWidget {
  const _PlaceOrderEntryButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE53935),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/place-order'),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.playlist_add, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Place a New Order',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingOrderRequestsSection extends ConsumerWidget {
  const _PendingOrderRequestsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myOrderRequestsProvider);

    return requestsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (requests) {
        final pending = requests.where((r) => r.status == OrderRequestStatus.pending).toList();
        if (pending.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Requests', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...pending.map((r) => Card(
                  child: ListTile(
                    leading: Icon(
                      r.type == OrderRequestType.photo ? Icons.photo_camera_outlined : Icons.edit_note,
                    ),
                    title: Text(
                      r.type == OrderRequestType.photo
                          ? 'Photo list submitted'
                          : '${r.itemLines.length} item${r.itemLines.length == 1 ? '' : 's'} typed',
                    ),
                    subtitle: Text(
                      '${r.fulfillmentMethod == FulfillmentMethod.delivery ? 'Home Delivery' : 'In-Store Pickup'} • We\'ll call ${r.contactPhone}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Pending',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final OrderEntity order;
  const _ActiveOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: cs.primary),
              const SizedBox(width: 8),
              Text('Track Your Order', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OrderStatusStepper(status: order.status),
          Row(
            children: [
              if (order.canCallDelivery)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('tel:${order.deliveryPersonPhone}');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call Delivery'),
                  ),
                ),
              if (order.canCallDelivery) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/orders/${order.id}'),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderEntity order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = order.status == OrderStatus.cancelled
        ? cs.error
        : order.status == OrderStatus.delivered
            ? cs.primary
            : cs.tertiary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} • ${_formatDate(order.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${order.totalAmount.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.label,
                      style: theme.textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
