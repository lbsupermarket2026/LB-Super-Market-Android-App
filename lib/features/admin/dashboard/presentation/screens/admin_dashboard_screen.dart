import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../authentication/presentation/providers/auth_providers.dart';
import '../../../../authentication/domain/entities/user_entity.dart';
import '../../../order_mgmt/presentation/providers/admin_order_providers.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../../../../orders/domain/entities/order_entity.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push('/admin/profile'),
          ),
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: colors.ink),
          ),
          Text(
            isAdmin ? 'Administrator' : 'Employee',
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _PendingCountsRow(),
          const SizedBox(height: AppSpacing.lg),
          Text('Manage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colors.ink)),
          const SizedBox(height: AppSpacing.sm),
          _AdminTile(
            icon: Icons.receipt_long_outlined,
            color: colors.green,
            title: 'Orders',
            subtitle: 'Accept orders & assign to employees for delivery',
            onTap: () => context.push('/admin/orders'),
          ),
          if (isAdmin) ...[
            _AdminTile(
              icon: Icons.badge_outlined,
              color: colors.orange,
              title: 'Employees',
              subtitle: 'Add or remove staff accounts',
              onTap: () => context.push('/admin/employees'),
            ),
            _AdminTile(
              icon: Icons.inventory_2_outlined,
              color: colors.red,
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
              color: colors.red,
              title: 'Home Offer Cards',
              subtitle: 'Manage the scrolling promo cards on Home',
              onTap: () => context.push('/admin/offers'),
            ),
            _AdminTile(
              icon: Icons.person_search_outlined,
              color: Colors.blueGrey,
              title: 'Customer Order History',
              subtitle: 'Look up all orders by phone or customer ID',
              onTap: () => context.push('/admin/customer-orders'),
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
    final colors = context.appColors;
    final ordersAsync = ref.watch(allOrdersAdminProvider);
    final requestsAsync = ref.watch(allOrderRequestsAdminProvider);

    final pendingOrders = ordersAsync.valueOrNull?.where((o) => o.status == OrderStatus.placed).length ?? 0;
    final pendingRequests =
        requestsAsync.valueOrNull?.where((r) => r.status == OrderRequestStatus.pending).length ?? 0;

    return Row(
      children: [
        Expanded(child: _CountCard(label: 'New Orders', count: pendingOrders, color: colors.green)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _CountCard(label: 'Order Requests', count: pendingRequests, color: colors.orange)),
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
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
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
    final colors = context.appColors;
    final disabled = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: (disabled ? colors.muted : color).withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: disabled ? colors.muted : color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: disabled ? colors.muted : colors.ink)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: colors.muted)),
        trailing: disabled ? null : Icon(Icons.chevron_right, color: colors.muted),
        onTap: onTap,
      ),
    );
  }
}
