import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

/// Data-layer DTO. Handles Firestore (de)serialization only —
/// the rest of the app should never see raw Firestore field names
/// outside this class.
class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String role; // raw string as stored: "customer" | "employee" | "admin"
  final int loyaltyPoints;
  final String? defaultAddressId;
  final bool isBlocked;
  final List<String> fcmTokens;

  const UserModel({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.role = 'customer',
    this.loyaltyPoints = 0,
    this.defaultAddressId,
    this.isBlocked = false,
    this.fcmTokens = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel(
      uid: doc.id,
      name: data['name'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      role: (data['role'] as String?) ?? 'customer',
      loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
      defaultAddressId: data['defaultAddressId'] as String?,
      isBlocked: (data['isBlocked'] as bool?) ?? false,
      fcmTokens: (data['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toFirestoreCreate() => {
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'role': role,
        'loyaltyPoints': loyaltyPoints,
        'defaultAddressId': defaultAddressId,
        'isBlocked': isBlocked,
        'fcmTokens': fcmTokens,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toFirestoreLoginUpdate() => {
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

  UserEntity toEntity() => UserEntity(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        photoUrl: photoUrl,
        role: userRoleFromString(role),
        loyaltyPoints: loyaltyPoints,
        defaultAddressId: defaultAddressId,
        isBlocked: isBlocked,
      );
}
