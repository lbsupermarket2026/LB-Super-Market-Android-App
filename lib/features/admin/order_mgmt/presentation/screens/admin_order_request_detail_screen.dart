import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../providers/admin_order_providers.dart';
import '../widgets/convert_to_order_dialog.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

class AdminOrderRequestDetailScreen extends ConsumerWidget {
  final OrderRequestEntity request;
  const AdminOrderRequestDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(adminOrderMutationProvider);

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      // FIXED: was Text('Order Request') with no color, so it
      // inherited dark mode's default AppBar foreground — same fix
      // as the Orders/Order Requests tabs before, applied to the
      // title itself here.
      appBar: AppBar(title: const Text('Order Request', style: TextStyle(color: Colors.white))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FIXED: every Text below had no explicit color, so
                // it inherited dark mode's light default — invisible
                // against this card, which is deliberately always
                // white regardless of theme (same pattern as
                // product_card.dart, login_screen.dart, etc.).
                Text(
                  request.type == OrderRequestType.photo ? 'Photo Submission' : 'Typed List',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (request.type == OrderRequestType.typedList)
                  ...request.itemLines.map((line) => Text('• $line', style: const TextStyle(color: Colors.black87)))
                else if (request.photoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(request.photoUrl!, height: 200, fit: BoxFit.cover),
                  ),
                const Divider(height: 24),
                Text('Call: ${request.contactPhone}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  request.fulfillmentMethod == FulfillmentMethod.delivery
                      ? 'Home Delivery — ${request.deliveryAddress ?? ""}'
                      : 'In-Store Pickup',
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (request.status == OrderRequestStatus.pending) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
              onPressed: mutation.isSubmitting
                  ? null
                  : () async {
                      final orderId = await showDialog<String>(
                        context: context,
                        builder: (_) => ConvertToOrderDialog(request: request),
                      );
                      if (orderId != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Order created and request confirmed.')),
                        );
                        Navigator.pop(context);
                      }
                    },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Convert to Order (after calling customer)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _red),
              onPressed: mutation.isSubmitting
                  ? null
                  : () async {
                      final success = await ref
                          .read(adminOrderMutationProvider.notifier)
                          .updateRequestStatus(request.id, OrderRequestStatus.cancelled);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'Request cancelled.' : 'Could not cancel.')),
                        );
                        if (success) Navigator.pop(context);
                      }
                    },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Request'),
            ),
          ] else
            Text('This request is ${request.status.label.toLowerCase()}.'),
        ],
      ),
    );
  }
}
