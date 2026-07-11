import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/order_entity.dart';

class OrderModel {
  final String id;
  final String userId;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String status;
  final Timestamp createdAt;
  final String deliveryAddress;
  final String? customerPhone;
  final String paymentMethod;
  final String? deliveryPersonName;
  final String? deliveryPersonPhone;
  final double? rating;
  final String? ratingComment;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.deliveryAddress,
    this.customerPhone,
    this.paymentMethod = 'cod',
    this.deliveryPersonName,
    this.deliveryPersonPhone,
    this.rating,
    this.ratingComment,
  });

  /// Some order documents (usually manually created for testing directly
  /// in the Firestore console) can have malformed entries in `items` —
  /// e.g. a plain string instead of the expected map. Rather than let one
  /// bad document crash the entire orders list for every admin screen,
  /// this quietly skips any entry that isn't actually a map and keeps
  /// the rest.
  static List<Map<String, dynamic>> _parseItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrderModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      items: _parseItems(data['items']),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      status: (data['status'] as String?) ?? 'placed',
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
      deliveryAddress: (data['deliveryAddress'] as String?) ?? '',
      customerPhone: data['customerPhone'] as String?,
      paymentMethod: (data['paymentMethod'] as String?) ?? 'cod',
      deliveryPersonName: data['deliveryPersonName'] as String?,
      deliveryPersonPhone: data['deliveryPersonPhone'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      ratingComment: data['ratingComment'] as String?,
    );
  }

  OrderEntity toEntity() => OrderEntity(
        id: id,
        userId: userId,
        items: items
            .map((i) => OrderItemEntity(
                  productId: (i['productId'] as String?) ?? '',
                  name: (i['name'] as String?) ?? '',
                  unit: (i['unit'] as String?) ?? '',
                  imageUrl: (i['imageUrl'] as String?) ?? '',
                  price: (i['price'] as num?)?.toDouble() ?? 0,
                  quantity: (i['quantity'] as num?)?.toInt() ?? 0,
                ))
            .toList(),
        totalAmount: totalAmount,
        status: OrderStatusX.fromString(status),
        createdAt: createdAt.toDate(),
        deliveryAddress: deliveryAddress,
        customerPhone: customerPhone,
        paymentMethod: PaymentMethodX.fromString(paymentMethod),
        deliveryPersonName: deliveryPersonName,
        deliveryPersonPhone: deliveryPersonPhone,
        rating: rating,
        ratingComment: ratingComment,
      );

  static Map<String, dynamic> toFirestoreMap({
    required String userId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String deliveryAddress,
    String? customerPhone,
    String paymentMethod = 'cod',
  }) {
    return {
      'userId': userId,
      'items': items,
      'totalAmount': totalAmount,
      'status': OrderStatus.placed.name,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryAddress': deliveryAddress,
      'customerPhone': customerPhone,
      'paymentMethod': paymentMethod,
      'deliveryPersonName': null,
      'deliveryPersonPhone': null,
      'rating': null,
      'ratingComment': null,
    };
  }
}
