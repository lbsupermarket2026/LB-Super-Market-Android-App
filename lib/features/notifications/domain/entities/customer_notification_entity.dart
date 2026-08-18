class CustomerNotificationEntity {
  final String id;
  final String type; // 'order_status' | 'new_offer'
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? orderId;
  final String? offerId;
  final List<String> hiddenFor;

  const CustomerNotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.orderId,
    this.offerId,
    this.hiddenFor = const [],
  });
}