import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/address_entity.dart';

/// Local-only storage for now — persisted per-device via SharedPreferences,
/// since there's no addresses collection in Firestore yet. This is fine
/// for "My Addresses" as a standalone profile section, but once checkout
/// needs these (synced across devices, used server-side for delivery),
/// move this to a Firestore subcollection under users/{uid}/addresses
/// following the same repository pattern as business_info.
const _prefsKey = 'saved_addresses';

class AddressListNotifier extends AsyncNotifier<List<AddressEntity>> {
  @override
  Future<List<AddressEntity>> build() => _load();

  Future<List<AddressEntity>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map((s) => AddressEntity.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> _persist(List<AddressEntity> addresses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, addresses.map((a) => jsonEncode(a.toJson())).toList());
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
