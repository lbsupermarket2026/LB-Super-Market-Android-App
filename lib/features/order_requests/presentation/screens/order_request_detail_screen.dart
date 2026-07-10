import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/order_request_entity.dart';
import '../providers/order_request_providers.dart';

/// Order requests (Type my list / Upload a photo) use a simpler 3-state
/// flow than real orders — Pending -> Confirmed (or Cancelled) — because
/// there's no admin panel yet to drive a fuller pipeline. Once staff
/// confirm by phone, they'd flip status in Firestore, and this screen
/// reflects it live via the same list provider Orders uses.
class OrderRequestDetailScreen extends ConsumerWidget {
  final String requestId;
  const OrderRequestDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the underlying list provider alive/fresh so this screen
    // reflects live status changes without a separate fetch.
    ref.watch(myOrderRequestsProvider);
    final request = ref.watch(orderByIdInRequestsProvider(requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Track Your Request')),
      body: request == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                        _RequestStatusTracker(status: request.status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.call_outlined, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request.status == OrderRequestStatus.pending
                              ? "We'll call ${request.contactPhone} shortly to confirm your order and the estimated price."
                              : request.status == OrderRequestStatus.confirmed
                                  ? 'Confirmed! Your order is being prepared.'
                                  : 'This request was cancelled.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.type == OrderRequestType.photo ? 'Your Photo' : 'Your List',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (request.type == OrderRequestType.typedList)
                          ...request.itemLines.map((line) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text('• $line'),
                              ))
                        else if (request.photoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(request.photoUrl!, height: 160, fit: BoxFit.cover),
                          ),
                        const Divider(height: 24),
                        Text('Fulfillment', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          request.fulfillmentMethod == FulfillmentMethod.delivery
                              ? 'Home Delivery — ${request.deliveryAddress ?? ""}'
                              : 'In-Store Pickup',
                        ),
                        const SizedBox(height: 8),
                        Text('Cash on Delivery', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RequestStatusTracker extends StatelessWidget {
  final OrderRequestStatus status;
  const _RequestStatusTracker({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (status == OrderRequestStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Text('Cancelled', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ],
      );
    }

    final steps = ['Request Received', 'Confirmed by Team'];
    final currentIndex = status == OrderRequestStatus.confirmed ? 1 : 0;

    return Column(
      children: List.generate(steps.length, (i) {
        final isDone = i <= currentIndex;
        final isLast = i == steps.length - 1;
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
                  if (!isLast) Expanded(child: Container(width: 2, color: isDone ? cs.primary : cs.outlineVariant)),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  steps[i],
                  style: TextStyle(fontWeight: isDone ? FontWeight.w700 : FontWeight.w400, color: isDone ? null : cs.outline),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
