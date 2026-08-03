import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/address_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// FIXED: this used to be local-only storage via SharedPreferences,
/// which lives in the app's private data directory — wiped on every
/// uninstall (including the uninstall+reinstall we do after most
/// rebuilds), so saved addresses kept disappearing even though
/// nothing else did. Now stored server-side in Firestore under
/// users/{uid}/addresses, same pattern as business_info, so addresses
/// survive reinstalls, app-data clears, and even a fresh device —
/// exactly what's needed now that checkout (place order) depends on
/// them too, not just the standalone "My Addresses" screen.
class AddressListNotifier extends AsyncNotifier<List<AddressEntity>> {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? _collectionFor(String? uid) {
    if (uid == null) return null;
    return _firestore.collection(FirestorePaths.users).doc(uid).collection(FirestorePaths.addressesSubcollection);
  }

  @override
  Future<List<AddressEntity>> build() async {
    // Watching this means the address list automatically reloads (and
    // correctly shows an empty list for a fresh account) the moment the
    // signed-in user changes, rather than keeping whatever was loaded
    // for the previous session.
    final uid = ref.watch(currentUserProvider)?.uid;
    return _load(uid);
  }

  Future<List<AddressEntity>> _load(String? uid) async {
    final collection = _collectionFor(uid);
    if (collection == null) return [];
    final snapshot = await collection.get();
    return snapshot.docs.map((doc) => AddressEntity.fromJson({...doc.data(), 'id': doc.id})).toList();
  }

  Future<void> addOrUpdate(AddressEntity address) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final collection = _collectionFor(uid);
    if (collection == null) return;

    final current = state.valueOrNull ?? [];
    final withoutThis = current.where((a) => a.id != address.id).toList();

    // Only one default address at a time — if this one is being set as
    // default, clear the flag on every other saved address.
    var updated = address.isDefault
        ? withoutThis.map((a) => a.copyWith(isDefault: false)).toList()
        : withoutThis;

    updated = [...updated, address];
    state = AsyncData(updated);

    final json = address.toJson()..remove('id');
    await collection.doc(address.id).set(json);

    if (address.isDefault) {
      // Persist the cleared default flag for every other address doc too.
      final batch = _firestore.batch();
      for (final other in withoutThis) {
        if (other.isDefault) {
          batch.set(collection.doc(other.id), {'isDefault': false}, SetOptions(merge: true));
        }
      }
      await batch.commit();
    }
  }

  Future<void> remove(String id) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final collection = _collectionFor(uid);
    if (collection == null) return;

    final current = state.valueOrNull ?? [];
    final updated = current.where((a) => a.id != id).toList();
    state = AsyncData(updated);
    await collection.doc(id).delete();
  }

  Future<void> setDefault(String id) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final collection = _collectionFor(uid);
    if (collection == null) return;

    final current = state.valueOrNull ?? [];
    final updated = current.map((a) => a.copyWith(isDefault: a.id == id)).toList();
    state = AsyncData(updated);

    final batch = _firestore.batch();
    for (final a in updated) {
      batch.set(collection.doc(a.id), {'isDefault': a.isDefault}, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

final addressListProvider = AsyncNotifierProvider<AddressListNotifier, List<AddressEntity>>(
  AddressListNotifier.new,
);
