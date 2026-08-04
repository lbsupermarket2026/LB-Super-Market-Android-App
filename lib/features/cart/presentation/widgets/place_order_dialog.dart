import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/config/payment_config.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../addresses/domain/entities/address_entity.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../addresses/presentation/widgets/address_form_dialog.dart';
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

  // Set right before _collectUpiPayment returns null for a failure —
  // read immediately after awaiting the call, in _placeOrder.
  bool _lastPaymentWasUserCancelled = false;

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
    _lastPaymentWasUserCancelled = false;
    final String razorpayOrderId;
    try {
      razorpayOrderId = await _razorpayServerService.createOrder(amount);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start payment — please try again.');
      return null;
    }

    final completer = Completer<PaymentSuccessResponse?>();

    // NEW: track whether the checkout sheet was explicitly cancelled
    // (Razorpay error code 2 — the person closed the sheet or backed
    // out before submitting) versus some other failure (network drop,
    // bank decline, etc.). A definite cancellation means nothing was
    // ever charged, so the order this attempt created can be safely
    // auto-cancelled instead of sitting around forever as "Payment
    // Pending" — genuinely ambiguous failures still get the original
    // safety-net treatment (order kept, for manual follow-up), since
    // those could be a charge that went through without the app
    // finding out.
    var wasUserCancelled = false;

    _razorpayService.init(
      onSuccess: (PaymentSuccessResponse response) {
        if (!completer.isCompleted) completer.complete(response);
      },
      onError: (PaymentFailureResponse response) {
        wasUserCancelled = response.code == 2; // Razorpay's "Payment Cancelled" code
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
    if (response == null) {
      _lastPaymentWasUserCancelled = wasUserCancelled;
      return null; // failed or cancelled at the checkout sheet
    }

    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      if (mounted) setState(() => _error = 'Payment response was incomplete — please try again.');
      return null;
    }

    final verified = await () async {
      try {
        return await _razorpayServerService.verifyPayment(
          razorpayOrderId: razorpayOrderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        );
      } catch (e) {
        // FIXED: this call had NO error handling at all. If it threw
        // for any reason (network blip, a Cloud Functions cold start,
        // anything) — which is a real possibility right after the
        // checkout sheet closes and control returns to the app — the
        // exception propagated straight up uncaught. That meant
        // _placeOrder's "if (paymentId == null)" handling below (the
        // whole point of which is to react to a failed/incomplete
        // payment) never ran at all, since the function had already
        // crashed out of its normal control flow. The order — already
        // created before checkout, sitting with paymentPending: true —
        // was left completely untouched forever, with _isPlacing never
        // reset either, so the UI could look permanently stuck. Now
        // this is caught and treated as "couldn't verify" (same as a
        // verified:false response), which the existing ambiguous-
        // failure path already handles correctly.
        return false;
      }
    }();

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

    if (_paymentMethod == PaymentMethod.upi && !PaymentConfig.isConfigured) {
      setState(() => _error =
          'Online payment isn\'t set up yet — add a Razorpay test key in lib/core/config/payment_config.dart first.');
      return;
    }

    setState(() {
      _isPlacing = true;
      _error = null;
    });

    // Order is created BEFORE the UPI checkout opens, not after — this
    // is what actually fixes the "paid but no order" bug. Razorpay may
    // hand off to a separate UPI app (GPay, PhonePe) to complete
    // payment, and if the app gets reclaimed by the OS during that
    // handoff, any in-memory state (like a Completer waiting for the
    // result) is lost when the person returns — the payment can
    // succeed while the app never finds out. Creating the order first
    // means it exists in Firestore (flagged paymentPending) regardless
    // of whether that callback ever arrives; markPaymentConfirmed just
    // clears the flag once it does. COD orders skip the pending state
    // entirely since there's no handoff risk for them.
    final createResult = await ref.read(createOrderUseCaseProvider).call(
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
          paymentPending: _paymentMethod == PaymentMethod.upi,
        );

    if (!mounted) return;

    final orderId = createResult.match(
      (failure) {
        setState(() {
          _isPlacing = false;
          _error = failure.message;
        });
        return null;
      },
      (id) => id,
    );
    if (orderId == null) return;

    if (_paymentMethod == PaymentMethod.upi) {
      final paymentId = await _collectUpiPayment(
        amount: total,
        customerName: user.name ?? 'Customer',
        customerPhone: user.phone ?? '',
        customerEmail: user.email,
      );

      if (!mounted) return;

      if (paymentId == null) {
        // FIXED: previously the order was always left sitting with
        // paymentPending: true regardless of why payment didn't
        // complete, which meant a plain "I changed my mind and closed
        // the checkout sheet" cancellation left a permanently-stuck
        // "Payment Pending" order cluttering both the customer's and
        // admin's order lists forever, even though nothing was ever
        // charged. Now: a CONFIRMED user cancellation (Razorpay error
        // code 2 — the sheet was closed/backed out of before
        // submitting) auto-cancels the order immediately, since we
        // know for certain no charge occurred. Any other failure
        // (network drop, bank decline, verification failure) keeps
        // the original safety-net behavior — the order stays as-is
        // for manual admin follow-up, since those cases genuinely
        // could be a charge that went through without the app
        // finding out, and losing that record would be worse.
        if (_lastPaymentWasUserCancelled) {
          await ref.read(cancelOrderUseCaseProvider).call(orderId);
          if (!mounted) return;
          setState(() {
            _isPlacing = false;
            _error = 'Payment was cancelled — no charge was made, and this order was not placed.';
          });
        } else {
          setState(() {
            _isPlacing = false;
            _error ??= 'Payment was not completed. If you were charged, this order is saved and our team will follow up — otherwise, nothing has been charged.';
          });
        }
        return;
      }

      // Payment genuinely succeeded at this point regardless of
      // whether this confirmation write itself succeeds — it's just a
      // bookkeeping step clearing the pending flag, so there's nothing
      // further to branch on here.
      await ref.read(markPaymentConfirmedUseCaseProvider).call(orderId, paymentId);
      if (!mounted) return;
    }

    await ref.read(cartProvider.notifier).clear();
    // Without this, the Orders tab keeps showing whatever it last
    // fetched — since it stays mounted in the bottom nav shell, it
    // never naturally re-runs after a new order is created.
    ref.invalidate(myOrdersProvider);
    if (mounted) Navigator.pop(context, orderId);
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
                  ? 'Online Payment charges you now, through Razorpay. Cash and Card Swipe are settled in person on delivery/pickup.'
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
            if (addresses.isNotEmpty) Text('Use a saved address', style: Theme.of(context).textTheme.labelMedium),
            if (addresses.isNotEmpty) const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...addresses.map((AddressEntity address) {
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
                }),
                // NEW: was previously only possible from the standalone
                // "My Addresses" screen — a customer with zero saved
                // addresses had no way to add one without leaving
                // checkout entirely. Opens the same AddressFormDialog
                // used there; on save it lands in addressListProvider
                // automatically (this widget watches that provider), and
                // we auto-select whichever address is new afterward.
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Address'),
                  onPressed: () async {
                    final existingIds = addresses.map((a) => a.id).toSet();
                    await showDialog(context: context, builder: (_) => const AddressFormDialog());
                    if (!mounted) return;
                    final refreshed = ref.read(addressListProvider).valueOrNull ?? [];
                    final added = refreshed.where((a) => !existingIds.contains(a.id)).toList();
                    if (added.isNotEmpty) {
                      final newAddress = added.first;
                      setState(() {
                        _selectedAddressId = newAddress.id;
                        _selectedAddress = newAddress;
                        _addressController.text = newAddress.formatted.replaceAll('\n', ', ');
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
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
    // FIXED: box was hardcoded Colors.grey.shade50/shade300 (a near-
    // white card in every theme), while the row labels/values below
    // had no explicit color and inherited dark mode's default LIGHT
    // text — light text on a near-white box was almost unreadable.
    // Now themed via context.appColors, with text colors passed
    // explicitly into _row so they always contrast with colors.card.
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(colors, 'Item total', '₹${pricing.subtotal.toStringAsFixed(0)}'),
          if (pricing.gstAmount > 0) _row(colors, 'GST', '₹${pricing.gstAmount.toStringAsFixed(0)}'),
          if (pricing.deliveryCharge != null)
            _row(colors, 'Delivery', '₹${pricing.deliveryCharge!.toStringAsFixed(0)}')
          else if (pricing.needsAddress)
            _row(colors, 'Delivery', 'Select an address'),
          Divider(height: 16, color: colors.divider),
          _row(colors, 'To pay', '₹${pricing.total.toStringAsFixed(0)}', bold: true),
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

  Widget _row(AppSemanticColors colors, String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: colors.ink)),
          Text(value, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? const Color(0xFF2E7D32) : colors.ink)),
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
