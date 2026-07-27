import '../../../addresses/domain/entities/address_entity.dart';
import '../../../admin/delivery_settings/domain/entities/delivery_settings_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';

class CheckoutPricing {
  final double subtotal;
  final double gstAmount;
  final double? deliveryCharge; // null only when needsAddress is true
  final bool belowMinimumOrder;
  final bool needsAddress; // true = no confirmed/pinpointed location yet

  const CheckoutPricing({
    required this.subtotal,
    required this.gstAmount,
    required this.deliveryCharge,
    required this.belowMinimumOrder,
    required this.needsAddress,
  });

  double get total => subtotal + gstAmount + (deliveryCharge ?? 0);
  bool get canCheckout => !belowMinimumOrder && !needsAddress;
}

class CheckoutCalculator {
  /// Pure function — no Firestore calls of its own, everything it needs
  /// is passed in. No distance/zone calculation anymore — that kept
  /// producing false "outside delivery range" results depending on
  /// geocoding accuracy. Now it's simple: a confirmed address (has
  /// real coordinates, from a saved address or "Pinpoint on Map")
  /// gets the flat delivery charge; no confirmed address blocks
  /// checkout rather than guessing.
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
    final needsAddress = !(deliveryAddress?.hasCoordinates == true);
    final deliveryCharge = needsAddress ? null : deliverySettings.flatDeliveryCharge;

    return CheckoutPricing(
      subtotal: subtotal,
      gstAmount: gstAmount,
      deliveryCharge: deliveryCharge,
      belowMinimumOrder: belowMinimum,
      needsAddress: needsAddress,
    );
  }
}
