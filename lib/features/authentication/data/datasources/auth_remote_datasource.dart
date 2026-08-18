import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/push_notification_service.dart';
import '../models/user_model.dart';

/// Only this class talks to Firebase directly for auth. RepositoryImpl
/// depends on this abstraction so it can be mocked in tests.
class AuthRemoteDataSource {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  AuthRemoteDataSource({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  Stream<fb.User?> get firebaseAuthStateChanges => _firebaseAuth.authStateChanges();

  fb.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Resolves the full profile for a signed-in Firebase user by checking
  /// staff_users first (admin/employee), falling back to users (customer).
  /// This mirrors the confirmed decision: role-checking via Firestore
  /// lookup, not custom claims.
  Future<UserModel> resolveUserProfile(String uid) async {
    const serverOnly = GetOptions();

    // IMPORTANT:
    // Staff must be checked FIRST.
    final staffDoc = await _firestore
        .collection(FirestorePaths.staffUsers)
        .doc(uid)
        .get(serverOnly);

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

    // Customer fallback
    final userDoc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .get(serverOnly);

    if (userDoc.exists) {
      final model = UserModel.fromFirestore(userDoc);

      if (model.name == null || model.name!.trim().isEmpty) {
        final displayName = _firebaseAuth.currentUser?.displayName;

        if (displayName != null && displayName.trim().isNotEmpty) {
          return UserModel(
            uid: model.uid,
            name: displayName,
            email: model.email,
            phone: model.phone,
            photoUrl: model.photoUrl,
            customerCode: model.customerCode,
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

    throw const NotFoundException(
      'User profile not found in Firestore.',
    );
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

      unawaited(credential.user?.sendEmailVerification());
      return credential;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  Future<void> resendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');
    await user.sendEmailVerification();
  }

  Future<bool> refreshAndCheckEmailVerified() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  Future<(String verificationId, int? resendToken)> sendOtp(
    String phoneNumber, {
    int? forceResendingToken,
  }) async {
    final completer = Completer<(String, int?)>();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,

        verificationCompleted: (credential) {
          // Do NOT automatically sign in here.
          // Wait for the user to enter the OTP and tap Verify.
        },

        verificationFailed: (e) {
          print('========== PHONE OTP ERROR ==========');
          print('CODE: ${e.code}');
          print('MESSAGE: ${e.message}');
          print('PLUGIN: ${e.plugin}');
          print('DETAILS: ${e.toString()}');
          print('=====================================');

          if (!completer.isCompleted) {
            completer.completeError(
              AuthException(
                '${e.code}: ${e.message ?? "Unknown Firebase phone auth error"}',
              ),
            );
          }
        },

        codeSent: (verificationId, resendToken) {
          if (!completer.isCompleted) {
            completer.complete((verificationId, resendToken));
          }
        },

        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) {
            completer.complete((verificationId, null));
          }
        },
      );
    } on fb.FirebaseAuthException catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          AuthException(_mapFirebaseAuthError(e)),
        );
      }
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

    final staffDoc = await _firestore.collection(FirestorePaths.staffUsers).doc(uid).get();
    if (staffDoc.exists) {
      await _firestore.collection(FirestorePaths.staffUsers).doc(uid).set(
        {'lastLoginAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return;
    }
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

  Future<void> signOut() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid != null) {
      // Best-effort — a failure here shouldn't block sign-out itself,
      // worst case this device keeps a stale token until it's pruned
      // on the next failed send server-side.
      try {
        await PushNotificationService.instance.clearTokenOnSignOut(uid);
      } catch (_) {}
    }
    await _firebaseAuth.signOut();
  }

  Future<String> uploadProfilePhoto(File file) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');

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


  bool looksLikeEmail(String identifier) => identifier.contains('@');

  Future<fb.UserCredential> signUpWithPhoneAndPassword({
  required String verificationId,
  required String smsCode,
  required String phone,
  required String email,
  required String password,
}) async {
  try {
    final phoneCredential = fb.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential =
        await _firebaseAuth.signInWithCredential(phoneCredential);

    final emailCredential = fb.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await userCredential.user!
        .linkWithCredential(emailCredential);

    return userCredential;
  } on fb.FirebaseAuthException catch (e) {
    if (e.code == 'provider-already-linked' ||
        e.code == 'credential-already-in-use' ||
        e.code == 'email-already-in-use') {
      throw const AuthException(
          'This phone number or email is already registered.');
    }

    throw AuthException(_mapFirebaseAuthError(e));
  }
}

  Future<fb.UserCredential> signInWithIdentifierAndPassword({
    required String identifier,
    required String password,
  }) async {
    try {
      // -----------------------
      // Login using Email
      // -----------------------
      if (looksLikeEmail(identifier)) {
        return await _firebaseAuth.signInWithEmailAndPassword(
          email: identifier.trim(),
          password: password,
        );
      }


      final callable = _functions.httpsCallable('getEmailByPhone');

      String phone = identifier.trim().replaceAll(RegExp(r'\s+'), '');

      if (RegExp(r'^\d{10}$').hasMatch(phone)) {
        phone = '+91$phone';
      } else if (RegExp(r'^91\d{10}$').hasMatch(phone)) {
        phone = '+$phone';
      }


      final result = await callable.call({
        'phone': phone,
      });


      final email = result.data['email'] as String?;

        print('PHONE LOGIN EMAIL = $email');

        if (email == null || email.isEmpty) {
          throw const AuthException(
            'No account found with this phone number.',
          );
        }

      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

    } on fb.FirebaseAuthException catch (e) {
      print("========== FIREBASE LOGIN ERROR ==========");
      print("Code    : ${e.code}");
      print("Message : ${e.message}");
      print("==========================================");

      throw AuthException(_mapFirebaseAuthError(e));
    } on FirebaseFunctionsException catch (e) {
      print("========== FUNCTIONS LOGIN ERROR ==========");
      print("Code    : ${e.code}");
      print("Message : ${e.message}");
      print("============================================");

      throw AuthException(
        e.message ?? 'Could not find an account for this phone number.',
      );
    }
  }

  Future<fb.UserCredential> resetPasswordWithPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String newPassword,
  }) async {
    try {
      final phoneCredential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Firebase Phone Auth requires authentication before
      // updatePassword() can be performed.
      final userCredential =
          await _firebaseAuth.signInWithCredential(phoneCredential);

      final user = userCredential.user;

      if (user == null) {
        throw const AuthException(
          'Could not verify your phone number.',
        );
      }

      await user.updatePassword(newPassword);

      // IMPORTANT:
      // Password reset should NOT leave the user logged in.
      await _firebaseAuth.signOut();

      return userCredential;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;

      throw const AuthException(
        'Could not reset your password. Please try again.',
      );
    }
  }

  Future<bool> checkPhoneRegistered(String phone) async {
    try {
      final callable = _functions.httpsCallable('checkPhoneRegistered');
      final result = await callable.call({'phone': phone});
      return result.data['registered'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Could not check this number right now.');
    }
  }

  Future<bool> checkEmailRegistered(String email) async {
    try {
      final callable = _functions.httpsCallable('checkEmailRegistered');

      final result = await callable.call({
        'email': email.trim().toLowerCase(),
      });

      return result.data['registered'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(
        e.message ?? 'Could not check this email right now.',
      );
    }
  }


  Future<void> sendEmailOtp(String email) async {
    try {
      final callable = _functions.httpsCallable('sendEmailOtp');
      await callable.call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Could not send the verification code.');
    }
  }

  Future<bool> verifyEmailOtp({required String email, required String code}) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailOtp');
      final result = await callable.call({'email': email, 'code': code});
      return result.data['valid'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Could not verify the code.');
    }
  }

  Future<fb.UserCredential> createAccountAfterEmailOtp(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      try {
        final callable = _functions.httpsCallable('markEmailVerified');
        await callable.call({'uid': credential.user!.uid});
        await credential.user!.reload();
      } catch (_) {

      }
      return credential;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }
}

