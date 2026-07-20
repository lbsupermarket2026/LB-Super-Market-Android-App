import 'dart:io';
import '../../../../core/error/result.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  const AuthRepositoryImpl(this._remote);

  @override
  Stream<UserEntity?> authStateChanges() {
    return _remote.firebaseAuthStateChanges.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      try {
        final model = await _remote.resolveUserProfile(firebaseUser.uid);
        return model.toEntity();
      } catch (_) {
        // Profile doc not created yet (e.g. mid-signup race) — treat as signed out
        // until the doc exists; UI will retry via the stream on next emission.
        return null;
      }
    });
  }

  @override
  Future<Result<void>> updateProfile({required String name, required String phone, String? photoUrl}) {
    return guard(() => _remote.updateProfile(name: name, phone: phone, photoUrl: photoUrl));
  }

  @override
  Future<Result<String>> uploadProfilePhoto(File file) {
    return guard(() => _remote.uploadProfilePhoto(file));
  }

  @override
  Future<Result<void>> changePassword({required String currentPassword, required String newPassword}) {
    return guard(() => _remote.changePassword(currentPassword: currentPassword, newPassword: newPassword));
  }

  @override
  UserEntity? get currentUser => null; // rely on authStateChanges stream via Riverpod provider

  @override
  Future<Result<UserEntity>> signInWithEmail({required String email, required String password}) {
    return guard(() async {
      final credential = await _remote.signInWithEmail(email, password);
      final uid = credential.user!.uid;
      await _remote.touchLastLogin(uid);
      final model = await _remote.resolveUserProfile(uid);
      return model.toEntity();
    });
  }

  @override
  Future<Result<UserEntity>> signUpWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return guard(() async {
      final credential = await _remote.signUpWithEmail(email, password);
      final uid = credential.user!.uid;
      final model = await _remote.createUserProfile(uid: uid, name: name, email: email, phone: phone);
      return model.toEntity();
    });
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) {
    return guard(() => _remote.sendPasswordResetEmail(email));
  }

  @override
  Future<Result<void>> signOut() {
    return guard(() => _remote.signOut());
  }

  @override
  Future<Result<String>> sendOtp(String phoneNumber) {
    return guard(() => _remote.sendOtp(phoneNumber));
  }

  @override
  Future<Result<UserEntity>> verifyOtp({required String verificationId, required String smsCode}) {
    return guard(() async {
      final credential = await _remote.verifyOtp(verificationId: verificationId, smsCode: smsCode);
      final uid = credential.user!.uid;
      try {
        final model = await _remote.resolveUserProfile(uid);
        await _remote.touchLastLogin(uid);
        return model.toEntity();
      } on NotFoundException {
        // First-time phone sign-in — create a bare profile.
        final model = await _remote.createUserProfile(
          uid: uid,
          name: '',
          email: credential.user!.email ?? '',
          phone: credential.user!.phoneNumber ?? '',
        );
        return model.toEntity();
      }
    });
  }
}
