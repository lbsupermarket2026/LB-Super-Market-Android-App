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

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref, List notifications) async {
    // Only "personal" notifications (order updates/assignments) can be
    // cleared this way — broadcast ones (new_offer, type: uid == null,
    // shared across every customer) are deliberately excluded, both
    // because Firestore rules don't allow a regular user to delete a
    // doc shared with everyone else, and because doing so would clear
    // it for every customer, not just this one.
    final clearableIds = notifications.where((n) => n.type != 'new_offer').map((n) => n.id as String).toList();
    if (clearableIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This removes your order and delivery notifications. Offer announcements aren\'t affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear all')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(customerNotificationsDataSourceProvider).deleteAll(clearableIds);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final notifications = ref.watch(customerNotificationsProvider);
    final hasUnread = notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        actions: [
          if (hasUnread)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: 'Mark all read',
              onPressed: () {
                final unreadIds = notifications.where((n) => !n.isRead).map((n) => n.id).toList();
                ref.read(customerNotificationsDataSourceProvider).markAllAsRead(unreadIds);
              },
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
              tooltip: 'Clear all',
              onPressed: () => _confirmClearAll(context, ref, notifications),
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

                // SIMPLIFIED: the previous version layered a dot +
                // asymmetric colored-stripe border + tint together,
                // which was rendering incorrectly on-device (showing
                // as an empty colored box with no visible content at
                // all). Stripped back to exactly what was asked for —
                // read is a plain white/normal card, unread is that
                // same card with a simple, flat green (or orange, for
                // offers) tinted background. Nothing layered on top.
                final titleText = n.title.isNotEmpty ? n.title : 'Notification';
                final bodyText = n.body.isNotEmpty ? n.body : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: n.isRead ? colors.card : accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
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
                    title: Text(titleText, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800, color: colors.ink)),
                    subtitle: bodyText.isEmpty ? null : Text(bodyText, style: TextStyle(fontSize: 12, color: colors.muted)),
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
