import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../domain/entities/admin_notification_entity.dart';
import '../providers/admin_notifications_providers.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              final unread = notificationsAsync.valueOrNull?.where((n) => !n.isRead).map((n) => n.id).toList() ?? [];
              if (unread.isNotEmpty) {
                ref.read(adminNotificationsDataSourceProvider).markAllAsRead(unread);
              }
            },
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load notifications: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              final isLowStock = n.type == 'low_stock';
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: n.isRead ? Colors.white : (isLowStock ? _orange : _green).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: n.isRead ? Colors.transparent : (isLowStock ? _orange : _green).withOpacity(0.3)),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(
                    isLowStock ? Icons.warning_amber_outlined : Icons.receipt_long_outlined,
                    color: isLowStock ? _orange : _green,
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                  subtitle: Text(n.body, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    if (!n.isRead) ref.read(adminNotificationsDataSourceProvider).markAsRead(n.id);
                    if (n.type == 'new_order' && n.orderId != null) {
                      context.push('/admin/orders');
                    } else if (n.type == 'low_stock') {
                      context.push('/admin/inventory');
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
