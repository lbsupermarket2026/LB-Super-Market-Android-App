import 'package:flutter/material.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../domain/entities/order_entity.dart';

class OrderStatusStepper extends StatelessWidget {
  final OrderStatus status;
  const OrderStatusStepper({super.key, required this.status});

  static const _steps = [
    OrderStatus.placed,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  static const _green = Color(0xFF2E7D32);
  static const _red = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    // FIXED: completed-step labels had color: null, which inherits
    // the ambient default text color — this wasn't reliably reading
    // as light/white against the dark-tinted "Track Your Order" card
    // in dark mode. Now explicit via context.appColors, same pattern
    // used everywhere else in the app.
    final colors = context.appColors;

    if (status == OrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel, color: _red, size: 20),
          const SizedBox(width: 8),
          Text('Order Cancelled', style: TextStyle(color: _red, fontWeight: FontWeight.w600)),
        ],
      );
    }

    final currentIndex = _steps.indexOf(status);

    return Column(
      children: List.generate(_steps.length, (i) {
        final isDone = i <= currentIndex;
        final isLast = i == _steps.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone ? _green : colors.muted,
                    size: 20,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: isDone ? _green : colors.divider),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _steps[i].label,
                  style: TextStyle(
                    fontWeight: isDone ? FontWeight.w700 : FontWeight.w400,
                    color: isDone ? colors.ink : colors.muted,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
