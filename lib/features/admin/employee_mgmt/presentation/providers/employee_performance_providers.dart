import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/employee_performance_datasource.dart';

final employeePerformanceDataSourceProvider = Provider<EmployeePerformanceDataSource>((ref) {
  return EmployeePerformanceDataSource();
});

enum PerformancePeriod { today, overall }

final performancePeriodProvider = StateProvider.autoDispose<PerformancePeriod>((ref) => PerformancePeriod.today);

final employeeStatsProvider = FutureProvider.autoDispose<Map<String, EmployeeStats>>((ref) {
  final period = ref.watch(performancePeriodProvider);
  final ds = ref.watch(employeePerformanceDataSourceProvider);
  return period == PerformancePeriod.today ? ds.getTodayStatsByEmployee() : ds.getOverallStatsByEmployee();
});
