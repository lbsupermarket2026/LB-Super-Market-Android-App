class DeliverySlabEntity {
  final double minKm;
  final double maxKm;
  final double charge;

  const DeliverySlabEntity({required this.minKm, required this.maxKm, required this.charge});
}

class DeliverySettingsEntity {
  final double? storeLatitude;
  final double? storeLongitude;
  final String storeAddress;
  final double minimumOrderAmount;
  final List<DeliverySlabEntity> slabs;
  final bool onlinePaymentsEnabled;

  const DeliverySettingsEntity({
    this.storeLatitude,
    this.storeLongitude,
    this.storeAddress = '',
    this.minimumOrderAmount = 200,
    this.slabs = const [],
    this.onlinePaymentsEnabled = true,
  });

  bool get hasStoreLocation => storeLatitude != null && storeLongitude != null;

  /// Returns the delivery charge for a distance, or null if it falls
  /// outside every configured slab (admin needs to add a slab covering
  /// it — treated as "delivery not available that far" by the caller).
  double? chargeForDistance(double distanceKm) {
    for (final slab in slabs) {
      if (distanceKm >= slab.minKm && distanceKm <= slab.maxKm) return slab.charge;
    }
    return null;
  }
}
