import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

/// Only this class talks to Firebase directly for auth. RepositoryImpl
/// depends on this abstraction so it can be mocked in tests.
class AuthRemoteDataSource {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AuthRemoteDataSource({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Stream<fb.User?> get firebaseAuthStateChanges => _firebaseAuth.authStateChanges();

  fb.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Resolves the full profile for a signed-in Firebase user by checking
  /// staff_users first (admin/employee), falling back to users (customer).
  /// This mirrors the confirmed decision: role-checking via Firestore
  /// lookup, not custom claims.
  Future<UserModel> resolveUserProfile(String uid) async {
    final staffDoc = await _firestore.collection(FirestorePaths.staffUsers).doc(uid).get();
    if (staffDoc.exists) {
      final data = staffDoc.data()!;
      return UserModel(
        uid: uid,
        name: data['name'] as String?,
        email: data['email'] as String?,
        phone: data['phone'] as String?,
        photoUrl: data['photoUrl'] as String?,
        role: (data['role'] as String?) ?? 'employee',
        isBlocked: !(data['isActive'] as bool? ?? true),
      );
    }

    final userDoc = await _firestore.collection(FirestorePaths.users).doc(uid).get();
    if (userDoc.exists) {
      final model = UserModel.fromFirestore(userDoc);
      // Some accounts have a Firebase Auth displayName but an empty/missing
      // 'name' field in Firestore (e.g. accounts created outside the normal
      // sign-up flow) — fall back to that rather than showing "Guest".
      if (model.name == null || model.name!.trim().isEmpty) {
        final displayName = _firebaseAuth.currentUser?.displayName;
        if (displayName != null && displayName.trim().isNotEmpty) {
          return UserModel(
            uid: model.uid,
            name: displayName,
            email: model.email,
            phone: model.phone,
            photoUrl: model.photoUrl,
            role: model.role,
            loyaltyPoints: model.loyaltyPoints,
            defaultAddressId: model.defaultAddressId,
            isBlocked: model.isBlocked,
            fcmTokens: model.fcmTokens,
          );
        }
      }
      return model;
    }

    throw const NotFoundException('User profile not found in Firestore.');
  }

  Future<fb.UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  Future<fb.UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      // Fire-and-forget is deliberate here — a failure to SEND the
      // verification email (e.g. a transient network blip) shouldn't
      // block account creation, which already succeeded. The Verify
      // Email screen has its own "resend" button to recover from this.
      unawaited(credential.user?.sendEmailVerification());
      return credential;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  /// Re-sends the verification link — used by the "Resend email" button
  /// on the Verify Email screen when the first one didn't arrive.
  Future<void> resendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');
    await user.sendEmailVerification();
  }

  /// Firebase caches emailVerified locally, so it only reflects reality
  /// right after a fresh reload() — this is what the Verify Email
  /// screen's "I've verified" button calls before checking the flag.
  Future<bool> refreshAndCheckEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  /// Kicks off Firebase Phone Auth — sends the SMS and returns the
  /// verificationId the OTP screen needs to actually verify the code
  /// the user receives. Android may auto-resolve without ever needing
  /// verifyOtp at all (Play Services reads the SMS itself); when that
  /// happens this completes the sign-in directly and the returned
  /// verificationId becomes moot, which the OTP screen handles by
  /// just treating that as "already signed in, move on."
  Future<String> sendOtp(String phoneNumber) async {
    final completer = Completer<String>();
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // Auto-retrieval succeeded — sign in immediately rather than
          // waiting on a manual code entry that isn't needed.
          try {
            await _firebaseAuth.signInWithCredential(credential);
          } catch (_) {
            // Swallowed deliberately: if auto sign-in fails here, the
            // user still has the manual OTP path as a fallback once
            // verificationId comes through codeSent below.
          }
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) completer.completeError(AuthException(_mapFirebaseAuthError(e)));
        },
        codeSent: (verificationId, resendToken) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) completer.complete(verificationId);
        },
      );
    } on fb.FirebaseAuthException catch (e) {
      if (!completer.isCompleted) completer.completeError(AuthException(_mapFirebaseAuthError(e)));
    }
    return completer.future;
  }

  Future<fb.UserCredential> verifyOtp({required String verificationId, required String smsCode}) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      return await _firebaseAuth.signInWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  /// Creates the users/{uid} Firestore doc immediately after Firebase Auth
  /// signup succeeds. A Cloud Function onCreate trigger (backend/functions)
  /// acts as a fallback if this client write ever fails mid-flow.
  Future<UserModel> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) async {
    final model = UserModel(uid: uid, name: name, email: email, phone: phone, role: 'customer');
    await _firestore.collection(FirestorePaths.users).doc(uid).set(model.toFirestoreCreate());
    return model;
  }

  Future<void> touchLastLogin(String uid) async {
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .set({'lastLoginAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  Future<String> uploadProfilePhoto(File file) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');

    // uid gets its own path segment (not baked into the filename) so
    // the Storage rule can just check the segment directly — no
    // string-splitting needed, which sidesteps a real gotcha: Storage
    // rules' split() takes a REGEX, not a literal string, so split('.')
    // was matching every character (since '.' is a regex wildcard),
    // not just the actual period.
    final ref = _storage.ref('profile_photos/${user.uid}/photo.jpg');
    final snapshot = await ref.putFile(file);
    if (snapshot.state != TaskState.success) {
      throw Exception('Photo upload did not complete (state: ${snapshot.state}).');
    }
    return snapshot.ref.getDownloadURL();
  }

  Future<void> updateProfile({required String name, required String phone, String? photoUrl}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');

    final updates = <String, dynamic>{'name': name, 'phone': phone};
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    // Staff (admin/employee) accounts live in staff_users, not users —
    // writing to users unconditionally here was a real bug: it always
    // "succeeded" (creating/touching an unrelated users doc for staff
    // accounts) while never touching the staff_users doc the profile
    // screen actually reads from, so edits for admin/employee looked
    // like they saved but silently never showed up.
    final staffRef = _firestore.collection(FirestorePaths.staffUsers).doc(user.uid);
    final staffDoc = await staffRef.get();
    if (staffDoc.exists) {
      await staffRef.set(updates, SetOptions(merge: true));
    } else {
      await _firestore.collection(FirestorePaths.users).doc(user.uid).set(
        updates,
        SetOptions(merge: true),
      );
    }

    await user.updateDisplayName(name);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) throw const AuthException('Not signed in.');

    try {
      final credential = fb.EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  String _mapFirebaseAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // Deliberately the same generic message for all three — telling
        // someone specifically "no account with this email" vs "wrong
        // password" leaks whether an email is registered at all, which
        // is exactly the kind of thing you don't want to hand an
        // attacker trying to guess valid accounts.
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
