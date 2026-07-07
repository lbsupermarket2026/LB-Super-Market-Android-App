class AddressEntity {
  final String id;
  final String label; // Home / Work / Other
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String pincode;
  final String phone;
  final bool isDefault;

  const AddressEntity({
    required this.id,
    required this.label,
    required this.line1,
    this.line2 = '',
    required this.city,
    required this.state,
    required this.pincode,
    this.phone = '',
    this.isDefault = false,
  });

  String get formatted => [
        line1,
        if (line2.isNotEmpty) line2,
        '$city, $state $pincode',
      ].join('\n');

  AddressEntity copyWith({
    String? label,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    bool? isDefault,
  }) {
    return AddressEntity(
      id: id,
      label: label ?? this.label,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'line1': line1,
        'line2': line2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'isDefault': isDefault,
      };

  factory AddressEntity.fromJson(Map<String, dynamic> json) => AddressEntity(
        id: json['id'] as String,
        label: json['label'] as String,
        line1: json['line1'] as String,
        line2: json['line2'] as String? ?? '',
        city: json['city'] as String,
        state: json['state'] as String,
        pincode: json['pincode'] as String,
        phone: json['phone'] as String? ?? '',
        isDefault: json['isDefault'] as bool? ?? false,
      );
}
