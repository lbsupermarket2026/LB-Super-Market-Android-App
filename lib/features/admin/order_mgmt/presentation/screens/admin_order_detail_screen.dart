import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../employee_mgmt/presentation/providers/employee_providers.dart';
import '../../../employee_mgmt/domain/entities/staff_member_entity.dart';
import '../providers/admin_order_providers.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);

class AdminOrderDetailScreen extends ConsumerWidget {
  final OrderEntity order;
  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(adminOrderMutationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Card(
            title: 'Customer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.deliveryAddress),
                if (order.customerPhone?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('Phone: ${order.customerPhone}'),
                ],
                const SizedBox(height: 4),
                Text('Payment: ${order.paymentMethod.label}'),
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrderStatus.values.map((s) {
                final isCurrent = s == order.status;
                return ChoiceChip(
                  label: Text(s.label),
                  selected: isCurrent,
                  selectedColor: _green,
                  labelStyle: TextStyle(color: isCurrent ? Colors.white : Colors.black87, fontSize: 12),
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
    final staffAsync = ref.read(allStaffProvider);
    final staff = staffAsync.valueOrNull?.where((s) => s.role == StaffRole.employee).toList() ?? [];

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
        await ref.read(adminOrderMutationProvider.notifier).assignDelivery(order.id, selected.name, selected.phone);
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
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
