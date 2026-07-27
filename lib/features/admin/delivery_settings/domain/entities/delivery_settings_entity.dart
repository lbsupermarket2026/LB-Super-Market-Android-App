/// Delivery is priced by pincode rather than measured distance —
/// distance calculation depended on geocoding accuracy, which was
/// unreliable for informal address text (a real address a short drive
/// from the store could geocode to the wrong spot and get flagged as
/// "outside delivery range"). Pincode is something the customer
/// enters directly and is unambiguous, so this is the more reliable
/// mechanism for an area-based local delivery service.
class PincodeChargeEntity {
  final String pincode;
  final double charge;

  const PincodeChargeEntity({required this.pincode, required this.charge});
}

class DeliverySettingsEntity {
  final double? storeLatitude;
  final double? storeLongitude;
  final String storeAddress;
  final double minimumOrderAmount;
  final List<PincodeChargeEntity> pincodeCharges;
  final bool onlinePaymentsEnabled;
  final String gstNumber;

  const DeliverySettingsEntity({
    this.storeLatitude,
    this.storeLongitude,
    this.storeAddress = '',
    this.minimumOrderAmount = 200,
    this.pincodeCharges = const [],
    this.onlinePaymentsEnabled = true,
    this.gstNumber = '',
  });

  bool get hasStoreLocation => storeLatitude != null && storeLongitude != null;

  /// Returns the delivery charge for a pincode, or null if that
  /// pincode isn't in the configured list — treated as "delivery not
  /// available there yet" by the caller, same as before.
  double? chargeForPincode(String pincode) {
    for (final entry in pincodeCharges) {
      if (entry.pincode.trim() == pincode.trim()) return entry.charge;
    }
    return null;
  }
}
