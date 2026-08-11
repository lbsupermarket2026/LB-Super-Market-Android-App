class AdminNotificationEntity {
  final String id;
  final String type; // 'new_order' | 'low_stock' | 'new_order_request' | 'order_cancelled'
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? orderId;
  final String? productId;
  // NEW: for 'new_order_request' notifications (Type My List / photo
  // submissions), pointing at the order_requests collection.
  final String? requestId;

  const AdminNotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.orderId,
    this.productId,
    this.requestId,
  });
}
