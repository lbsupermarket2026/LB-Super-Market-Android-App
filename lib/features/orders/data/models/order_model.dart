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
  final String? customerName;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? orderNumber;
  final String paymentMethod;
  final String? razorpayPaymentId;
  final bool paymentPending;
  final String? refundStatus;
  final String? refundId;
  final String? refundError;
  final String? assignedEmployeeUid;
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
    this.customerName,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.orderNumber,
    this.paymentMethod = 'cod',
    this.razorpayPaymentId,
    this.paymentPending = false,
    this.refundStatus,
    this.refundId,
    this.refundError,
    this.assignedEmployeeUid,
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
      customerName: data['customerName'] as String?,
      deliveryLatitude: (data['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (data['deliveryLongitude'] as num?)?.toDouble(),
      orderNumber: data['orderNumber'] as String?,
      razorpayPaymentId: data['razorpayPaymentId'] as String?,
      paymentPending: (data['paymentPending'] as bool?) ?? false,
      refundStatus: data['refundStatus'] as String?,
      refundId: data['refundId'] as String?,
      refundError: data['refundError'] as String?,
      paymentMethod: (data['paymentMethod'] as String?) ?? 'cod',
      assignedEmployeeUid: data['assignedEmployeeUid'] as String?,
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
                  categoryId: i['categoryId'] as String?,
                  mrp: (i['mrp'] as num?)?.toDouble(),
                ))
            .toList(),
        totalAmount: totalAmount,
        status: OrderStatusX.fromString(status),
        createdAt: createdAt.toDate(),
        deliveryAddress: deliveryAddress,
        customerPhone: customerPhone,
        customerName: customerName,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        orderNumber: orderNumber,
        paymentMethod: PaymentMethodX.fromString(paymentMethod),
        razorpayPaymentId: razorpayPaymentId,
        paymentPending: paymentPending,
        refundStatus: refundStatus,
        refundId: refundId,
        refundError: refundError,
        assignedEmployeeUid: assignedEmployeeUid,
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
    String? customerName,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? orderNumber,
    String paymentMethod = 'cod',
    String? razorpayPaymentId,
    bool paymentPending = false,
  }) {
    return {
      'userId': userId,
      'items': items,
      'totalAmount': totalAmount,
      'status': OrderStatus.placed.name,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveryAddress': deliveryAddress,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'orderNumber': orderNumber,
      'paymentMethod': paymentMethod,
      'razorpayPaymentId': razorpayPaymentId,
      // True only for a brief window between "UPI checkout opened" and
      // "payment verified" — lets admin (and the customer's own order
      // list) distinguish a real, paid order from one where the person
      // may have been sent to a UPI app and never made it back to
      // confirm. Recreated as false the instant verification succeeds.
      'paymentPending': paymentPending,
      'deliveryPersonName': null,
      'deliveryPersonPhone': null,
      'rating': null,
      'ratingComment': null,
    };
  }
}
