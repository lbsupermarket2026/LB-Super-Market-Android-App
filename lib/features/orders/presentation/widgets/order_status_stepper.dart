import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (status == OrderStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Text('Order Cancelled', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
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
                    color: isDone ? cs.primary : cs.outline,
                    size: 20,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: isDone ? cs.primary : cs.outlineVariant),
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
                    color: isDone ? null : cs.outline,
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
