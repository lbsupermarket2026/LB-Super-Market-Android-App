import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../domain/entities/order_entity.dart';
import '../providers/order_providers.dart';
import '../widgets/order_status_stepper.dart';
import '../widgets/rate_order_dialog.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load this order.',
          onRetry: () => ref.invalidate(orderByIdProvider(orderId)),
        ),
        data: (order) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    OrderStatusStepper(status: order.status),
                    if (order.canCallDelivery)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('tel:${order.deliveryPersonPhone}');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                          icon: const Icon(Icons.call_outlined),
                          label: Text('Call ${order.deliveryPersonName ?? 'Delivery Person'}'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery Address', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(order.deliveryAddress),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        Text('Payment: ${order.paymentMethod.label}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: item.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            color: const Color(0xFFF3F3F3),
                                            child: const Icon(Icons.image_not_supported_outlined, color: Colors.black38, size: 20),
                                          ),
                                        )
                                      : Container(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          child: const Icon(Icons.image_outlined, size: 20),
                                        ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('Qty ${item.quantity}',
                                        style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Text('₹${item.lineTotal.toStringAsFixed(2)}'),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: Theme.of(context).textTheme.titleMedium),
                        Text('₹${order.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _RatingSection(order: order),
          ],
        ),
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  final OrderEntity order;
  const _RatingSection({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.isRated) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Rating', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < order.rating!.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
              ),
              if (order.ratingComment?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(order.ratingComment!),
              ],
            ],
          ),
        ),
      );
    }

    if (!order.canBeRated) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showDialog(context: context, builder: (_) => RateOrderDialog(orderId: order.id)),
        icon: const Icon(Icons.star_border),
        label: const Text('Rate this Order'),
      ),
    );
  }
}
