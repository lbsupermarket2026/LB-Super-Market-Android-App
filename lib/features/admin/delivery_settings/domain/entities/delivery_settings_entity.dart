class DeliverySettingsEntity {
  final double? storeLatitude;
  final double? storeLongitude;
  final String storeAddress;
  final double minimumOrderAmount;
  final double flatDeliveryCharge;
  final bool onlinePaymentsEnabled;
  final String gstNumber;

  const DeliverySettingsEntity({
    this.storeLatitude,
    this.storeLongitude,
    this.storeAddress = '',
    this.minimumOrderAmount = 200,
    this.flatDeliveryCharge = 30,
    this.onlinePaymentsEnabled = true,
    this.gstNumber = '',
  });

  bool get hasStoreLocation => storeLatitude != null && storeLongitude != null;
}
