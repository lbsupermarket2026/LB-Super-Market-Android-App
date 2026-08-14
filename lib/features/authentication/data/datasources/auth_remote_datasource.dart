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
        _functions = functions ?? FirebaseFunctions.instance;

  Stream<fb.User?> get firebaseAuthStateChanges => _firebaseAuth.authStateChanges();

  fb.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Resolves the full profile for a signed-in Firebase user by checking
  /// staff_users first (admin/employee), falling back to users (customer).
  /// This mirrors the confirmed decision: role-checking via Firestore
  /// lookup, not custom claims.
  Future<UserModel> resolveUserProfile(String uid) async {
    // Checks the CUSTOMER collection first, staff second — reversed
    // from the original order. A genuine staff account (created only
    // through Employee Management) never has a matching users/{uid}
    // doc, so this is safe for them; they still correctly fall through
    // to the staff check below. But if anything ever causes the staff
    // check to match a uid it shouldn't (a stale/leftover document, a
    // caching quirk, whatever the exact mechanism turns out to be),
    // checking customer first means a genuine customer account can no
    // longer be shadowed by it.
    // FIXED: was Source.server, which skips Firestore's offline cache
    // entirely and throws if the network isn't ready yet — very
    // common in the first moments of a cold app start, right when
    // Firebase Auth is restoring its persisted session. That throw
    // was being caught in authStateChanges() and treated as "signed
    // out", forcing a fresh login even with a perfectly valid Auth
    // session. Default GetOptions (cache-then-server) uses the
    // offline cache persistenceEnabled already turns on, so a cold
    // start with a not-yet-ready network still resolves instantly
    // from cache instead of failing outright.
    const serverOnly = GetOptions();
    final userDoc = await _firestore.collection(FirestorePaths.users).doc(uid).get(serverOnly);
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

    final staffDoc = await _firestore.collection(FirestorePaths.staffUsers).doc(uid).get(serverOnly);
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
  // FIXED: codeSent's resendToken parameter was received but never
  // captured or reused anywhere — every "resend" was just calling
  // verifyPhoneNumber() fresh with no forceResendingToken at all.
  // Firebase's phone auth can silently reject a resend for the same
  // number within its rate-limiting window without that token, which
  // is exactly why the first OTP arrived but every resend after it
  // didn't. Now accepts an optional forceResendingToken (pass the one
  // from the PREVIOUS attempt's result when this is a genuine resend,
  // omit it for a first-time send) and returns the new token alongside
  // the verificationId so the caller can chain further resends
  // correctly.
  Future<(String verificationId, int? resendToken)> sendOtp(String phoneNumber, {int? forceResendingToken}) async {
    final completer = Completer<(String, int?)>();
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
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
          if (!completer.isCompleted) completer.complete((verificationId, resendToken));
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) completer.complete((verificationId, null));
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
    // Staff accounts must NEVER get a users/{uid} doc written for them —
    // this was the actual root cause of the "every admin/employee login
    // gets treated as a customer" bug. With SetOptions(merge: true),
    // this call CREATES the doc if none exists, and since
    // resolveUserProfile() checks the customer collection first, that
    // freshly-created (empty) doc immediately shadowed the real
    // staff_users record on the very next profile resolution — meaning
    // deleting the stray doc never actually fixed anything, because the
    // next login just recreated it right away.
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

  // ============================================================
  // Unified phone-or-email + password auth. Firebase itself has no
  // native "phone + password" method — phone auth is OTP-only, email
  // auth is separate. The standard workaround: verify the phone via
  // OTP once (at signup only), then link an email/password credential
  // to that SAME account using a deterministic internal address
  // derived from the phone number. After that, "phone + password"
  // login is really "translate phone to its internal address, then
  // do a normal email/password sign-in" — no OTP needed again, same
  // as logging into any other app with a phone number and password.
  // ============================================================

  /// Deterministic, not stored anywhere — recomputed from the phone
  /// number itself every time, so there's nothing to keep in sync.
  String _syntheticEmailForPhone(String e164Phone) {
    final digitsOnly = e164Phone.replaceAll(RegExp(r'[^\d]'), '');
    return '$digitsOnly@phone.freshcart.internal';
  }

  bool looksLikeEmail(String identifier) => identifier.contains('@');

  /// Completes a phone signup: verifies the OTP code (proving the
  /// person actually owns this number), then links a password
  /// credential to that same account so future logins don't need
  /// OTP again. Returns the signed-in credential; profile creation
  /// happens at the repository layer same as any other signup.
  Future<fb.UserCredential> signUpWithPhoneAndPassword({
    required String verificationId,
    required String smsCode,
    required String phone,
    required String password,
  }) async {
    try {
      final phoneCredential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      final userCredential = await _firebaseAuth.signInWithCredential(phoneCredential);

      final syntheticEmail = _syntheticEmailForPhone(phone);
      final emailCredential = fb.EmailAuthProvider.credential(email: syntheticEmail, password: password);
      // Links rather than replaces — the account keeps its phone-auth
      // provider too, which is harmless and not currently used for
      // anything, but costs nothing to leave in place.
      await userCredential.user!.linkWithCredential(emailCredential);

      return userCredential;
    } on fb.FirebaseAuthException catch (e) {
      // NEW: signInWithCredential(phoneCredential) actually SUCCEEDS
      // even when this phone number already has an account — Firebase
      // just signs into the existing one, it doesn't fail on OTP
      // verification alone. The failure shows up one step later, at
      // linkWithCredential, as provider-already-linked (this account
      // already has an email/password credential) or
      // credential-already-in-use — neither of which was previously
      // mapped to a clear message, so it fell through to Firebase's
      // raw internal error text instead of telling the person plainly
      // that this number is already registered.
      if (e.code == 'provider-already-linked' || e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        throw const AuthException('This phone number is already registered. Try logging in instead.');
      }
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  /// Accepts either an email or a phone number as the identifier —
  /// email goes straight to normal sign-in; phone gets translated to
  /// its internal address first. Used for customer, employee, and
  /// admin sign-in alike, since staff accounts already have real
  /// emails on file and can be looked up the same way.
  Future<fb.UserCredential> signInWithIdentifierAndPassword({
    required String identifier,
    required String password,
  }) async {
    try {
      if (looksLikeEmail(identifier)) {
        return await _firebaseAuth.signInWithEmailAndPassword(email: identifier, password: password);
      }

      // Not an email — could be a staff phone (real email on file) or
      // a customer phone (synthetic email). Staff lookup goes through
      // a Cloud Function rather than a direct Firestore query, since
      // this runs BEFORE sign-in completes — the staff_users read rule
      // only allows already-authenticated reads, which a pre-auth
      // query can't satisfy no matter how it's written client-side.
      try {
        final callable = _functions.httpsCallable('lookupStaffEmailByPhone');
        final result = await callable.call({'phone': identifier});
        final staffEmail = result.data['email'] as String?;
        if (staffEmail != null && staffEmail.isNotEmpty) {
          return await _firebaseAuth.signInWithEmailAndPassword(email: staffEmail, password: password);
        }
      } on FirebaseFunctionsException {
        // Lookup itself failed (network, etc.) — fall through to the
        // customer path below rather than blocking sign-in entirely.
      }

      // Not staff — try as a customer via the deterministic synthetic
      // address. No Firestore lookup needed here since it's derived
      // directly from the phone number itself.
      final syntheticEmail = _syntheticEmailForPhone(identifier);
      return await _firebaseAuth.signInWithEmailAndPassword(email: syntheticEmail, password: password);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  /// Verifies the OTP (proving ownership of the phone number) and, in
  /// the SAME step, sets a new password on that account — this is what
  /// makes it a genuine reset rather than an OTP-only backdoor. Phone
  /// verification signs the user in as a side effect of how Firebase
  /// phone auth works, but they always leave this method with a newly
  /// set password already in place, not just "logged in with the same
  /// old password still active."
  Future<fb.UserCredential> resetPasswordWithPhoneOtp({
    required String verificationId,
    required String smsCode,
    required String newPassword,
  }) async {
    try {
      final phoneCredential = fb.PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      final userCredential = await _firebaseAuth.signInWithCredential(phoneCredential);
      await userCredential.user!.updatePassword(newPassword);
      return userCredential;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }

  // ============================================================
  /// "Forgot Password" must never send an OTP to a number that has no
  /// account — Firebase phone auth auto-creates a new account for any
  /// unregistered number rather than failing, so without this check,
  /// resetting a random/mistyped number would silently create a brand
  /// new account instead of giving a clear "no account found" error.
  Future<bool> checkPhoneRegistered(String phone) async {
    try {
      final callable = _functions.httpsCallable('checkPhoneRegistered');
      final result = await callable.call({'phone': phone});
      return result.data['registered'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Could not check this number right now.');
    }
  }

  // ============================================================
  // Email OTP — a real numeric code (via Cloud Function + SendGrid)
  // rather than the click-through link used elsewhere. Both calls go
  // through Cloud Functions specifically so the actual code value
  // never has to be readable from the client side at all.
  // ============================================================

  Future<void> sendEmailOtp(String email) async {
    try {
      final callable = _functions.httpsCallable('sendEmailOtp');
      await callable.call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Could not send the verification code.');
    }
  }

  /// Returns true only on a genuinely valid, unexpired, matching code
  /// — the function deletes it immediately after a successful check,
  /// so this can only ever succeed once per sent code.
  Future<bool> verifyEmailOtp({required String email, required String code}) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailOtp');
      final result = await callable.call({'email': email, 'code': code});
      return result.data['valid'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.message ?? 'Could not verify the code.');
    }
  }

  /// Called only after verifyEmailOtp has already returned true — the
  /// OTP step proves ownership of the email; this is the normal
  /// Firebase account creation that follows it, same as any other
  /// email/password signup. Firebase's emailVerified flag can only be
  /// set by the Admin SDK, not the client, so a Cloud Function call
  /// right after creation is what marks it true — without this, the
  /// person would land on the "verify your email" screen again
  /// immediately after already proving it via OTP, which would make
  /// the whole OTP step pointless.
  Future<fb.UserCredential> createAccountAfterEmailOtp(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      try {
        final callable = _functions.httpsCallable('markEmailVerified');
        await callable.call({'uid': credential.user!.uid});
        await credential.user!.reload();
      } catch (_) {
        // Best-effort — worst case they see one unnecessary "verify
        // your email" prompt despite already having done OTP, not a
        // broken signup. Account creation itself already succeeded.
      }
      return credential;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    }
  }
}
