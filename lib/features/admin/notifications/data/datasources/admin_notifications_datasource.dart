import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/admin_notification_entity.dart';

class AdminNotificationsDataSource {
  final FirebaseFirestore _firestore;
  AdminNotificationsDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('notifications');

  /// Live stream so the badge count and list update the moment a Cloud
  /// Function writes a new one — no manual refresh needed. No orderBy
  /// (avoids another composite-index requirement); sorted client-side.
  Stream<List<AdminNotificationEntity>> watchAll() {
    return _collection
        .where('type', whereIn: ['new_order', 'low_stock'])
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return AdminNotificationEntity(
          id: doc.id,
          type: (data['type'] as String?) ?? '',
          title: (data['title'] as String?) ?? '',
          body: (data['body'] as String?) ?? '',
          isRead: (data['isRead'] as bool?) ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          orderId: data['orderId'] as String?,
          productId: data['productId'] as String?,
        );
      }).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  Future<void> markAsRead(String id) async {
    await _collection.doc(id).update({'isRead': true});
  }

  Future<void> markAllAsRead(List<String> ids) async {
    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_collection.doc(id), {'isRead': true});
    }
    await batch.commit();
  }
}
