import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/domain/entities/order_entity.dart';

class EmployeeOrderDataSource {
  final FirebaseFirestore _firestore;
  EmployeeOrderDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');

  /// No orderBy here deliberately — combining an equality filter with
  /// orderBy on a different field needs a Firestore composite index,
  /// and an employee's own list is small enough to just sort client-side
  /// instead of asking for another index to be created.
  Future<List<OrderEntity>> getMyAssignedOrders(String employeeUid) async {
    final snapshot = await _orders.where('assignedEmployeeUid', isEqualTo: employeeUid).get();
    final orders = snapshot.docs.map((d) => OrderModel.fromFirestore(d).toEntity()).toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<void> markDelivered(String orderId) async {
    await _orders.doc(orderId).update({'status': OrderStatus.delivered.name});
  }
}
