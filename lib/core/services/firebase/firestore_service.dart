import 'package:cloud_firestore/cloud_firestore.dart';

/// Thin, generic wrapper around common Firestore access patterns so
/// feature DataSources don't repeat pagination/query boilerplate.
/// Feature-specific DataSources should still own their own collection
/// references and mapping — this only centralizes the mechanics.
class FirestoreService {
  final FirebaseFirestore _firestore;
  FirestoreService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseFirestore get instance => _firestore;

  CollectionReference<Map<String, dynamic>> collection(String path) => _firestore.collection(path);

  /// Cursor-based pagination — never fetch a full collection.
  Future<QuerySnapshot<Map<String, dynamic>>> paginatedQuery({
    required Query<Map<String, dynamic>> query,
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) {
    var q = query.limit(limit);
    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }
    return q.get();
  }
}
