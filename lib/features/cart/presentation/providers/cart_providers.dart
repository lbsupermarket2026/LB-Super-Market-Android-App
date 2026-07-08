import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../domain/entities/cart_item_entity.dart';

/// Local-only for now, same reasoning as Addresses/Wishlist — this app has
/// no `carts` write path wired up yet even though FirestorePaths.carts is
/// reserved for it. When checkout gets built, this is the notifier to
/// swap over to a Firestore-backed cart under carts/{uid}.
const _prefsKey = 'cart_items';

class CartNotifier extends AsyncNotifier<List<CartItemEntity>> {
  @override
  Future<List<CartItemEntity>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    return raw.map((s) => CartItemEntity.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> _persist(List<CartItemEntity> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, items.map((i) => jsonEncode(i.toJson())).toList());
  }

  Future<void> addProduct(ProductEntity product) async {
    final current = List<CartItemEntity>.from(state.valueOrNull ?? []);
    final index = current.indexWhere((i) => i.productId == product.id);

    if (index >= 0) {
      current[index] = current[index].copyWith(quantity: current[index].quantity + 1);
    } else {
      current.add(CartItemEntity(
        productId: product.id,
        name: product.name,
        unit: product.unit,
        imageUrl: product.primaryImage,
        price: product.displayPrice,
        quantity: 1,
      ));
    }

    state = AsyncData(current);
    await _persist(current);
  }

  Future<void> setQuantity(String productId, int quantity) async {
    final current = List<CartItemEntity>.from(state.valueOrNull ?? []);
    if (quantity <= 0) {
      current.removeWhere((i) => i.productId == productId);
    } else {
      final index = current.indexWhere((i) => i.productId == productId);
      if (index >= 0) current[index] = current[index].copyWith(quantity: quantity);
    }
    state = AsyncData(current);
    await _persist(current);
  }

  Future<void> remove(String productId) => setQuantity(productId, 0);

  Future<void> clear() async {
    state = const AsyncData([]);
    await _persist([]);
  }

  int quantityOf(String productId) =>
      state.valueOrNull?.firstWhere((i) => i.productId == productId, orElse: () => const CartItemEntity(
            productId: '',
            name: '',
            unit: '',
            imageUrl: '',
            price: 0,
            quantity: 0,
          )).quantity ??
      0;
}

final cartProvider = AsyncNotifierProvider<CartNotifier, List<CartItemEntity>>(CartNotifier.new);

final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartProvider).valueOrNull ?? [];
  return items.fold(0, (sum, item) => sum + item.quantity);
});

final cartTotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider).valueOrNull ?? [];
  return items.fold(0.0, (sum, item) => sum + item.lineTotal);
});
