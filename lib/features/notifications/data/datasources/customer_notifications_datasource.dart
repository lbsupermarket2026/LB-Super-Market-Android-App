import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/customer_notification_entity.dart';

class CustomerNotificationsDataSource {
  final FirebaseFirestore _firestore;
  CustomerNotificationsDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('notifications');

  CustomerNotificationEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CustomerNotificationEntity(
      id: doc.id,
      type: (data['type'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      isRead: (data['isRead'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderId: data['orderId'] as String?,
      offerId: data['offerId'] as String?,
    );
  }

  /// This customer's own notifications (order status changes).
  Stream<List<CustomerNotificationEntity>> watchPersonal(String uid) {
    return _collection.where('uid', isEqualTo: uid).snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }

  /// Broadcast notifications (new offers) — uid is null on these, sent
  /// to every customer rather than one write per person.
  Stream<List<CustomerNotificationEntity>> watchBroadcast() {
    return _collection.where('uid', isNull: true).snapshots().map((s) => s.docs.map(_fromDoc).toList());
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