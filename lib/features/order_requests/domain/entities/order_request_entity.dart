enum OrderRequestType { typedList, photo }

enum FulfillmentMethod { delivery, pickup }

enum OrderRequestStatus { pending, confirmed, cancelled }

extension OrderRequestStatusX on OrderRequestStatus {
  String get label {
    switch (this) {
      case OrderRequestStatus.pending:
        return 'Pending Confirmation';
      case OrderRequestStatus.confirmed:
        return 'Confirmed';
      case OrderRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  static OrderRequestStatus fromString(String value) {
    return OrderRequestStatus.values.firstWhere((s) => s.name == value, orElse: () => OrderRequestStatus.pending);
  }
}

class OrderRequestEntity {
  final String id;
  final String userId;
  final OrderRequestType type;
  final List<String> itemLines; // free-text lines, only for typedList
  final String? photoUrl; // only for photo type
  final String contactPhone;
  final FulfillmentMethod fulfillmentMethod;
  final String? deliveryAddress; // required when fulfillmentMethod == delivery
  final OrderRequestStatus status;
  final DateTime createdAt;

  const OrderRequestEntity({
    required this.id,
    required this.userId,
    required this.type,
    this.itemLines = const [],
    this.photoUrl,
    required this.contactPhone,
    required this.fulfillmentMethod,
    this.deliveryAddress,
    required this.status,
    required this.createdAt,
  });
}
