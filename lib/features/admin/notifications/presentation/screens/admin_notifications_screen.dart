import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../domain/entities/admin_notification_entity.dart';
import '../providers/admin_notifications_providers.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../order_mgmt/presentation/providers/admin_order_providers.dart';
import '../../../order_mgmt/presentation/screens/admin_order_detail_screen.dart';
import '../../../order_mgmt/presentation/screens/admin_order_request_detail_screen.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../../../../products/domain/entities/product_entity.dart';
import '../../../inventory_mgmt/presentation/providers/admin_inventory_providers.dart';
import '../../../inventory_mgmt/presentation/screens/product_form_screen.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);

class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  /// NEW: was previously just context.push('/admin/orders') — the
  /// order list, not the specific order the notification is about.
  /// Looks the order up in the already-live allOrdersAdminProvider
  /// stream and opens its detail screen directly; falls back to the
  /// list only if that specific order can't be found (e.g. deleted).
  Future<void> _openOrder(BuildContext context, WidgetRef ref, String orderId) async {
    final orders = await ref.read(allOrdersAdminProvider.future);
    OrderEntity? order;
    for (final o in orders) {
      if (o.id == orderId) {
        order = o;
        break;
      }
    }
    // FIXED: null-check on `order` doesn't promote through the
    // builder: closure below (a separate function scope), so the
    // analyzer still sees OrderEntity? there. Capture it in a
    // non-nullable local first.
    final resolvedOrder = order;
    if (resolvedOrder != null && context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: resolvedOrder)));
    } else if (context.mounted) {
      context.push('/admin/orders');
    }
  }

  /// NEW: same pattern as _openOrder — looks the request up in the
  /// already-loaded allOrderRequestsAdminProvider and opens its
  /// detail screen directly, so tapping a "new order request"
  /// notification lands exactly where admin needs to act (approve /
  /// convert to order), not just the generic Order Requests list.
  Future<void> _openOrderRequest(BuildContext context, WidgetRef ref, String requestId) async {
    final requests = await ref.read(allOrderRequestsAdminProvider.future);
    OrderRequestEntity? request;
    for (final r in requests) {
      if (r.id == requestId) {
        request = r;
        break;
      }
    }
    final resolvedRequest = request;
    if (resolvedRequest != null && context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderRequestDetailScreen(request: resolvedRequest)));
    } else if (context.mounted) {
      context.push('/admin/orders');
    }
  }

  /// NEW: was previously just context.push('/admin/inventory') — the
  /// full product list, not the specific low-stock product. Looks the
  /// product up and opens its edit form directly; falls back to the
  /// list only if it can't be found (e.g. deleted since the alert fired).
  Future<void> _openProduct(BuildContext context, WidgetRef ref, String productId) async {
    final products = await ref.read(allProductsAdminProvider.future);
    ProductEntity? product;
    for (final p in products) {
      if (p.id == productId) {
        product = p;
        break;
      }
    }
    // Same fix as _openOrder above — non-nullable local for the closure.
    final resolvedProduct = product;
    if (resolvedProduct != null && context.mounted) {
      final categories = await ref.read(allCategoriesAdminProvider.future);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductFormScreen(existing: resolvedProduct, categories: categories)),
        );
      }
    } else if (context.mounted) {
      context.push('/admin/inventory');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsProvider);

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        actions: [
          // NEW: "Mark all read" and "Clear all" both re-added — admin
          // already had full write access to this collection, so
          // these were always safe here; the fix elsewhere was giving
          // customers/employees the SAME ability on their own
          // notifications, which the Firestore rules previously blocked.
          Consumer(
            builder: (context, ref, _) {
              final notifications = ref.watch(adminNotificationsProvider).valueOrNull ?? [];
              final hasUnread = notifications.any((n) => !n.isRead);
              return Row(
                children: [
                  if (hasUnread)
                    IconButton(
                      icon: const Icon(Icons.done_all, color: Colors.white),
                      tooltip: 'Mark all read',
                      onPressed: () {
                        final unreadIds = notifications.where((n) => !n.isRead).map((n) => n.id).toList();
                        ref.read(adminNotificationsDataSourceProvider).markAllAsRead(unreadIds);
                      },
                    ),
                  if (notifications.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                      tooltip: 'Clear all',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Clear all notifications?'),
                            content: const Text('This removes every new-order and low-stock alert.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear all')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final ids = notifications.map((n) => n.id).toList();
                          await ref.read(adminNotificationsDataSourceProvider).deleteAll(ids);
                        }
                      },
                    ),
                ],
              );
            },
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
              // NEW: order_cancelled gets a distinct red accent so it
              // reads as something that needs attention, separate
              // from the routine green "new order"/"new request" tone.
              final accentColor = isLowStock
                  ? _orange
                  : n.type == 'order_cancelled'
                      ? const Color(0xFFE53935)
                      : _green;
              // FIXED: card used to be hardcoded Colors.white when
              // read — a bright white card on a dark scaffold, with
              // title/body text relying on inherited theme color for
              // contrast against it. Now themed via context.appColors
              // for the read state; the unread tint stays as a
              // subtle accent wash (already fine in both themes since
              // it's a low-opacity color, not a fixed white/black).
              // SIMPLIFIED: same reasoning as the customer screen —
              // stripped back to plain white when read, flat tinted
              // background when unread, nothing layered on top.
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
                    isLowStock
                        ? Icons.warning_amber_outlined
                        : n.type == 'order_cancelled'
                            ? Icons.cancel_outlined
                            : n.type == 'new_order_request'
                                ? Icons.edit_note
                                : Icons.receipt_long_outlined,
                    color: accentColor,
                  ),
                  title: Text(titleText, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800, color: colors.ink)),
                  subtitle: bodyText.isEmpty ? null : Text(bodyText, style: TextStyle(fontSize: 12, color: colors.muted)),
                  // NEW: small chevron makes it visually clear the row
                  // is tappable and leads somewhere specific — asked
                  // for on the low-stock alert, applied consistently
                  // to both types for the same affordance.
                  trailing: Icon(Icons.chevron_right, color: colors.muted, size: 20),
                  onTap: () {
                    if (!n.isRead) ref.read(adminNotificationsDataSourceProvider).markAsRead(n.id);
                    if ((n.type == 'new_order' || n.type == 'order_cancelled') && n.orderId != null) {
                      _openOrder(context, ref, n.orderId!);
                    } else if (n.type == 'new_order_request' && n.requestId != null) {
                      _openOrderRequest(context, ref, n.requestId!);
                    } else if (n.type == 'low_stock' && n.productId != null) {
                      _openProduct(context, ref, n.productId!);
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
