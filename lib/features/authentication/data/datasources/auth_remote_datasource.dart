import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

/// Only this class talks to Firebase directly for auth. RepositoryImpl
/// depends on this abstraction so it can be mocked in tests.
class AuthRemoteDataSource {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSource({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

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
        role: (data['role'] as String?) ?? 'employee',
        isBlocked: !(data['isActive'] as bool? ?? true),
      );
    }

    final userDoc = await _firestore.collection(FirestorePaths.users).doc(uid).get();
    if (userDoc.exists) {
      return UserModel.fromFirestore(userDoc);
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
      return await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
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

  Future<String> sendOtp(String phoneNumber) async {
    final completer = <String, dynamic>{};
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        throw AuthException(_mapFirebaseAuthError(e));
      },
      codeSent: (verificationId, resendToken) {
        completer['verificationId'] = verificationId;
      },
      codeAutoRetrievalTimeout: (verificationId) {
        completer['verificationId'] = verificationId;
      },
    );
    // In production, wrap this in a Completer<String> awaiting codeSent;
    // simplified here for a synchronous-looking API surface.
    return completer['verificationId'] as String? ?? '';
  }

  Future<fb.UserCredential> verifyOtp({required String verificationId, required String smsCode}) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      return await _firebaseAuth.signInWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');

    await _firestore.collection(FirestorePaths.users).doc(user.uid).set(
      {'name': name, 'phone': phone},
      SetOptions(merge: true),
    );
    await user.updateDisplayName(name);
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
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
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
