import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/order_request_entity.dart';
import '../models/order_request_model.dart';

class OrderRequestRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  OrderRequestRemoteDataSource({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.orderRequests);

  Future<String> uploadListPhoto(String userId, File file) async {
    final ref = _storage.ref('order_request_photos/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final snapshot = await ref.putFile(file);

    if (snapshot.state != TaskState.success) {
      throw Exception('Photo upload did not complete (state: ${snapshot.state}).');
    }

    // Use the snapshot's own ref rather than the original `ref` variable —
    // functionally the same path, but this guarantees we're asking for
    // the URL of the object we just confirmed was written.
    return snapshot.ref.getDownloadURL();
  }

  Future<String> createOrderRequest({
    required String userId,
    required OrderRequestType type,
    List<String> itemLines = const [],
    String? photoUrl,
    required String contactPhone,
    required FulfillmentMethod fulfillmentMethod,
    String? deliveryAddress,
  }) async {
    final docRef = await _collection.add(OrderRequestModel.toFirestoreMap(
      userId: userId,
      type: type,
      itemLines: itemLines,
      photoUrl: photoUrl,
      contactPhone: contactPhone,
      fulfillmentMethod: fulfillmentMethod,
      deliveryAddress: deliveryAddress,
    ));
    return docRef.id;
  }

  Future<List<OrderRequestEntity>> getMyOrderRequests(String userId) async {
    final snapshot =
        await _collection.where('uid', isEqualTo: userId).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(OrderRequestModel.fromFirestore).toList();
  }
}
