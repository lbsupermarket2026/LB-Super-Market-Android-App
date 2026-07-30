import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../domain/entities/staff_member_entity.dart';
import '../providers/employee_providers.dart';
import '../providers/employee_performance_providers.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);

class EmployeePerformanceScreen extends ConsumerWidget {
  const EmployeePerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(allStaffProvider);
    final statsAsync = ref.watch(employeeStatsProvider);
    final period = ref.watch(performancePeriodProvider);

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Employee Work')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SegmentedButton<PerformancePeriod>(
              segments: const [
                ButtonSegment(value: PerformancePeriod.today, label: Text('Today')),
                ButtonSegment(value: PerformancePeriod.overall, label: Text('Overall')),
              ],
              selected: {period},
              onSelectionChanged: (selection) => ref.read(performancePeriodProvider.notifier).state = selection.first,
              style: SegmentedButton.styleFrom(selectedBackgroundColor: _green, selectedForegroundColor: Colors.white),
            ),
          ),
          Expanded(
            child: staffAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load employees: $e')),
              data: (staff) {
                final employees = staff.where((s) => s.role == StaffRole.employee).toList();
                if (employees.isEmpty) {
                  return const Center(child: Text('No employees added yet.'));
                }

                final stats = statsAsync.valueOrNull ?? {};
                final isToday = period == PerformancePeriod.today;

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(employeeStatsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final employee = employees[index];
                      final s = stats[employee.uid];
                      final assigned = s?.assignedToday ?? 0;
                      final delivered = s?.deliveredToday ?? 0;
                      final pending = assigned - delivered;

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _green.withOpacity(0.12),
                                  child: Text(
                                    employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(employee.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(employee.phone, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _StatChip(label: isToday ? 'Assigned Today' : 'Assigned', value: assigned, color: _orange)),
                                const SizedBox(width: 8),
                                Expanded(child: _StatChip(label: isToday ? 'Delivered Today' : 'Delivered', value: delivered, color: _green)),
                                const SizedBox(width: 8),
                                Expanded(child: _StatChip(label: 'Pending', value: pending < 0 ? 0 : pending, color: Colors.blueGrey)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 9.5, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
