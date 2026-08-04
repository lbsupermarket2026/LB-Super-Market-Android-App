import 'package:flutter/material.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/entities/order_entity.dart';

/// Surfaces the refund state that autoRefundOnCancel (Cloud Function)
/// writes onto a cancelled order — previously only visible by checking
/// the order document directly in Firestore. Renders nothing if the
/// order was never cancelled/refunded (refundStatus is null), so it's
/// safe to drop into any order detail screen unconditionally.
class RefundStatusBanner extends StatelessWidget {
  final OrderEntity order;
  const RefundStatusBanner({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order.refundStatus;
    if (status == null) return const SizedBox.shrink();

    late final IconData icon;
    late final Color color;
    late final String title;
    String? subtitle;

    switch (status) {
      case 'processing':
        icon = Icons.hourglass_top_outlined;
        color = const Color(0xFFEF6C00);
        title = 'Refund in progress';
        subtitle = 'This usually completes within a few minutes to a few days, depending on your bank.';
        break;
      case 'processed':
        icon = Icons.check_circle_outline;
        color = const Color(0xFF2E7D32);
        title = 'Refund of ₹${order.totalAmount.toStringAsFixed(2)} processed';
        subtitle = order.refundId != null ? 'Refund ID: ${order.refundId}' : null;
        break;
      case 'failed':
        icon = Icons.error_outline;
        color = const Color(0xFFE53935);
        title = 'Refund failed';
        subtitle = order.refundError ?? 'Please contact support to resolve this.';
        break;
      default:
        return const SizedBox.shrink();
    }

    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink, fontSize: 13.5)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: colors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
