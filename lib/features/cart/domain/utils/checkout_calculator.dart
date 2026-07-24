import 'package:geolocator/geolocator.dart';
import '../../../addresses/domain/entities/address_entity.dart';
import '../../../admin/delivery_settings/domain/entities/delivery_settings_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';

class CheckoutPricing {
  final double subtotal;
  final double gstAmount;
  final double? deliveryCharge; // null = out of delivery range or no address/store location yet
  final bool belowMinimumOrder;
  final bool outOfDeliveryRange;
  final double? distanceKm;

  const CheckoutPricing({
    required this.subtotal,
    required this.gstAmount,
    required this.deliveryCharge,
    required this.belowMinimumOrder,
    required this.outOfDeliveryRange,
    required this.distanceKm,
  });

  double get total => subtotal + gstAmount + (deliveryCharge ?? 0);
  bool get canCheckout => !belowMinimumOrder && !outOfDeliveryRange;
}

class CheckoutCalculator {
  /// Pure function — no Firestore calls of its own, everything it needs
  /// is passed in. Keeping the actual math separate from data-fetching
  /// makes it straightforward to reason about and test.
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

    double? distanceKm;
    double? deliveryCharge;
    bool outOfRange = false;

    if (deliverySettings.hasStoreLocation && deliveryAddress?.hasCoordinates == true) {
      final meters = Geolocator.distanceBetween(
        deliverySettings.storeLatitude!,
        deliverySettings.storeLongitude!,
        deliveryAddress!.latitude!,
        deliveryAddress.longitude!,
      );
      distanceKm = meters / 1000;
      deliveryCharge = deliverySettings.chargeForDistance(distanceKm);
      outOfRange = deliveryCharge == null;
    }
    // If store location isn't set up yet, or the address has no
    // coordinates (geocoding failed when it was saved), delivery charge
    // stays null rather than blocking checkout — treated as "not yet
    // calculable" rather than "too far," since that's admin/data setup
    // catching up, not a real distance problem.

    return CheckoutPricing(
      subtotal: subtotal,
      gstAmount: gstAmount,
      deliveryCharge: deliveryCharge,
      belowMinimumOrder: belowMinimum,
      outOfDeliveryRange: outOfRange,
      distanceKm: distanceKm,
    );
  }
}
