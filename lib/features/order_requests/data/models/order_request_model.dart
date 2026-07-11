import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/order_request_entity.dart';

class OrderRequestModel {
  static OrderRequestEntity fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrderRequestEntity(
      id: doc.id,
      userId: (data['uid'] as String?) ?? '',
      type: (data['type'] as String?) == 'photo' ? OrderRequestType.photo : OrderRequestType.typedList,
      itemLines: (data['itemLines'] is List)
          ? (data['itemLines'] as List).whereType<String>().toList()
          : const [],
      photoUrl: data['photoUrl'] as String?,
      contactPhone: (data['contactPhone'] as String?) ?? '',
      fulfillmentMethod:
          (data['fulfillmentMethod'] as String?) == 'pickup' ? FulfillmentMethod.pickup : FulfillmentMethod.delivery,
      deliveryAddress: data['deliveryAddress'] as String?,
      status: OrderRequestStatusX.fromString((data['status'] as String?) ?? 'pending'),
      createdAt: ((data['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
    );
  }

  static Map<String, dynamic> toFirestoreMap({
    required String userId,
    required OrderRequestType type,
    List<String> itemLines = const [],
    String? photoUrl,
    required String contactPhone,
    required FulfillmentMethod fulfillmentMethod,
    String? deliveryAddress,
  }) {
    return {
      'uid': userId,
      'type': type == OrderRequestType.photo ? 'photo' : 'typedList',
      'itemLines': itemLines,
      'photoUrl': photoUrl,
      'contactPhone': contactPhone,
      'fulfillmentMethod': fulfillmentMethod == FulfillmentMethod.pickup ? 'pickup' : 'delivery',
      'deliveryAddress': deliveryAddress,
      'paymentMethod': 'cod',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
