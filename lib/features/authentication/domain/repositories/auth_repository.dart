import 'dart:io';
import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';

/// Abstract contract — domain layer has zero Flutter/Firebase imports.
/// Implemented by AuthRepositoryImpl in the data layer.
abstract class AuthRepository {
  /// Emits the current user entity (or null if signed out) whenever
  /// Firebase auth state changes, enriched with the Firestore user doc.
  Stream<UserEntity?> authStateChanges();

  UserEntity? get currentUser;

  Future<Result<void>> resendEmailVerification();
  Future<Result<bool>> refreshAndCheckEmailVerified();

  /// Returns a verificationId on success — pass it to verifyOtp along
  /// with whatever code the user receives by SMS.
  Future<Result<String>> sendOtp(String phoneNumber);
  Future<Result<UserEntity>> verifyOtp({required String verificationId, required String smsCode});

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

  Future<Result<void>> updateProfile({required String name, required String phone, String? photoUrl});

  Future<Result<String>> uploadProfilePhoto(File file);

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Result<void>> sendPasswordResetEmail(String email);

  Future<Result<void>> signOut();

  /// Signs in with either an email or a phone number as the
  /// identifier, plus a password — no OTP needed for this, since a
  /// phone number only ever needs OTP verification once, at signup.
  Future<Result<UserEntity>> signInWithIdentifierAndPassword({
    required String identifier,
    required String password,
  });

  /// Completes a phone-based signup after OTP verification — links a
  /// password to the now-verified phone account and creates its
  /// Firestore profile, so it behaves identically to an email signup
  /// from that point on.
  Future<Result<UserEntity>> signUpWithPhoneAndPassword({
    required String name,
    required String phone,
    required String password,
    required String verificationId,
    required String smsCode,
  });
}
