import 'dart:io';
import '../../../../core/error/result.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

// Unique sentinel — identity-compared (==), never equal to any real
// value, used to mark a resolveUserProfile() result as superseded by
// a newer auth event so it can be filtered out of the stream.
final Object _staleMarker = Object();

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  AuthRepositoryImpl(this._remote);

  // Bumped on every Firebase auth event — lets a resolveUserProfile()
  // call that's still in flight when a NEWER auth event arrives know
  // it's now stale and should be discarded rather than emitted. Without
  // this, sign-out-then-sign-in-quickly could let an older account's
  // profile lookup finish AFTER a newer one and silently overwrite it —
  // exactly the "signs in as customer, lands on employee's profile" bug.
  int _authEventGeneration = 0;

  @override
  Stream<UserEntity?> authStateChanges() {
    return _remote.firebaseAuthStateChanges.asyncMap<Object?>((firebaseUser) async {
      final myGeneration = ++_authEventGeneration;

      if (firebaseUser == null) return null;
      UserEntity? result;
      try {
        final model = await _remote.resolveUserProfile(firebaseUser.uid);
        result = model.toEntity();
      } catch (_) {
        // Profile doc not created yet (e.g. mid-signup race) — treat as signed out
        // until the doc exists; UI will retry via the stream on next emission.
        result = null;
      }

      // A newer auth event arrived while this lookup was in flight —
      // this result is for an account that's no longer the current
      // one, so it must never reach the stream's listeners.
      if (myGeneration != _authEventGeneration) {
        return _staleMarker;
      }
      return result;
    }).where((value) => value != _staleMarker).cast<UserEntity?>();
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
  Future<Result<void>> resendEmailVerification() {
    return guard(() => _remote.resendEmailVerification());
  }

  @override
  Future<Result<bool>> refreshAndCheckEmailVerified() {
    return guard(() => _remote.refreshAndCheckEmailVerified());
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
      final phone = credential.user!.phoneNumber ?? '';

      // Brand-new phone sign-in has no Firestore doc yet — customer
      // signups otherwise always go through createUserProfile right
      // after Firebase Auth succeeds, so this mirrors that for the
      // phone path. Name stays empty; they can fill it in from Profile
      // whenever they want, same as any account missing optional info.
      try {
        final model = await _remote.resolveUserProfile(uid);
        await _remote.touchLastLogin(uid);
        return model.toEntity();
      } on NotFoundException {
        return (await _remote.createUserProfile(uid: uid, name: '', email: '', phone: phone)).toEntity();
      }
    });
  }

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
  Future<Result<UserEntity>> signInWithIdentifierAndPassword({
    required String identifier,
    required String password,
  }) {
    return guard(() async {
      final credential = await _remote.signInWithIdentifierAndPassword(identifier: identifier, password: password);
      final uid = credential.user!.uid;
      await _remote.touchLastLogin(uid);
      final model = await _remote.resolveUserProfile(uid);
      return model.toEntity();
    });
  }

  @override
  Future<Result<UserEntity>> signUpWithPhoneAndPassword({
    required String name,
    required String phone,
    required String password,
    required String verificationId,
    required String smsCode,
  }) {
    return guard(() async {
      final credential = await _remote.signUpWithPhoneAndPassword(
        verificationId: verificationId,
        smsCode: smsCode,
        phone: phone,
        password: password,
      );
      final uid = credential.user!.uid;
      final model = await _remote.createUserProfile(uid: uid, name: name, email: '', phone: phone);
      return model.toEntity();
    });
  }
}
