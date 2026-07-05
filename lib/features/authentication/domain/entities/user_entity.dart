import 'package:equatable/equatable.dart';

enum UserRole { customer, employee, admin }

UserRole userRoleFromString(String? value) {
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'employee':
      return UserRole.employee;
    default:
      return UserRole.customer;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.employee:
      return 'employee';
    case UserRole.customer:
      return 'customer';
  }
}

/// Domain entity — no toJson/fromJson here, that belongs to UserModel
/// in the data layer. This is what the rest of the app (presentation,
/// other features' domain layers) should depend on.
class UserEntity extends Equatable {
  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final UserRole role;
  final int loyaltyPoints;
  final String? defaultAddressId;
  final bool isBlocked;

  const UserEntity({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.role = UserRole.customer,
    this.loyaltyPoints = 0,
    this.defaultAddressId,
    this.isBlocked = false,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isEmployee => role == UserRole.employee;
  bool get isStaff => isAdmin || isEmployee;

  @override
  List<Object?> get props => [uid, name, email, phone, photoUrl, role, loyaltyPoints, defaultAddressId, isBlocked];
}
