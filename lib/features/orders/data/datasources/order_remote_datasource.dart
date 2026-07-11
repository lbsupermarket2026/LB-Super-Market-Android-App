import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../models/order_model.dart';

class OrderRemoteDataSource {
  final FirebaseFirestore _firestore;
  OrderRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.orders);

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
  }) async {
    final docRef = await _collection.add(OrderModel.toFirestoreMap(
      userId: userId,
      items: items,
      totalAmount: totalAmount,
      deliveryAddress: deliveryAddress,
      customerPhone: customerPhone,
      paymentMethod: paymentMethod,
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
