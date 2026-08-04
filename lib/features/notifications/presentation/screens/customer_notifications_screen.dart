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
      // FIXED: removed "Mark all read" per request. Title color also
      // made explicit white, same fix as elsewhere.
      appBar: AppBar(title: const Text('Notifications', style: TextStyle(color: Colors.white))),
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
                // FIXED: card was hardcoded Colors.white when read —
                // a bright white card on a dark scaffold with
                // inherited-color text fighting for contrast against
                // it. Now themed via context.appColors for the read
                // state; the unread accent wash is unchanged (already
                // theme-safe since it's a low-opacity tint, not a
                // fixed color).
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: n.isRead ? colors.card : accentColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                    // Read notifications still get a faint outline
                    // (colors.divider) rather than none at all, so every
                    // row reads as a distinct card — not just unread ones.
                    border: Border.all(color: n.isRead ? colors.divider : accentColor.withOpacity(0.35)),
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
                    // NEW: small filled dot for unread, nothing for
                    // read — makes the distinction unmistakable at a
                    // glance rather than relying only on the subtle
                    // background tint.
                    title: Row(
                      children: [
                        if (!n.isRead) ...[
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800, color: colors.ink)),
                        ),
                      ],
                    ),
                    subtitle: Text(n.body, style: TextStyle(fontSize: 12, color: colors.muted)),
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