import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only for now, same reasoning as addresses — stored per-device via
/// SharedPreferences since there's no wishlist collection in Firestore yet.
/// Move this to users/{uid}/wishlist in Firestore if you want it synced
/// across devices later.
const _prefsKey = 'wishlist_product_ids';

class WishlistNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? []).toSet();
  }

  Future<void> _persist(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids.toList());
  }

  Future<void> toggle(String productId) async {
    final current = Set<String>.from(state.valueOrNull ?? {});
    if (current.contains(productId)) {
      current.remove(productId);
    } else {
      current.add(productId);
    }
    state = AsyncData(current);
    await _persist(current);
  }

  Future<void> remove(String productId) async {
    final current = Set<String>.from(state.valueOrNull ?? {});
    current.remove(productId);
    state = AsyncData(current);
    await _persist(current);
  }

  bool isWishlisted(String productId) => state.valueOrNull?.contains(productId) ?? false;
}

final wishlistProvider = AsyncNotifierProvider<WishlistNotifier, Set<String>>(WishlistNotifier.new);
