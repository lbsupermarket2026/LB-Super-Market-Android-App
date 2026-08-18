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
      // NEW: which uids have "cleared" this broadcast for themselves.
      // A broadcast is shared across every customer, so it can't
      // actually be DELETED by one person (that would remove it for
      // everyone) — instead each person's own uid gets added here
      // when they clear it, and the provider filters it out of THEIR
      // view specifically. Empty for personal notifications, which
      // are genuinely deleted instead.
      hiddenFor: (data['hiddenFor'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
  }

  /// This customer's own notifications (order status changes).
  Stream<List<CustomerNotificationEntity>> watchPersonal(String uid) {
    return _collection.where('uid', isEqualTo: uid).snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }

  /// Broadcast notifications (new offers, admin announcements) — uid
  /// is null on these, sent to every customer rather than one write
  /// per person.
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

  /// Deletes every given notification outright — for PERSONAL
  /// notifications only (the caller is responsible for not passing
  /// broadcast ids here; see hideBroadcastForUser below for those).
  /// Chunked to stay under Firestore's 500-writes-per-batch cap.
  Future<void> deleteAll(List<String> ids) async {
    for (var i = 0; i < ids.length; i += 450) {
      final chunk = ids.skip(i).take(450);
      final batch = _firestore.batch();
      for (final id in chunk) {
        batch.delete(_collection.doc(id));
      }
      await batch.commit();
    }
  }

  /// NEW: "clears" a broadcast notification for ONE specific person,
  /// without touching the shared document itself — every other
  /// customer still sees it normally. This is what makes "Clear all"
  /// actually work for offers/announcements: those can't be deleted
  /// by a regular user (Firestore rules correctly block that, since
  /// deleting a shared doc would remove it for everyone), so instead
  /// this adds the person's own uid to the doc's hiddenFor array —
  /// the provider then filters out anything with their uid in that
  /// list before it ever reaches the UI.
  Future<void> hideBroadcastForUser(List<String> ids, String uid) async {
    for (var i = 0; i < ids.length; i += 450) {
      final chunk = ids.skip(i).take(450);
      final batch = _firestore.batch();
      for (final id in chunk) {
        batch.update(_collection.doc(id), {
          'hiddenFor': FieldValue.arrayUnion([uid]),
        });
      }
      await batch.commit();
    }
  }
}
