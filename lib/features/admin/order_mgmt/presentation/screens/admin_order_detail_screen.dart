import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../employee_mgmt/presentation/providers/employee_providers.dart';
import '../../../../employee/presentation/screens/delivery_location_screen.dart';
import '../../../employee_mgmt/domain/entities/staff_member_entity.dart';
import '../../../../orders/presentation/widgets/order_bill_actions.dart';
import '../../../../orders/presentation/widgets/edit_order_dialog.dart';
import '../providers/admin_order_providers.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

// Confirmed/Delivered read as success (green), Cancelled as a stop (red),
// everything still in-progress stays orange — matches how the customer
// side and Orders list already color status badges, so this reads
// consistently across the whole app rather than "selected = always green."
Color _statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.confirmed:
    case OrderStatus.delivered:
      return _green;
    case OrderStatus.cancelled:
      return _red;
    case OrderStatus.placed:
    case OrderStatus.preparing:
    case OrderStatus.outForDelivery:
      return _orange;
  }
}

class AdminOrderDetailScreen extends ConsumerWidget {
  final OrderEntity order;
  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(adminOrderMutationProvider);

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('Order #${order.orderNumber ?? order.id.substring(0, order.id.length.clamp(0, 8))}'),
        actions: [
          if (order.status == OrderStatus.placed && order.paymentMethod != PaymentMethod.upi)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Order',
              onPressed: () async {
                final edited = await showDialog<bool>(
                  context: context,
                  builder: (_) => EditOrderDialog(order: order),
                );
                if (edited == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order updated.')));
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Bill',
            onPressed: () => generateAndShareOrderBill(context, ref, order),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Card(
            title: 'Customer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(order.deliveryAddress)),
                    // NEW: admin previously had no way to see WHERE a
                    // delivery should actually go, just the text
                    // address — employee already had this map view,
                    // now admin gets the exact same reusable screen.
                    if (order.deliveryLatitude != null && order.deliveryLongitude != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.map_outlined, color: _orange),
                        tooltip: 'View on map',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeliveryLocationScreen(
                                latitude: order.deliveryLatitude!,
                                longitude: order.deliveryLongitude!,
                                customerAddress: order.deliveryAddress,
                                orderLabel: order.orderNumber ?? order.id.substring(0, order.id.length.clamp(0, 8)),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                if (order.customerPhone?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('Phone: ${order.customerPhone}'),
                ],
                const SizedBox(height: 4),
                Consumer(
                  builder: (context, ref, _) {
                    final statsAsync = ref.watch(customerOrderStatsProvider(order.userId));
                    return statsAsync.when(
                      data: (stats) => GestureDetector(
                        onTap: () => context.push('/admin/customer-orders', extra: order.userId),
                        child: Row(
                          children: [
                            Text(
                              stats.count <= 1
                                  ? 'First order from this customer'
                                  : '${stats.count} orders • ₹${stats.totalSpent.toStringAsFixed(0)} total from this customer',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: _green),
                            ),
                            if (stats.count > 1) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 16, color: _green),
                            ],
                          ],
                        ),
                      ),
                      loading: () => const Text('Loading order history…', style: TextStyle(color: Colors.grey)),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text('Payment: ${order.paymentMethod.label}'),
                if (order.razorpayPaymentId?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Payment ref: ${order.razorpayPaymentId}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                if (order.refundStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      order.refundStatus == 'processed'
                          ? 'Refund: Processed${order.refundId != null ? ' (${order.refundId})' : ''}'
                          : order.refundStatus == 'processing'
                              ? 'Refund: In progress via Razorpay'
                              : 'Refund: Failed — ${order.refundError ?? 'check Razorpay dashboard'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: order.refundStatus == 'processed'
                            ? _green
                            : order.refundStatus == 'processing'
                                ? _orange
                                : _red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _Card(
            title: 'Items',
            child: Column(
              children: [
                ...order.items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('${i.name} × ${i.quantity}')),
                          Text('₹${i.lineTotal.toStringAsFixed(2)}'),
                        ],
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('₹${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          _Card(
            title: 'Update Status',
            child: order.status == OrderStatus.cancelled
                // NEW: a cancelled order is a final state — showing
                // tappable status chips here implied it could still be
                // moved to e.g. "Delivered", which is exactly what was
                // just reported as a bug. The Firestore write itself is
                // now also guarded (admin_order_datasource.dart), but
                // this keeps the UI honest about it too rather than
                // letting someone tap a chip and get an error back.
                ? Row(
                    children: [
                      const Icon(Icons.block, size: 18, color: _red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This order was cancelled — its status can no longer be changed.',
                          style: TextStyle(color: colors.muted, fontSize: 13),
                        ),
                      ),
                    ],
                  )
                : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrderStatus.values.map((s) {
                final isCurrent = s == order.status;
                final color = _statusColor(s);
                return ChoiceChip(
                  label: Text(s.label),
                  selected: isCurrent,
                  selectedColor: color,
                  // FIXED: unselected label was hardcoded black87 —
                  // invisible on a dark unselected chip in dark mode.
                  labelStyle: TextStyle(color: isCurrent ? Colors.white : colors.ink, fontSize: 12),
                  onSelected: mutation.isSubmitting
                      ? null
                      : (_) async {
                          final success = await ref.read(adminOrderMutationProvider.notifier).updateOrderStatus(order.id, s);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(success ? 'Status updated to ${s.label}.' : 'Could not update status.')),
                            );
                            if (success) Navigator.pop(context);
                          }
                        },
                );
              }).toList(),
            ),
          ),
          // NEW: hide "Assign Delivery" entirely once an order is
          // cancelled — assigning (or reassigning) an employee to
          // deliver something that's no longer happening made no
          // sense, same class of fix as the Update Status guard above.
          if (order.status != OrderStatus.cancelled)
            _Card(
              title: 'Assign Delivery',
              child: order.deliveryPersonName?.isNotEmpty == true
                  ? Row(
                      children: [
                        const Icon(Icons.delivery_dining, color: _orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${order.deliveryPersonName} • ${order.deliveryPersonPhone}')),
                        TextButton(onPressed: () => _showAssignDialog(context, ref), child: const Text('Change')),
                      ],
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white),
                      onPressed: () => _showAssignDialog(context, ref),
                      icon: const Icon(Icons.delivery_dining),
                      label: const Text('Assign Employee'),
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAssignDialog(BuildContext context, WidgetRef ref) async {
    // ref.read() on its own only returns whatever's already loaded — if
    // this is the first time this session anything has asked for the
    // staff list (e.g. jumping straight to an order without visiting
    // Employees first), that snapshot is empty even though real
    // employees exist. Awaiting .future actually fetches it.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<StaffMemberEntity> staff;
    try {
      final allStaff = await ref.read(allStaffProvider.future);
      staff = allStaff.where((s) => s.role == StaffRole.employee).toList();
    } catch (e) {
      staff = [];
    }

    if (context.mounted) Navigator.pop(context); // close the loading dialog

    if (!context.mounted) return;

    if (staff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employees added yet — add one from the Employees screen first.')),
      );
      return;
    }

    final selected = await showDialog<StaffMemberEntity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign to Employee'),
        children: staff
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e),
                  child: Text('${e.name} (${e.phone})'),
                ))
            .toList(),
      ),
    );

    if (selected == null || !context.mounted) return;

    final success =
        await ref.read(adminOrderMutationProvider.notifier).assignDelivery(order.id, selected.uid, selected.name, selected.phone);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Assigned to ${selected.name}.' : 'Could not assign.')),
      );
      if (success) Navigator.pop(context);
    }
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
