class AdminNotificationEntity {
  final String id;
  final String type; // 'new_order' | 'low_stock'
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? orderId;
  final String? productId;

  const AdminNotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.orderId,
    this.productId,
  });
}
