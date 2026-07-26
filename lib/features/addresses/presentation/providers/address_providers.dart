import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/address_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// Local-only storage for now — persisted per-device via SharedPreferences,
/// since there's no addresses collection in Firestore yet. This is fine
/// for "My Addresses" as a standalone profile section, but once checkout
/// needs these (synced across devices, used server-side for delivery),
/// move this to a Firestore subcollection under users/{uid}/addresses
/// following the same repository pattern as business_info.
///
/// The key is scoped per signed-in user's uid — without that, every
/// account on the same physical device shared the exact same saved
/// addresses, so signing in as a different person inherited whatever
/// the previous account had saved. "_guest" is only a fallback for the
/// narrow window before auth state resolves; addresses genuinely
/// belonging to no one shouldn't normally get created.
String _prefsKeyFor(String? uid) => 'saved_addresses_${uid ?? "_guest"}';

class AddressListNotifier extends AsyncNotifier<List<AddressEntity>> {
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKeyFor(uid)) ?? [];
    return raw.map((s) => AddressEntity.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> _persist(List<AddressEntity> addresses) async {
    final uid = ref.read(currentUserProvider)?.uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyFor(uid), addresses.map((a) => jsonEncode(a.toJson())).toList());
  }

  Future<void> addOrUpdate(AddressEntity address) async {
    final current = state.valueOrNull ?? [];
    final withoutThis = current.where((a) => a.id != address.id).toList();

    // Only one default address at a time — if this one is being set as
    // default, clear the flag on every other saved address.
    var updated = address.isDefault
        ? withoutThis.map((a) => a.copyWith(isDefault: false)).toList()
        : withoutThis;

    updated = [...updated, address];
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> remove(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((a) => a.id != id).toList();
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setDefault(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.map((a) => a.copyWith(isDefault: a.id == id)).toList();
    state = AsyncData(updated);
    await _persist(updated);
  }
}

final addressListProvider = AsyncNotifierProvider<AddressListNotifier, List<AddressEntity>>(
  AddressListNotifier.new,
);
