import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../order_requests/domain/entities/order_request_entity.dart';
import '../../../order_requests/presentation/providers/order_request_providers.dart';
import '../../domain/entities/order_entity.dart';
import '../providers/order_providers.dart';
import '../widgets/order_status_stepper.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

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

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myOrdersProvider),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    orders.length == 1 ? 'You have 1 order' : 'You have ${orders.length} orders',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: const [
                      _PlaceOrderEntryButton(),
                      SizedBox(height: AppSpacing.md),
                      _WhatsAppOrderCard(),
                      SizedBox(height: AppSpacing.md),
                      _PendingOrderRequestsSection(),
                    ],
                  ),
                ),
                if (activeOrder.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: _ActiveOrderCard(order: activeOrder.first),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Order History', accentWord: 'History'),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: orders
                        .map((order) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _OrderCard(order: order),
                            ))
                        .toList(),
                  ),
                ),
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

  static const _whatsappNumber = '7989694819';

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent("Hi, I'd like to place an order.")}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF25D366),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
      color: _green,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/place-order'),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.playlist_add, color: Colors.white),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Place a New Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            const Text('Order Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
            const SizedBox(height: AppSpacing.sm),
            ...pending.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onTap: () => context.push('/order-requests/${r.id}'),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: _orange.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(
                        r.type == OrderRequestType.photo ? Icons.photo_camera_outlined : Icons.edit_note,
                        color: _orange,
                      ),
                    ),
                    title: Text(
                      r.type == OrderRequestType.photo
                          ? 'Photo list submitted'
                          : '${r.itemLines.length} item${r.itemLines.length == 1 ? '' : 's'} typed',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${r.fulfillmentMethod == FulfillmentMethod.delivery ? 'Home Delivery' : 'In-Store Pickup'} • We\'ll call ${r.contactPhone}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'Pending',
                        style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w700, fontSize: 11),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_green.withOpacity(0.10), _green.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: _green),
              const SizedBox(width: 8),
              const Text('Track Your Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OrderStatusStepper(status: order.status),
          Row(
            children: [
              if (order.canCallDelivery)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: _green, side: const BorderSide(color: _green)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
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
    final statusColor = order.status == OrderStatus.cancelled
        ? _red
        : order.status == OrderStatus.delivered
            ? _green
            : _orange;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.receipt_long_outlined, color: statusColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(
                      '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} • ${_formatDate(order.createdAt)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      order.status.label,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11),
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
