import '../../../addresses/domain/entities/address_entity.dart';
import '../../../admin/delivery_settings/domain/entities/delivery_settings_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';

class CheckoutPricing {
  // NEW: originalSubtotal/discountAmount split out from what used to
  // be just "subtotal" — needed to show a real bill breakdown
  // (original price, discount, discounted price) rather than only
  // the final post-discount figure.
  final double originalSubtotal;
  final double discountAmount;
  final double subtotal; // post-discount — originalSubtotal - discountAmount
  final double gstAmount; // sgstAmount + cgstAmount
  final double sgstAmount;
  final double cgstAmount;
  final double? deliveryCharge; // null only when needsAddress is true
  final bool belowMinimumOrder;
  final bool needsAddress; // true = no confirmed/pinpointed location yet

  const CheckoutPricing({
    required this.originalSubtotal,
    required this.discountAmount,
    required this.subtotal,
    required this.gstAmount,
    required this.sgstAmount,
    required this.cgstAmount,
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
    final originalSubtotal = items.fold(0.0, (sum, i) => sum + i.originalLineTotal);
    final subtotal = items.fold(0.0, (sum, i) => sum + i.lineTotal);
    final discountAmount = originalSubtotal - subtotal;

    // Each item's GST comes from its own category — a cart with items
    // from a 5%-GST category and a 12%-GST category charges each item
    // its own rate, not one blended rate for the whole order. Split
    // evenly into SGST + CGST (standard for an intra-state sale,
    // which covers a single local supermarket) rather than one
    // combined GST line.
    final gstAmount = items.fold(0.0, (sum, item) {
      final category = item.categoryId != null ? categoriesById[item.categoryId] : null;
      final gstPercent = category?.gstPercent ?? 0;
      return sum + (item.lineTotal * gstPercent / 100);
    });
    final sgstAmount = gstAmount / 2;
    final cgstAmount = gstAmount / 2;

    final belowMinimum = subtotal < deliverySettings.minimumOrderAmount;
    final needsAddress = !(deliveryAddress?.hasCoordinates == true);
    final deliveryCharge = needsAddress ? null : deliverySettings.flatDeliveryCharge;

    return CheckoutPricing(
      originalSubtotal: originalSubtotal,
      discountAmount: discountAmount,
      subtotal: subtotal,
      gstAmount: gstAmount,
      sgstAmount: sgstAmount,
      cgstAmount: cgstAmount,
      deliveryCharge: deliveryCharge,
      belowMinimumOrder: belowMinimum,
      needsAddress: needsAddress,
    );
  }
}
