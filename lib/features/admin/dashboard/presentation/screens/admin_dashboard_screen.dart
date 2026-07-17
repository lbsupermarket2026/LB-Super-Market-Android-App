import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../authentication/presentation/providers/auth_providers.dart';
import '../../../../authentication/domain/entities/user_entity.dart';
import '../../../../orders/presentation/providers/order_providers.dart';
import '../../../../order_requests/presentation/providers/order_request_providers.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../../../../orders/domain/entities/order_entity.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(signOutUseCaseProvider).call(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Welcome, ${user?.name ?? user?.email ?? ''}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          Text(
            isAdmin ? 'Administrator' : 'Employee',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _PendingCountsRow(),
          const SizedBox(height: AppSpacing.lg),
          const Text('Manage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: AppSpacing.sm),
          _AdminTile(
            icon: Icons.receipt_long_outlined,
            color: _green,
            title: 'Orders',
            subtitle: 'Accept orders & assign to employees for delivery',
            onTap: () => context.push('/admin/orders'),
          ),
          if (isAdmin) ...[
            _AdminTile(
              icon: Icons.badge_outlined,
              color: _orange,
              title: 'Employees',
              subtitle: 'Add or remove staff accounts',
              onTap: () => context.push('/admin/employees'),
            ),
            _AdminTile(
              icon: Icons.inventory_2_outlined,
              color: _red,
              title: 'Inventory',
              subtitle: 'Manage products, categories & stock',
              onTap: () => context.push('/admin/inventory'),
            ),
            _AdminTile(
              icon: Icons.bar_chart_outlined,
              color: Colors.blueGrey,
              title: 'Sales Reports',
              subtitle: 'Revenue and orders, hourly through yearly',
              onTap: () => context.push('/admin/sales'),
            ),
            _AdminTile(
              icon: Icons.local_offer_outlined,
              color: _red,
              title: 'Home Offer Cards',
              subtitle: 'Manage the scrolling promo cards on Home',
              onTap: () => context.push('/admin/offers'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingCountsRow extends ConsumerWidget {
  const _PendingCountsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);
    final requestsAsync = ref.watch(myOrderRequestsProvider);

    final pendingOrders = ordersAsync.valueOrNull?.where((o) => o.status == OrderStatus.placed).length ?? 0;
    final pendingRequests =
        requestsAsync.valueOrNull?.where((r) => r.status == OrderRequestStatus.pending).length ?? 0;

    return Row(
      children: [
        Expanded(child: _CountCard(label: 'New Orders', count: pendingOrders, color: _green)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _CountCard(label: 'Order Requests', count: pendingRequests, color: _orange)),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AdminTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: (disabled ? Colors.grey : color).withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: disabled ? Colors.grey : color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: disabled ? Colors.grey : Colors.black87)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: disabled ? null : Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }
}
