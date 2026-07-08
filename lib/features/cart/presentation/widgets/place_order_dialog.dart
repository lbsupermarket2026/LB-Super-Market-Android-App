import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../providers/cart_providers.dart';

class PlaceOrderDialog extends ConsumerStatefulWidget {
  const PlaceOrderDialog({super.key});

  @override
  ConsumerState<PlaceOrderDialog> createState() => _PlaceOrderDialogState();
}

class _PlaceOrderDialogState extends ConsumerState<PlaceOrderDialog> {
  final _addressController = TextEditingController();
  bool _isPlacing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prefill from the default saved address, if there is one — still
    // editable, since this is a simple text field, not address-selection.
    final addresses = ref.read(addressListProvider).valueOrNull ?? [];
    if (addresses.isNotEmpty) {
      final defaultAddress = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
      _addressController.text = defaultAddress.formatted.replaceAll('\n', ', ');
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_addressController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a delivery address.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'You need to be signed in to place an order.');
      return;
    }

    final cartItems = ref.read(cartProvider).valueOrNull ?? [];
    if (cartItems.isEmpty) return;

    setState(() {
      _isPlacing = true;
      _error = null;
    });

    final total = ref.read(cartTotalProvider);
    final result = await ref.read(createOrderUseCaseProvider).call(
          userId: user.uid,
          items: cartItems
              .map((i) => {
                    'productId': i.productId,
                    'name': i.name,
                    'unit': i.unit,
                    'imageUrl': i.imageUrl,
                    'price': i.price,
                    'quantity': i.quantity,
                  })
              .toList(),
          totalAmount: total,
          deliveryAddress: _addressController.text.trim(),
        );

    if (!mounted) return;

    result.match(
      (failure) => setState(() {
        _isPlacing = false;
        _error = failure.message;
      }),
      (orderId) async {
        await ref.read(cartProvider.notifier).clear();
        if (mounted) Navigator.pop(context, orderId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Place Order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This creates your order without online payment for now — pay on delivery.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextField(
            controller: _addressController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isPlacing ? null : _placeOrder,
          child: _isPlacing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Place Order'),
        ),
      ],
    );
  }
}
