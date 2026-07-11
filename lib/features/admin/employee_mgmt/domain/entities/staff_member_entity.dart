enum StaffRole { employee, admin }

extension StaffRoleX on StaffRole {
  String get label => this == StaffRole.admin ? 'Admin' : 'Employee';

  static StaffRole fromString(String value) => value == 'admin' ? StaffRole.admin : StaffRole.employee;
}

class StaffMemberEntity {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final StaffRole role;
  final DateTime createdAt;

  const StaffMemberEntity({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.createdAt,
  });
}
