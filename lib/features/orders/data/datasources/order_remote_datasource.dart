import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/sequential_id_service.dart';
import '../../domain/entities/order_entity.dart';
import '../models/order_model.dart';

class OrderRemoteDataSource {
  final FirebaseFirestore _firestore;
  OrderRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.orders);

  /// Assigns a "CUST-0001" style code the first time this customer ever
  /// places an order that has one — covers both new signups and
  /// existing accounts created before this feature existed, without
  /// needing a separate one-off migration script.
  Future<void> _ensureCustomerCode(String userId) async {
    final userRef = _firestore.collection(FirestorePaths.users).doc(userId);
    final snapshot = await userRef.get();
    if (snapshot.data()?['customerCode'] != null) return;

    final code = await SequentialIdService().next(counterField: 'nextCustomerNumber', prefix: 'CUST');
    await userRef.set({'customerCode': code}, SetOptions(merge: true));
  }

  /// Customer-initiated cancellation — only touches the status field, so
  /// it matches the narrow Firestore rule exception that lets a customer
  /// cancel their own order (as opposed to the broader staff update rule).
  Future<void> cancelOrder(String orderId) async {
    await _collection.doc(orderId).update({'status': OrderStatus.cancelled.name});
  }

  Future<List<OrderModel>> getMyOrders(String userId) async {
    final snapshot =
        await _collection.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(OrderModel.fromFirestore).toList();
  }

  Future<OrderModel> getOrderById(String orderId) async {
    final doc = await _collection.doc(orderId).get();
    if (!doc.exists) {
      throw const NotFoundException('Order not found.');
    }
    return OrderModel.fromFirestore(doc);
  }

  Future<String> createOrder({
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String deliveryAddress,
    String? customerPhone,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String paymentMethod = 'cod',
    String? razorpayPaymentId,
  }) async {
    final orderNumber = await SequentialIdService().next(counterField: 'nextOrderNumber', prefix: 'ORD');
    await _ensureCustomerCode(userId);

    final docRef = await _collection.add(OrderModel.toFirestoreMap(
      userId: userId,
      items: items,
      totalAmount: totalAmount,
      deliveryAddress: deliveryAddress,
      customerPhone: customerPhone,
          deliveryLatitude: deliveryLatitude,
          deliveryLongitude: deliveryLongitude,
      orderNumber: orderNumber,
      paymentMethod: paymentMethod,
      razorpayPaymentId: razorpayPaymentId,
    ));
    return docRef.id;
  }

  Future<void> submitRating(String orderId, double rating, String? comment) async {
    await _collection.doc(orderId).update({
      'rating': rating,
      'ratingComment': comment,
    });
  }

  /// Only usable while the order is still 'placed' — the Firestore
  /// rule enforces this too, not just this client check, since the
  /// customer's own device isn't a trustworthy place to enforce it
  /// alone. Once staff move an order to 'confirmed' or later, neither
  /// side can edit items through this path anymore.
  Future<void> updateOrderItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String deliveryAddress,
  }) async {
    await _collection.doc(orderId).update({
      'items': items,
      'totalAmount': totalAmount,
      'deliveryAddress': deliveryAddress,
    });
  }
}
