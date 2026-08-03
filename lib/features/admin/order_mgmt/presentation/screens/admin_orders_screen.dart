import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../providers/admin_order_providers.dart';
import '../../../../orders/presentation/providers/order_providers.dart';
import 'admin_order_detail_screen.dart';
import 'admin_create_order_screen.dart';
import 'admin_order_request_detail_screen.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text('Orders'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Create Order',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminCreateOrderScreen()),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Orders'), Tab(text: 'Order Requests')],
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
    final colors = context.appColors;
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
                              : (order.status == OrderStatus.delivered || order.status == OrderStatus.confirmed)
                                  ? _green
                                  : _orange;
                          // FIXED: was a ListTile with up to 3 stacked
                          // items (Payment Pending badge + status badge +
                          // assigned employee name) crammed into its
                          // `trailing` slot — ListTile gives trailing a
                          // fixed height budget, so with all three present
                          // it overflowed ("BOTTOM OVERFLOWED BY 14
                          // PIXELS"). Replaced with a manual Row/Column
                          // layout that sizes to its content naturally,
                          // so it can never overflow regardless of how
                          // many badges are showing. Text colors are now
                          // explicit via context.appColors instead of
                          // ListTile's inherited defaults, for guaranteed
                          // dark-mode contrast.
                          return Material(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Order #${order.orderNumber ?? order.id.substring(0, order.id.length.clamp(0, 8))}',
                                              style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink)),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${order.itemCount} items • ₹${order.totalAmount.toStringAsFixed(0)} • ${order.paymentMethod.label}\n${order.deliveryAddress}',
                                            style: TextStyle(color: colors.muted, fontSize: 12.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (order.paymentPending)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                              child: const Text('Payment Pending',
                                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 10)),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                          child: Text(order.status.label,
                                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                                        ),
                                        if (order.assignedEmployeeUid != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Consumer(
                                              builder: (context, ref, _) {
                                                final nameAsync = ref.watch(assignedEmployeeNameProvider(order.assignedEmployeeUid!));
                                                return nameAsync.when(
                                                  data: (name) => Text(
                                                    name ?? 'Assigned',
                                                    style: TextStyle(fontSize: 10, color: colors.muted),
                                                  ),
                                                  loading: () => const SizedBox.shrink(),
                                                  error: (_, __) => const SizedBox.shrink(),
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
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
    final colors = context.appColors;
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
                  color: colors.card,
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
    // FIXED: unselected label was hardcoded Colors.black87 — on a
    // dark unselected chip surface in dark mode this was very low
    // contrast. Now colors.ink, which flips appropriately.
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: _green,
        labelStyle: TextStyle(color: selected ? Colors.white : colors.ink, fontSize: 12),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
