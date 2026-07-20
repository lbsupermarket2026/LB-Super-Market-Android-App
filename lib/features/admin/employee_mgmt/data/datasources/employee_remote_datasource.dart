import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/staff_member_entity.dart';

class EmployeeRemoteDataSource {
  final FirebaseFirestore _firestore;
  EmployeeRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('staff_users');

  Future<List<StaffMemberEntity>> getAllStaff() async {
    final snapshot = await _collection.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return StaffMemberEntity(
        uid: doc.id,
        name: (data['name'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
        phone: (data['phone'] as String?) ?? '',
        role: StaffRoleX.fromString((data['role'] as String?) ?? 'employee'),
        createdAt: ((data['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      );
    }).toList();
  }

  /// Creating a Firebase Auth user via the client SDK normally signs the
  /// *caller* in as that new user — which would log the admin out of
  /// their own session. To avoid that, the new account is created on a
  /// throwaway secondary Firebase App instance, then immediately torn
  /// down, leaving the admin's own session on the default app untouched.
  Future<void> createEmployee({
    required String name,
    required String email,
    required String phone,
    required String password,
    required StaffRole role,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'employee_creation_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;
      await secondaryAuth.signOut();

      await _collection.doc(uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': role == StaffRole.admin ? 'admin' : 'employee',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } finally {
      await secondaryApp.delete();
    }
  }

  /// Editing an existing staff member's name/phone/role — deliberately
  /// doesn't touch email, since changing another person's login email
  /// isn't something the client SDK can do safely (that's an Auth
  /// account-level change, not a Firestore field).
  Future<void> updateEmployee({
    required String uid,
    required String name,
    required String phone,
    required StaffRole role,
  }) async {
    await _collection.doc(uid).update({
      'name': name,
      'phone': phone,
      'role': role == StaffRole.admin ? 'admin' : 'employee',
    });
  }

  /// Revokes staff access by deleting the staff_users doc — Firestore
  /// rules key off this doc's existence (isStaff()), so this immediately
  /// cuts off admin/employee access. It does NOT delete the underlying
  /// Firebase Auth account itself — that requires the Admin SDK, which
  /// isn't available from a Flutter client. The person could still sign
  /// in, but would land as a plain customer with no staff permissions.
  Future<void> removeStaffAccess(String uid) async {
    await _collection.doc(uid).delete();
  }
}
