import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/customer_notifications_providers.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);

class CustomerNotificationsScreen extends ConsumerWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final notifications = ref.watch(customerNotificationsProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              final unread = notifications.where((n) => !n.isRead).map((n) => n.id).toList();
              if (unread.isNotEmpty) {
                ref.read(customerNotificationsDataSourceProvider).markAllAsRead(unread);
              }
            },
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                final isOffer = n.type == 'new_offer';
                final isAssignment = n.type == 'order_assigned';
                final accentColor = isOffer ? _orange : _green;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: n.isRead ? Colors.white : accentColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: n.isRead ? Colors.transparent : accentColor.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: Icon(
                      isOffer
                          ? Icons.local_offer_outlined
                          : isAssignment
                              ? Icons.assignment_turned_in_outlined
                              : Icons.local_shipping_outlined,
                      color: accentColor,
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800)),
                    subtitle: Text(n.body, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      if (!n.isRead) ref.read(customerNotificationsDataSourceProvider).markAsRead(n.id);
                      if (n.type == 'order_status' && n.orderId != null) {
                        context.push('/orders/${n.orderId}');
                      } else if (n.type == 'new_offer') {
                        context.push('/offers');
                      } else if (n.type == 'order_assigned') {
                        context.push('/employee/home');
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}