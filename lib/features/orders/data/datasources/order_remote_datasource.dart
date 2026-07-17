import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/order_entity.dart';
import '../models/order_model.dart';

class OrderRemoteDataSource {
  final FirebaseFirestore _firestore;
  OrderRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.orders);

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
    String paymentMethod = 'cod',
    String? razorpayPaymentId,
  }) async {
    final docRef = await _collection.add(OrderModel.toFirestoreMap(
      userId: userId,
      items: items,
      totalAmount: totalAmount,
      deliveryAddress: deliveryAddress,
      customerPhone: customerPhone,
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
}
