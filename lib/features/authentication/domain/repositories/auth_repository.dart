import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';

/// Abstract contract — domain layer has zero Flutter/Firebase imports.
/// Implemented by AuthRepositoryImpl in the data layer.
abstract class AuthRepository {
  /// Emits the current user entity (or null if signed out) whenever
  /// Firebase auth state changes, enriched with the Firestore user doc.
  Stream<UserEntity?> authStateChanges();

  UserEntity? get currentUser;

  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<UserEntity>> signUpWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  Future<Result<void>> updateProfile({required String name, required String phone});

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Result<void>> sendPasswordResetEmail(String email);

  Future<Result<void>> signOut();

  /// Phone OTP flow
  Future<Result<String>> sendOtp(String phoneNumber); // returns verificationId
  Future<Result<UserEntity>> verifyOtp({
    required String verificationId,
    required String smsCode,
  });
}
