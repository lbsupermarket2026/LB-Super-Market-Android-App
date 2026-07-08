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
    this.deliveryPersonName,
    this.deliveryPersonPhone,
    this.rating,
    this.ratingComment,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrderModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      items: (data['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [],
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      status: (data['status'] as String?) ?? 'placed',
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
      deliveryAddress: (data['deliveryAddress'] as String?) ?? '',
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
  }) {
    return {
      'userId': userId,
      'items': items,
      'totalAmount': totalAmount,
      'status': OrderStatus.placed.name,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryAddress': deliveryAddress,
      'deliveryPersonName': null,
      'deliveryPersonPhone': null,
      'rating': null,
      'ratingComment': null,
    };
  }
}
