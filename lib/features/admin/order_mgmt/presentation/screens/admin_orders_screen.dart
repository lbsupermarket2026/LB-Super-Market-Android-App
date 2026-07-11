import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../providers/admin_order_providers.dart';
import 'admin_order_detail_screen.dart';
import 'admin_order_request_detail_screen.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8ED),
        appBar: AppBar(
          title: const Text('Orders'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Orders'), Tab(text: 'Order Requests')],
          ),
        ),
        body: const TabBarView(
          children: [_AdminOrdersTab(), _AdminOrderRequestsTab()],
        ),
      ),
    );
  }
}

class _AdminOrdersTab extends ConsumerStatefulWidget {
  const _AdminOrdersTab();

  @override
  ConsumerState<_AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends ConsumerState<_AdminOrdersTab> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(allOrdersAdminProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load orders: $e')),
      data: (orders) {
        final filtered = _filter == null ? orders : orders.where((o) => o.status == _filter).toList();

        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                children: [
                  _FilterChip(label: 'All', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                  ...OrderStatus.values.map((s) => _FilterChip(
                        label: s.label,
                        selected: _filter == s,
                        onTap: () => setState(() => _filter = s),
                      )),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No orders here.'))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(allOrdersAdminProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final statusColor = order.status == OrderStatus.cancelled
                              ? _red
                              : order.status == OrderStatus.delivered
                                  ? _green
                                  : _orange;
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                '${order.itemCount} items • ₹${order.totalAmount.toStringAsFixed(0)} • ${order.paymentMethod.label}\n${order.deliveryAddress}',
                              ),
                              isThreeLine: true,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text(order.status.label,
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminOrderRequestsTab extends ConsumerWidget {
  const _AdminOrderRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(allOrderRequestsAdminProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load requests: $e')),
      data: (requests) {
        if (requests.isEmpty) return const Center(child: Text('No order requests.'));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allOrderRequestsAdminProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final r = requests[index];
              final statusColor = r.status == OrderRequestStatus.cancelled
                  ? _red
                  : r.status == OrderRequestStatus.confirmed
                      ? _green
                      : _orange;
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(r.type == OrderRequestType.photo ? Icons.photo_camera_outlined : Icons.edit_note),
                  title: Text(
                    r.type == OrderRequestType.photo ? 'Photo list' : '${r.itemLines.length} items typed',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Call: ${r.contactPhone}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(r.status.label, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AdminOrderRequestDetailScreen(request: r)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: _green,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontSize: 12),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
