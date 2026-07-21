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
  Future<int> getCustomerOrderCount(String userId) async {
    final snapshot = await _orders.where('userId', isEqualTo: userId).count().get();
    return snapshot.count ?? 0;
  }

  /// Runs two separate equality queries (userId, customerPhone) and
  /// merges/dedupes rather than one combined query — Firestore doesn't
  /// support OR across different fields natively, and this way the
  /// admin can search by either without needing to specify which kind
  /// of value they typed.
  Future<List<OrderEntity>> searchCustomerOrders(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = await Future.wait([
      _orders.where('userId', isEqualTo: trimmed).get(),
      _orders.where('customerPhone', isEqualTo: trimmed).get(),
    ]);

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

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _orders.doc(orderId).update({'status': status.name});
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
