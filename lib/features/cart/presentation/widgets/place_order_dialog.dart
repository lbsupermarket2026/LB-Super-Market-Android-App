import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/config/payment_config.dart';
import '../../../addresses/domain/entities/address_entity.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../payments/domain/razorpay_checkout_service.dart';
import '../providers/cart_providers.dart';

class PlaceOrderDialog extends ConsumerStatefulWidget {
  const PlaceOrderDialog({super.key});

  @override
  ConsumerState<PlaceOrderDialog> createState() => _PlaceOrderDialogState();
}

class _PlaceOrderDialogState extends ConsumerState<PlaceOrderDialog> {
  final _addressController = TextEditingController();
  String? _selectedAddressId;
  PaymentMethod _paymentMethod = PaymentMethod.cod;
  bool _isPlacing = false;
  String? _error;

  late final RazorpayCheckoutService _razorpayService;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayCheckoutService();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _razorpayService.dispose();
    super.dispose();
  }

  /// Bridges Razorpay's callback-based SDK into something this dialog's
  /// normal async flow can just await — resolves with the payment ID on
  /// success, or null on failure/cancel.
  Future<String?> _collectUpiPayment({
    required double amount,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
  }) {
    final completer = Completer<String?>();

    _razorpayService.init(
      onSuccess: (PaymentSuccessResponse response) {
        if (!completer.isCompleted) completer.complete(response.paymentId);
      },
      onError: (PaymentFailureResponse response) {
        if (!completer.isCompleted) completer.complete(null);
      },
      onExternalWallet: (ExternalWalletResponse response) {
        // Selecting an external wallet isn't itself success or failure —
        // Razorpay will still follow up with one of the two above once
        // that flow finishes, so nothing to resolve here.
      },
    );

    _razorpayService.openUpiCheckout(
      amountInRupees: amount,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
    );

    return completer.future;
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

    final total = ref.read(cartTotalProvider);
    String? razorpayPaymentId;

    if (_paymentMethod == PaymentMethod.upi) {
      if (!PaymentConfig.isConfigured) {
        setState(() => _error =
            'UPI payment isn\'t set up yet — add a Razorpay test key in lib/core/config/payment_config.dart first.');
        return;
      }

      setState(() {
        _isPlacing = true;
        _error = null;
      });

      final paymentId = await _collectUpiPayment(
        amount: total,
        customerName: user.name ?? 'Customer',
        customerPhone: user.phone ?? '',
        customerEmail: user.email,
      );

      if (!mounted) return;

      if (paymentId == null) {
        setState(() {
          _isPlacing = false;
          _error = 'Payment was not completed. Nothing has been charged — try again or choose a different payment method.';
        });
        return;
      }
      razorpayPaymentId = paymentId;
    } else {
      setState(() {
        _isPlacing = true;
        _error = null;
      });
    }

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
          customerPhone: user.phone,
          paymentMethod: _paymentMethod.name,
          razorpayPaymentId: razorpayPaymentId,
        );

    if (!mounted) return;

    result.match(
      (failure) => setState(() {
        _isPlacing = false;
        _error = failure.message;
      }),
      (orderId) async {
        await ref.read(cartProvider.notifier).clear();
        // Without this, the Orders tab keeps showing whatever it last
        // fetched — since it stays mounted in the bottom nav shell, it
        // never naturally re-runs after a new order is created.
        ref.invalidate(myOrdersProvider);
        if (mounted) Navigator.pop(context, orderId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressListProvider);
    final addresses = addressesAsync.valueOrNull ?? [];

    return AlertDialog(
      title: const Text('Place Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UPI charges you now, through Razorpay. Cash and Card Swipe are settled in person on delivery/pickup.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            _PaymentMethodTile(
              method: PaymentMethod.upi,
              icon: Icons.qr_code_scanner,
              subtitle: 'PhonePe, GPay, Paytm, CRED, or any UPI app',
              selected: _paymentMethod,
              onSelect: (m) => setState(() => _paymentMethod = m),
            ),
            _PaymentMethodTile(
              method: PaymentMethod.cod,
              icon: Icons.payments_outlined,
              subtitle: 'Pay with cash when it arrives',
              selected: _paymentMethod,
              onSelect: (m) => setState(() => _paymentMethod = m),
            ),
            _PaymentMethodTile(
              method: PaymentMethod.cardSwipe,
              icon: Icons.credit_card,
              subtitle: 'Our delivery person will bring a card machine',
              selected: _paymentMethod,
              onSelect: (m) => setState(() => _paymentMethod = m),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (addresses.isNotEmpty) ...[
              Text('Use a saved address', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: addresses.map((AddressEntity address) {
                  final isSelected = address.id == _selectedAddressId;
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
                    onSelected: (_) => setState(() {
                      _selectedAddressId = address.id;
                      _addressController.text = address.formatted.replaceAll('\n', ', ');
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _addressController,
              maxLines: 3,
              onChanged: (_) {
                if (_selectedAddressId != null) setState(() => _selectedAddressId = null);
              },
              decoration: const InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isPlacing ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isPlacing ? null : _placeOrder,
          child: _isPlacing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_paymentMethod == PaymentMethod.upi ? 'Pay & Place Order' : 'Place Order'),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final PaymentMethod method;
  final IconData icon;
  final String subtitle;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelect;

  const _PaymentMethodTile({
    required this.method,
    required this.icon,
    required this.subtitle,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = method == selected;
    const green = Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? green.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? green : Colors.grey.shade300),
      ),
      child: RadioListTile<PaymentMethod>(
        value: method,
        groupValue: selected,
        onChanged: (v) => onSelect(v!),
        activeColor: green,
        dense: true,
        title: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? green : Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(method.label, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? green : Colors.black87)),
          ],
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ),
    );
  }
}
