import '../../../addresses/domain/entities/address_entity.dart';
import '../../../admin/delivery_settings/domain/entities/delivery_settings_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';

class CheckoutPricing {
  final double subtotal;
  final double gstAmount;
  final double? deliveryCharge; // null = out of delivery range or no pincode yet
  final bool belowMinimumOrder;
  final bool outOfDeliveryRange;

  const CheckoutPricing({
    required this.subtotal,
    required this.gstAmount,
    required this.deliveryCharge,
    required this.belowMinimumOrder,
    required this.outOfDeliveryRange,
  });

  double get total => subtotal + gstAmount + (deliveryCharge ?? 0);
  bool get canCheckout => !belowMinimumOrder && !outOfDeliveryRange;
}

class CheckoutCalculator {
  /// Pure function — no Firestore calls of its own, everything it needs
  /// is passed in. Delivery is priced by pincode (exact match against
  /// what admin has configured) rather than measured distance — more
  /// reliable than geocoding informal address text, and matches how a
  /// local delivery service actually decides where it delivers.
  static CheckoutPricing calculate({
    required List<CartItemEntity> items,
    required Map<String, CategoryEntity> categoriesById,
    required DeliverySettingsEntity deliverySettings,
    required AddressEntity? deliveryAddress,
  }) {
    final subtotal = items.fold(0.0, (sum, i) => sum + i.lineTotal);

    // Each item's GST comes from its own category — a cart with items
    // from a 5%-GST category and a 12%-GST category charges each item
    // its own rate, not one blended rate for the whole order.
    final gstAmount = items.fold(0.0, (sum, item) {
      final category = item.categoryId != null ? categoriesById[item.categoryId] : null;
      final gstPercent = category?.gstPercent ?? 0;
      return sum + (item.lineTotal * gstPercent / 100);
    });

    final belowMinimum = subtotal < deliverySettings.minimumOrderAmount;

    double? deliveryCharge;
    bool outOfRange = false;

    final pincode = deliveryAddress?.pincode.trim();
    if (pincode != null && pincode.isNotEmpty) {
      deliveryCharge = deliverySettings.chargeForPincode(pincode);
      outOfRange = deliveryCharge == null;
    }
    // No address/pincode yet → delivery charge stays null without
    // flagging out-of-range, same "not yet calculable" treatment as
    // before — this is the checkout screen waiting on input, not a
    // real delivery problem.

    return CheckoutPricing(
      subtotal: subtotal,
      gstAmount: gstAmount,
      deliveryCharge: deliveryCharge,
      belowMinimumOrder: belowMinimum,
      outOfDeliveryRange: outOfRange,
    );
  }
}
