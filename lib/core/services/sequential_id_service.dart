import 'package:cloud_firestore/cloud_firestore.dart';

/// Generates human-readable display numbers (ORD-0001, CUST-0001, ...)
/// stored ALONGSIDE the real Firestore document ID, never replacing it.
/// The real ID stays the actual primary key everywhere it's already
/// used (security rules, assignedEmployeeUid, order.userId, etc.) —
/// this only adds a friendlier number for bills and UI display.
///
/// Counters live in a single admin_config/idCounters document so every
/// assignment goes through one atomic transaction, which is what
/// prevents two orders placed at the same moment from ever getting the
/// same number.
class SequentialIdService {
  final FirebaseFirestore _firestore;
  SequentialIdService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _counterDoc =>
      _firestore.collection('admin_config').doc('idCounters');

  /// [counterField] is which counter to use (e.g. 'nextOrderNumber').
  /// [prefix] and [padding] control the formatted output — prefix
  /// 'ORD', padding 4 → "ORD-0001".
  Future<String> next({required String counterField, required String prefix, int padding = 4}) async {
    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(_counterDoc);
      final current = (snapshot.data()?[counterField] as num?)?.toInt() ?? 1;

      transaction.set(_counterDoc, {counterField: current + 1}, SetOptions(merge: true));

      return '$prefix-${current.toString().padLeft(padding, '0')}';
    });
  }
}
