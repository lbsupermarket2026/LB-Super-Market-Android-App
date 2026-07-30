import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../orders/data/models/order_model.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../../order_requests/data/models/order_request_model.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';

/// Staff-only reads across ALL customers' orders/order_requests — allowed
/// because the Firestore rules evaluate isStaff() per document and it's
/// true regardless of whose order it is, so a staff account can safely
/// query the whole collection with no per-user filter.
class AdminOrderDataSource {
  final FirebaseFirestore _firestore;
  AdminOrderDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');
  CollectionReference<Map<String, dynamic>> get _requests => _firestore.collection('order_requests');

  /// Aggregate count, not a full fetch — cheap regardless of how many
  /// orders that customer has, same reasoning as the category product
  /// count on the customer side.
  /// Replaces the old count-only query — needs the actual totalAmount
  /// values to sum, not just a count, so this fetches real documents
  /// rather than using .count().
  Future<({int count, double totalSpent})> getCustomerOrderStats(String userId) async {
    final snapshot = await _orders.where('userId', isEqualTo: userId).get();
    final total = snapshot.docs.fold<double>(0, (sum, doc) => sum + ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0));
    return (count: snapshot.docs.length, totalSpent: total);
  }

  /// Runs two separate equality queries (userId, customerPhone) and
  /// merges/dedupes rather than one combined query — Firestore doesn't
  /// support OR across different fields natively, and this way the
  /// admin can search by either without needing to specify which kind
  /// of value they typed.
  Future<List<OrderEntity>> searchCustomerOrders(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // customerPhone on an order is a snapshot of whatever the phone
    // number was AT THE TIME that order was placed — if a customer's
    // profile phone changed (or was blank) between orders, older orders
    // keep the old value, so a literal customerPhone match alone can
    // miss real history for the same person. Resolving the searched
    // phone to their actual account first, then also searching by that
    // userId, closes that gap — the userId never changes.
    String? resolvedUserId;
    try {
      final userQuery = await _firestore.collection('users').where('phone', isEqualTo: trimmed).limit(1).get();
      if (userQuery.docs.isNotEmpty) {
        resolvedUserId = userQuery.docs.first.id;
      }
    } catch (_) {
      // Non-fatal — falls back to the direct matches below.
    }

    final queries = [
      _orders.where('userId', isEqualTo: trimmed).get(),
      _orders.where('customerPhone', isEqualTo: trimmed).get(),
    ];
    if (resolvedUserId != null && resolvedUserId != trimmed) {
      queries.add(_orders.where('userId', isEqualTo: resolvedUserId).get());
    }

    final results = await Future.wait(queries);

    final byId = <String, OrderEntity>{};
    for (final snapshot in results) {
      for (final doc in snapshot.docs) {
        final order = OrderModel.fromFirestore(doc).toEntity();
        byId[order.id] = order;
      }
    }

    final orders = byId.values.toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<List<OrderEntity>> getAllOrders() async {
    final snapshot = await _orders.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((d) => OrderModel.fromFirestore(d).toEntity()).toList();
  }

  /// Decrements stock for every item on the order the FIRST time it's
  /// marked confirmed — the stockDecremented flag inside the same
  /// transaction stops it from happening twice if status ever gets
  /// flipped back and forth (placed → confirmed → placed → confirmed).
  /// Uses a transaction specifically so two people confirming different
  /// orders for the same low-stock product at the same moment can't
  /// both read the same starting stockQty and both "successfully"
  /// oversell it.
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    if (status != OrderStatus.confirmed) {
      await _orders.doc(orderId).update({'status': status.name});
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final orderRef = _orders.doc(orderId);
      final orderSnap = await transaction.get(orderRef);
      final orderData = orderSnap.data();
      if (orderData == null) return;

      final alreadyDecremented = orderData['stockDecremented'] == true;
      final items = (orderData['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

      // Firestore transactions require every read to happen before any
      // write — so every product doc gets read first (into this list),
      // and only once all reads are done do the actual stock updates
      // get written.
      final updates = <DocumentReference<Map<String, dynamic>>, int>{};
      if (!alreadyDecremented) {
        for (final item in items) {
          final productId = item['productId'] as String?;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          if (productId == null || productId.isEmpty || quantity <= 0) continue;

          final productRef = _firestore.collection('products').doc(productId);
          final productSnap = await transaction.get(productRef);
          if (!productSnap.exists) continue;

          final currentStock = (productSnap.data()?['stockQty'] as num?)?.toInt() ?? 0;
          final newStock = currentStock - quantity;
          updates[productRef] = newStock < 0 ? 0 : newStock;
        }
      }

      for (final entry in updates.entries) {
        transaction.update(entry.key, {'stockQty': entry.value});
      }
      transaction.update(orderRef, {'status': status.name, 'stockDecremented': true});
    });
  }

  Future<void> assignDelivery(String orderId, String employeeUid, String name, String phone) async {
    await _orders.doc(orderId).update({
      'assignedEmployeeUid': employeeUid,
      'deliveryPersonName': name,
      'deliveryPersonPhone': phone,
      // Assigning someone naturally implies it's on its way — keeps the
      // customer's tracker moving instead of staff having to also
      // separately flip the status right after assigning.
      'status': OrderStatus.outForDelivery.name,
    });
  }

  Future<List<OrderRequestEntity>> getAllOrderRequests() async {
    final snapshot = await _requests.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(OrderRequestModel.fromFirestore).toList();
  }

  Future<void> updateRequestStatus(String requestId, OrderRequestStatus status) async {
    await _requests.doc(requestId).update({'status': status.name});
  }

  /// Converts a confirmed order request into a real priced order, then
  /// marks the original request confirmed — bridging the two systems
  /// once staff have called the customer and agreed on final pricing.
  Future<String> convertRequestToOrder({
    required OrderRequestEntity request,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    final orderRef = await _orders.add(OrderModel.toFirestoreMap(
      userId: request.userId,
      items: items,
      totalAmount: totalAmount,
      deliveryAddress: request.deliveryAddress ?? '',
      customerPhone: request.contactPhone,
      paymentMethod: 'cod',
    ));
    await _requests.doc(request.id).update({'status': OrderRequestStatus.confirmed.name});
    return orderRef.id;
  }
}
