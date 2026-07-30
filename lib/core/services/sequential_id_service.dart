import 'package:cloud_firestore/cloud_firestore.dart';

/// Generates human-readable display numbers stored ALONGSIDE the real
/// Firestore document ID, never replacing it. The real ID stays the
/// actual primary key everywhere it's already used (security rules,
/// assignedEmployeeUid, order.userId, etc.) — this only adds a
/// friendlier number for bills and UI display.
///
/// Counters live in a single admin_config/idCounters document so every
/// assignment goes through one atomic transaction, which is what
/// prevents two records created at the same moment from ever getting
/// the same number.
class SequentialIdService {
  final FirebaseFirestore _firestore;
  SequentialIdService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _counterDoc =>
      _firestore.collection('admin_config').doc('idCounters');

  /// Order numbers reset every month — "202607007" is the 7th order
  /// placed in July 2026 (2026-07), not the 7th order ever. Padded to
  /// a minimum of 3 digits but grows naturally past that (e.g. the
  /// 1234th order that month becomes "2026071234", not truncated or
  /// re-padded).
  Future<String> nextOrderNumber() async {
    final now = DateTime.now();
    final yearMonth = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final counterField = 'order_$yearMonth';

    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(_counterDoc);
      final current = (snapshot.data()?[counterField] as num?)?.toInt() ?? 1;
      transaction.set(_counterDoc, {counterField: current + 1}, SetOptions(merge: true));
      return '$yearMonth${current.toString().padLeft(3, '0')}';
    });
  }

  /// EMP001, EMP002, ... — does not reset, since headcount is a
  /// running total rather than a per-period thing like orders.
  Future<String> nextEmployeeCode() => _next(counterField: 'nextEmployeeNumber', prefix: 'EMP', padding: 3);

  /// CUST0001, CUST0002, ... — same reasoning, running total.
  Future<String> nextCustomerCode() => _next(counterField: 'nextCustomerNumber', prefix: 'CUST', padding: 4);

  Future<String> _next({required String counterField, required String prefix, required int padding}) async {
    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(_counterDoc);
      final current = (snapshot.data()?[counterField] as num?)?.toInt() ?? 1;
      transaction.set(_counterDoc, {counterField: current + 1}, SetOptions(merge: true));
      return '$prefix${current.toString().padLeft(padding, '0')}';
    });
  }
}
