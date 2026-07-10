import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../addresses/domain/entities/address_entity.dart';
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

class _SavedAddressPicker extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<AddressEntity> onSelected;
  const _SavedAddressPicker({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressListProvider);
    final addresses = addressesAsync.valueOrNull ?? [];

    if (addresses.isEmpty) {
      // No saved addresses yet — the free-text field below still works
      // fine on its own, this is purely a shortcut when one exists.
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Use a saved address', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: addresses.map((address) {
            final isSelected = address.id == selectedId;
            return ChoiceChip(
              avatar: Icon(
                address.label == 'Home'
                    ? Icons.home_outlined
                    : address.label == 'Work'
                        ? Icons.work_outline
                        : Icons.location_on_outlined,
                size: 16,
                color: isSelected ? Colors.white : null,
              ),
              label: Text(address.label),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : null),
              onSelected: (_) => onSelected(address),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ReviewOrderRequestScreenState extends ConsumerState<ReviewOrderRequestScreen> {
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  FulfillmentMethod _method = FulfillmentMethod.delivery;
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _phoneController.text = user?.phone ?? '';
    // No address auto-fill here — leaving this blank until the person
    // either taps a saved address chip or types their own, so nothing
    // shows up unexpectedly.
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

    final requestId = await ref.read(orderRequestSubmitterProvider.notifier).submit(
          type: widget.type,
          itemLines: widget.itemLines,
          photoFile: widget.photoFile,
          contactPhone: _phoneController.text.trim(),
          fulfillmentMethod: _method,
          deliveryAddress: _method == FulfillmentMethod.delivery ? _addressController.text.trim() : null,
        );

    if (!mounted) return;

    if (requestId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent! Our team will call you shortly to confirm.')),
      );
      context.go('/order-requests/$requestId');
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
            _SavedAddressPicker(
              selectedId: _selectedAddressId,
              onSelected: (address) => setState(() {
                _selectedAddressId = address.id;
                _addressController.text = address.formatted.replaceAll('\n', ', ');
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _addressController,
              maxLines: 3,
              onChanged: (_) {
                if (_selectedAddressId != null) setState(() => _selectedAddressId = null);
              },
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
