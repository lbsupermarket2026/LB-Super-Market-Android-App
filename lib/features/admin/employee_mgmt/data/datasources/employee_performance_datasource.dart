import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../orders/data/models/order_model.dart';
import '../../../../orders/domain/entities/order_entity.dart';

class EmployeeStats {
  final String employeeUid;
  final int assignedToday;
  final int deliveredToday;

  const EmployeeStats({required this.employeeUid, required this.assignedToday, required this.deliveredToday});
}

class EmployeePerformanceDataSource {
  final FirebaseFirestore _firestore;
  EmployeePerformanceDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// "Today" here means orders CREATED today that have an employee
  /// assigned — there's no separate assignedAt/deliveredAt timestamp on
  /// orders, and for a same-day grocery delivery flow, created-today is
  /// a reasonable stand-in for "today's work." Fetches everything
  /// assigned (no orderBy, to sidestep another composite index) and
  /// tallies per employee client-side.
  Future<Map<String, EmployeeStats>> getTodayStatsByEmployee() => _getStats(todayOnly: true);

  /// Same tally with no date filter — total assigned/delivered per
  /// employee across their whole history.
  Future<Map<String, EmployeeStats>> getOverallStatsByEmployee() => _getStats(todayOnly: false);

  Future<Map<String, EmployeeStats>> _getStats({required bool todayOnly}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _firestore
        .collection('orders')
        .where('assignedEmployeeUid', isNull: false)
        .get();

    final counts = <String, ({int assigned, int delivered})>{};

    for (final doc in snapshot.docs) {
      final order = OrderModel.fromFirestore(doc).toEntity();
      if (todayOnly && order.createdAt.isBefore(startOfDay)) continue;

      final uid = order.assignedEmployeeUid;
      if (uid == null) continue;

      final current = counts[uid] ?? (assigned: 0, delivered: 0);
      counts[uid] = (
        assigned: current.assigned + 1,
        delivered: current.delivered + (order.status == OrderStatus.delivered ? 1 : 0),
      );
    }

    return {
      for (final entry in counts.entries)
        entry.key: EmployeeStats(employeeUid: entry.key, assignedToday: entry.value.assigned, deliveredToday: entry.value.delivered),
    };
  }
}
