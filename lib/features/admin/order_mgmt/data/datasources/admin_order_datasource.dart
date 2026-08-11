import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/services/sequential_id_service.dart';
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

  /// NEW: live version of getAllOrders(). The one-shot Future above is
  /// why the admin dashboard kept showing "Payment Pending" after a
  /// customer's payment actually succeeded — that confirmation write
  /// happens entirely on the CUSTOMER's device (place_order_dialog.dart
  /// calling markPaymentConfirmed), which has no way to invalidate the
  /// ADMIN's separate allOrdersAdminProvider on a different device. The
  /// admin side only re-fetched on its own mutations (status change,
  /// manual order, etc.) or a manual pull-to-refresh — never in
  /// response to something a customer did. A live Firestore snapshot
  /// stream fixes this at the root: any change to any order, from any
  /// device, reflects immediately, with no invalidation wiring needed.
  Stream<List<OrderEntity>> watchAllOrders() {
    return _orders.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((d) => OrderModel.fromFirestore(d).toEntity()).toList(),
        );
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
    // NEW: a cancelled order is a final state — once autoRefundOnCancel
    // (Cloud Function) may have already acted on it, flipping the
    // status again (e.g. back to "Delivered") would leave the order
    // record and any refund badly out of sync with reality. Guards
    // both branches below: the simple direct-update path, and the
    // transactional "confirmed" path (which also decrements stock —
    // definitely not something that should ever happen to a
    // cancelled order).
    if (status != OrderStatus.confirmed) {
      final currentSnap = await _orders.doc(orderId).get();
      final currentStatus = currentSnap.data()?['status'] as String?;
      if (currentStatus == OrderStatus.cancelled.name) {
        throw const ServerException('This order has been cancelled and its status can no longer be changed.');
      }
      await _orders.doc(orderId).update({'status': status.name});
      return;
    }

    await _firestore.runTransaction((transaction) async {
      final orderRef = _orders.doc(orderId);
      final orderSnap = await transaction.get(orderRef);
      final orderData = orderSnap.data();
      if (orderData == null) return;

      if (orderData['status'] == OrderStatus.cancelled.name) {
        throw const ServerException('This order has been cancelled and its status can no longer be changed.');
      }

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
    // NEW: same guard as updateOrderStatus — assignDelivery also
    // flips status to outForDelivery, which would silently un-cancel
    // a cancelled order if this ran on one. UI already hides the
    // option, but this closes the gap for any other caller.
    final currentSnap = await _orders.doc(orderId).get();
    final currentStatus = currentSnap.data()?['status'] as String?;
    if (currentStatus == OrderStatus.cancelled.name) {
      throw const ServerException('This order has been cancelled and can no longer be assigned to a delivery employee.');
    }
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
    // FIXED: this never assigned an orderNumber at all — every order
    // that started as "Type My List" or a photo submission fell back
    // to a raw random Firestore doc ID substring wherever displayed
    // (admin orders list, customer order search, notifications —
    // anywhere order.orderNumber ?? order.id.substring(...) is used),
    // which is exactly the "weird order number" being reported. Now
    // generates a proper sequential number the same way the normal
    // checkout flow does.
    final orderNumber = await SequentialIdService().nextOrderNumber();

    // NEW: also look up the customer's actual name from their user
    // profile — order_requests only ever captured a phone number, not
    // a name, so nothing downstream (admin lists, customer search)
    // ever had a real name to show for these orders. Best-effort: if
    // the lookup fails for any reason, the order still gets created
    // (customerName just stays null, same as before this fix).
    String? customerName;
    try {
      final userDoc = await _firestore.collection('users').doc(request.userId).get();
      customerName = userDoc.data()?['name'] as String?;
    } catch (_) {
      // Non-fatal — proceed without a name rather than blocking order creation.
    }

    final orderRef = await _orders.add(OrderModel.toFirestoreMap(
      userId: request.userId,
      items: items,
      totalAmount: totalAmount,
      deliveryAddress: request.deliveryAddress ?? '',
      customerPhone: request.contactPhone,
      customerName: customerName,
      orderNumber: orderNumber,
      paymentMethod: 'cod',
    ));
    await _requests.doc(request.id).update({'status': OrderRequestStatus.confirmed.name});
    return orderRef.id;
  }
}
