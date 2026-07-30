import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/staff_member_entity.dart';
import '../providers/employee_providers.dart';
import '../widgets/add_employee_dialog.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final staffAsync = ref.watch(allStaffProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () async {
          final added = await showDialog<bool>(context: context, builder: (_) => const AddEmployeeDialog());
          if (added == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Staff member added successfully.')),
            );
          }
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Staff'),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load staff: $error')),
        data: (allStaff) {
          // A doc with neither a name nor an email isn't something
          // anyone can meaningfully act on — most likely a leftover
          // from a partially-failed "Add Staff" attempt (e.g. the
          // login account got created but the profile write didn't).
          // Hidden here rather than shown as an unusable "?" row; worth
          // checking Firestore's staff_users collection directly if
          // you want to actually delete these.
          final staff = allStaff.where((s) => s.name.isNotEmpty || s.email.isNotEmpty).toList();
          if (staff.isEmpty) {
            return const Center(child: Text('No staff members yet. Tap "Add Staff" to create one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            itemCount: staff.length,
            itemBuilder: (context, index) {
              final member = staff[index];
              final isSelf = member.uid == currentUser?.uid;
              final roleColor = member.role == StaffRole.admin ? _orange : _green;

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: CircleAvatar(
                    backgroundColor: roleColor.withOpacity(0.12),
                    child: Text(
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                      style: TextStyle(color: roleColor, fontWeight: FontWeight.w800),
                    ),
                  ),
                  title: Text('${member.name}${isSelf ? ' (You)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${member.employeeCode != null ? '${member.employeeCode} • ' : ''}${member.email}\n${member.phone}',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(member.role.label,
                            style: TextStyle(color: roleColor, fontWeight: FontWeight.w700, fontSize: 11)),
                      ),
                      if (!isSelf)
                        SizedBox(
                          height: 28,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (choice) async {
                            if (choice == 'edit') {
                              final edited = await showDialog<bool>(
                                context: context,
                                builder: (_) => AddEmployeeDialog(existing: member),
                              );
                              if (edited == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Staff member updated.')),
                                );
                              }
                            } else if (choice == 'delete') {
                              _confirmRemove(context, ref, member);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: _red))),
                          ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, StaffMemberEntity member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff Access?'),
        content: Text(
          'This revokes ${member.name}\'s admin/employee access immediately. Their login will still exist, but they\'ll only have regular customer access.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref.read(employeeMutationProvider.notifier).removeStaff(member.uid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Access removed.' : 'Could not remove access.')),
      );
    }
  }
}
