import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/config/payment_config.dart';
import '../../../addresses/domain/entities/address_entity.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../admin/delivery_settings/presentation/providers/delivery_settings_providers.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../payments/domain/razorpay_checkout_service.dart';
import '../../../payments/domain/razorpay_server_service.dart';
import '../../domain/utils/checkout_calculator.dart';
import '../providers/cart_providers.dart';

class PlaceOrderDialog extends ConsumerStatefulWidget {
  const PlaceOrderDialog({super.key});

  @override
  ConsumerState<PlaceOrderDialog> createState() => _PlaceOrderDialogState();
}

class _PlaceOrderDialogState extends ConsumerState<PlaceOrderDialog> {
  final _addressController = TextEditingController();
  String? _selectedAddressId;
  AddressEntity? _selectedAddress;
  PaymentMethod _paymentMethod = PaymentMethod.cod;
  bool _isPlacing = false;
  String? _error;

  late final RazorpayCheckoutService _razorpayService;
  final _razorpayServerService = RazorpayServerService();

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
  /// normal async flow can just await. Two server round-trips bracket
  /// the actual checkout: an order is created server-side first (so the
  /// charged amount is decided by the server, not whatever the client
  /// claims), and the payment is verified server-side after (so a
  /// tampered client can't just fake a success callback). Returns the
  /// payment ID only once both of those have genuinely happened.
  Future<String?> _collectUpiPayment({
    required double amount,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
  }) async {
    final String razorpayOrderId;
    try {
      razorpayOrderId = await _razorpayServerService.createOrder(amount);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start payment — please try again.');
      return null;
    }

    final completer = Completer<PaymentSuccessResponse?>();

    _razorpayService.init(
      onSuccess: (PaymentSuccessResponse response) {
        if (!completer.isCompleted) completer.complete(response);
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
      orderId: razorpayOrderId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
    );

    final response = await completer.future;
    if (response == null) return null; // failed or cancelled at the checkout sheet

    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      if (mounted) setState(() => _error = 'Payment response was incomplete — please try again.');
      return null;
    }

    final verified = await _razorpayServerService.verifyPayment(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: paymentId,
      razorpaySignature: signature,
    );

    if (!verified) {
      if (mounted) {
        setState(() => _error =
            'Payment could not be verified — if money was deducted, it will be refunded automatically. Please try again.');
      }
      return null;
    }

    return paymentId;
  }

  Future<void> _placeOrder(CheckoutPricing? pricing) async {
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

    // Falls back to a plain subtotal only if delivery settings genuinely
    // haven't loaded yet — the button itself is already disabled
    // whenever pricing says checkout isn't allowed, so reaching here
    // with a below-minimum or out-of-range order shouldn't happen.
    final total = pricing?.total ?? cartItems.fold<double>(0.0, (sum, i) => sum + i.lineTotal);
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
          // A more specific message may already be set (couldn't start
          // payment / couldn't verify) — only fall back to the generic
          // one if nothing more specific applies.
          _error ??= 'Payment was not completed. Nothing has been charged — try again or choose a different payment method.';
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
                    'categoryId': i.categoryId,
                  })
              .toList(),
          totalAmount: total,
          deliveryAddress: _addressController.text.trim(),
          customerPhone: user.phone,
          deliveryLatitude: _selectedAddress?.latitude,
          deliveryLongitude: _selectedAddress?.longitude,
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
    final cartItems = ref.watch(cartProvider).valueOrNull ?? [];
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);
    final deliverySettingsAsync = ref.watch(deliverySettingsProvider);

    final onlinePaymentsEnabled = deliverySettingsAsync.valueOrNull?.onlinePaymentsEnabled ?? true;
    if (!onlinePaymentsEnabled && _paymentMethod == PaymentMethod.upi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _paymentMethod = PaymentMethod.cod);
      });
    }

    final categoriesById = <String, CategoryEntity>{
      for (final c in categoriesAsync.valueOrNull ?? <CategoryEntity>[]) c.id: c,
    };

    final pricing = deliverySettingsAsync.valueOrNull == null
        ? null
        : CheckoutCalculator.calculate(
            items: cartItems,
            categoriesById: categoriesById,
            deliverySettings: deliverySettingsAsync.valueOrNull!,
            deliveryAddress: _selectedAddress,
          );

    return AlertDialog(
      title: const Text('Place Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              onlinePaymentsEnabled
                  ? 'UPI charges you now, through Razorpay. Cash and Card Swipe are settled in person on delivery/pickup.'
                  : 'Cash and Card Swipe are settled in person on delivery/pickup.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (onlinePaymentsEnabled)
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
                      _selectedAddress = address;
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
                if (_selectedAddressId != null) {
                  setState(() {
                    _selectedAddressId = null;
                    _selectedAddress = null;
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()),
            ),
            if (pricing != null) ...[
              const SizedBox(height: 16),
              _PricingSummary(pricing: pricing, minimumOrder: deliverySettingsAsync.valueOrNull!.minimumOrderAmount),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isPlacing ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_isPlacing || pricing?.canCheckout == false) ? null : () => _placeOrder(pricing),
          child: _isPlacing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_paymentMethod == PaymentMethod.upi ? 'Pay & Place Order' : 'Place Order'),
        ),
      ],
    );
  }
}

class _PricingSummary extends StatelessWidget {
  final CheckoutPricing pricing;
  final double minimumOrder;
  const _PricingSummary({required this.pricing, required this.minimumOrder});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE53935);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Item total', '₹${pricing.subtotal.toStringAsFixed(0)}'),
          if (pricing.gstAmount > 0) _row('GST', '₹${pricing.gstAmount.toStringAsFixed(0)}'),
          if (pricing.deliveryCharge != null)
            _row('Delivery', '₹${pricing.deliveryCharge!.toStringAsFixed(0)}')
          else if (pricing.needsAddress)
            _row('Delivery', 'Select an address'),
          const Divider(height: 16),
          _row('To pay', '₹${pricing.total.toStringAsFixed(0)}', bold: true),
          if (pricing.belowMinimumOrder) ...[
            const SizedBox(height: 8),
            Text(
              'Minimum order for delivery is ₹${minimumOrder.toStringAsFixed(0)} — add ₹${(minimumOrder - pricing.subtotal).toStringAsFixed(0)} more to checkout.',
              style: const TextStyle(color: red, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (pricing.needsAddress) ...[
            const SizedBox(height: 8),
            const Text(
              'Pick a saved address, or add a new one and confirm its exact location with "Pinpoint on Map" — we need this to place the order.',
              style: TextStyle(color: red, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? const Color(0xFF2E7D32) : null)),
        ],
      ),
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
            Expanded(
              child: Text(
                method.label,
                style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? green : Colors.black87),
              ),
            ),
          ],
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ),
    );
  }
}
