class BusinessHourEntity {
  final String day;
  final String openTime;
  final String closeTime;
  const BusinessHourEntity({required this.day, required this.openTime, required this.closeTime});
}

class BusinessInfoEntity {
  final String aboutUsText;
  final String? physicalAddress;
  final String? contactPhone;
  final String? contactEmail;
  final String? instagram;
  final String? facebook;
  final String? whatsappBusinessNumber;
  final List<BusinessHourEntity> businessHours;

  const BusinessInfoEntity({
    this.aboutUsText = '',
    this.physicalAddress,
    this.contactPhone,
    this.contactEmail,
    this.instagram,
    this.facebook,
    this.whatsappBusinessNumber,
    this.businessHours = const [],
  });
}