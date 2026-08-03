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
              final accentColor = isLowStock ? _orange : _green;
              // FIXED: card used to be hardcoded Colors.white when
              // read — a bright white card on a dark scaffold, with
              // title/body text relying on inherited theme color for
              // contrast against it. Now themed via context.appColors
              // for the read state; the unread tint stays as a
              // subtle accent wash (already fine in both themes since
              // it's a low-opacity color, not a fixed white/black).
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: n.isRead ? colors.card : accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: n.isRead ? Colors.transparent : accentColor.withOpacity(0.35)),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(
                    isLowStock ? Icons.warning_amber_outlined : Icons.receipt_long_outlined,
                    color: accentColor,
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w800, color: colors.ink),
                  ),
                  subtitle: Text(n.body, style: TextStyle(fontSize: 12, color: colors.muted)),
                  // NEW: small chevron makes it visually clear the row
                  // is tappable and leads somewhere specific — asked
                  // for on the low-stock alert, applied consistently
                  // to both types for the same affordance.
                  trailing: Icon(Icons.chevron_right, color: colors.muted, size: 20),
                  onTap: () {
                    if (!n.isRead) ref.read(adminNotificationsDataSourceProvider).markAsRead(n.id);
                    if (n.type == 'new_order' && n.orderId != null) {
                      _openOrder(context, ref, n.orderId!);
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