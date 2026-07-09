import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/order_request_entity.dart';
import '../providers/order_request_providers.dart';

class ReviewOrderRequestScreen extends ConsumerStatefulWidget {
  final OrderRequestType type;
  final List<String> itemLines;
  final File? photoFile;

  const ReviewOrderRequestScreen({
    super.key,
    required this.type,
    this.itemLines = const [],
    this.photoFile,
  });

  @override
  ConsumerState<ReviewOrderRequestScreen> createState() => _ReviewOrderRequestScreenState();
}

class _ReviewOrderRequestScreenState extends ConsumerState<ReviewOrderRequestScreen> {
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  FulfillmentMethod _method = FulfillmentMethod.delivery;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _phoneController.text = user?.phone ?? '';

    final addresses = ref.read(addressListProvider).valueOrNull ?? [];
    if (addresses.isNotEmpty) {
      final defaultAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
      _addressController.text = defaultAddress.formatted.replaceAll('\n', ', ');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number.')),
      );
      return;
    }
    if (_method == FulfillmentMethod.delivery && _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address.')),
      );
      return;
    }

    final success = await ref.read(orderRequestSubmitterProvider.notifier).submit(
          type: widget.type,
          itemLines: widget.itemLines,
          photoFile: widget.photoFile,
          contactPhone: _phoneController.text.trim(),
          fulfillmentMethod: _method,
          deliveryAddress: _method == FulfillmentMethod.delivery ? _addressController.text.trim() : null,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent! Our team will call you shortly to confirm.')),
      );
      context.go('/orders');
    } else {
      final error = ref.read(orderRequestSubmitterProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Something went wrong.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(orderRequestSubmitterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Review & Place Order')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your List', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (widget.type == OrderRequestType.typedList)
                    ...widget.itemLines.map((line) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $line'),
                        ))
                  else if (widget.photoFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(widget.photoFile!, height: 160, fit: BoxFit.cover),
                    ),
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
            child: const Row(
              children: [
                Icon(Icons.payments_outlined, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cash on Delivery only. Our team will call you to confirm your order and estimated price before packing.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Your Mobile Number', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Fulfillment', style: theme.textTheme.titleMedium),
          RadioListTile<FulfillmentMethod>(
            value: FulfillmentMethod.delivery,
            groupValue: _method,
            title: const Text('Home Delivery'),
            onChanged: (v) => setState(() => _method = v!),
          ),
          RadioListTile<FulfillmentMethod>(
            value: FulfillmentMethod.pickup,
            groupValue: _method,
            title: const Text('In-Store Pickup'),
            onChanged: (v) => setState(() => _method = v!),
          ),
          if (_method == FulfillmentMethod.delivery) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: ElevatedButton(
          onPressed: submission.isSubmitting ? null : _submit,
          child: submission.isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Place Order'),
        ),
      ),
    );
  }
}
