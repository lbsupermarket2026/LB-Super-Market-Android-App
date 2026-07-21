import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/admin_inventory_datasource.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../../../../products/domain/entities/product_entity.dart';

final adminInventoryDataSourceProvider = Provider<AdminInventoryDataSource>((ref) {
  return AdminInventoryDataSource();
});

final allCategoriesAdminProvider = FutureProvider.autoDispose<List<CategoryEntity>>((ref) {
  return ref.watch(adminInventoryDataSourceProvider).getAllCategories();
});

final allProductsAdminProvider = FutureProvider.autoDispose<List<ProductEntity>>((ref) {
  return ref.watch(adminInventoryDataSourceProvider).getAllProducts();
});

class InventoryMutationState {
  final bool isSubmitting;
  final String? error;
  const InventoryMutationState({this.isSubmitting = false, this.error});
}

class InventoryMutationNotifier extends StateNotifier<InventoryMutationState> {
  final Ref _ref;
  InventoryMutationNotifier(this._ref) : super(const InventoryMutationState());

  Future<String?> _uploadIfNeeded(String folder, String id, File? imageFile) async {
    if (imageFile == null) return null;
    return _ref.read(adminInventoryDataSourceProvider).uploadImage(folder, id, imageFile);
  }

  Future<bool> saveCategory({
    String? id,
    required String name,
    File? imageFile,
    String? existingImageUrl,
    int sortOrder = 0,
    bool isActive = true,
    // "picked no offer" (null) vs "hasn't touched the offer field"
    // (also null, but nothing changes) look identical from a plain
    // nullable param — clearOfferId is how the form says "yes, I really
    // want this set to no offer" so an edit can remove a previously
    // assigned offer, not just add one.
    bool clearOfferId = false,
    String? offerId,
  }) async {
    state = const InventoryMutationState(isSubmitting: true);
    try {
      final ds = _ref.read(adminInventoryDataSourceProvider);
      if (id == null) {
        final newId = await ds.createCategory(name: name, sortOrder: sortOrder, offerId: offerId);
        final imageUrl = await _uploadIfNeeded('category_images', newId, imageFile);
        if (imageUrl != null) {
          await ds.updateCategory(id: newId, name: name, imageUrl: imageUrl);
        }
      } else {
        final imageUrl = await _uploadIfNeeded('category_images', id, imageFile) ?? existingImageUrl;
        await ds.updateCategory(
          id: id,
          name: name,
          imageUrl: imageUrl,
          sortOrder: sortOrder,
          isActive: isActive,
          offerId: offerId,
          clearOfferId: clearOfferId,
        );
      }
      state = const InventoryMutationState();
      _ref.invalidate(allCategoriesAdminProvider);
      return true;
    } catch (e) {
      state = InventoryMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    state = const InventoryMutationState(isSubmitting: true);
    try {
      await _ref.read(adminInventoryDataSourceProvider).deleteCategory(id);
      state = const InventoryMutationState();
      _ref.invalidate(allCategoriesAdminProvider);
      return true;
    } catch (e) {
      state = InventoryMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> saveProduct({
    String? id,
    required String name,
    String? description,
    String? brand,
    required String categoryId,
    File? imageFile,
    String? existingImageUrl,
    required double basePrice,
    double? mrp,
    double discountPercent = 0,
    required String unit,
    required int stockQty,
    int lowStockThreshold = 5,
    bool clearOfferId = false,
    String? offerId,
    bool isFeatured = false,
    bool isTrending = false,
    bool isBestSeller = false,
    bool isActive = true,
  }) async {
    state = const InventoryMutationState(isSubmitting: true);
    try {
      final ds = _ref.read(adminInventoryDataSourceProvider);
      if (id == null) {
        final newId = await ds.createProduct(
          name: name,
          description: description,
          brand: brand,
          categoryId: categoryId,
          basePrice: basePrice,
          mrp: mrp,
          discountPercent: discountPercent,
          unit: unit,
          stockQty: stockQty,
          lowStockThreshold: lowStockThreshold,
          offerId: offerId,
          isFeatured: isFeatured,
          isTrending: isTrending,
          isBestSeller: isBestSeller,
          isActive: isActive,
        );
        final imageUrl = await _uploadIfNeeded('product_images', newId, imageFile);
        if (imageUrl != null) {
          await ds.updateProduct(
            id: newId,
            name: name,
            description: description,
            brand: brand,
            categoryId: categoryId,
            thumbnailUrl: imageUrl,
            basePrice: basePrice,
            mrp: mrp,
            discountPercent: discountPercent,
            unit: unit,
            stockQty: stockQty,
            lowStockThreshold: lowStockThreshold,
            isFeatured: isFeatured,
            isTrending: isTrending,
            isBestSeller: isBestSeller,
            isActive: isActive,
          );
        }
      } else {
        final imageUrl = await _uploadIfNeeded('product_images', id, imageFile) ?? existingImageUrl;
        await ds.updateProduct(
          id: id,
          name: name,
          description: description,
          brand: brand,
          categoryId: categoryId,
          thumbnailUrl: imageUrl,
          basePrice: basePrice,
          mrp: mrp,
          discountPercent: discountPercent,
          unit: unit,
          stockQty: stockQty,
          lowStockThreshold: lowStockThreshold,
          clearOfferId: clearOfferId,
          offerId: offerId,
          isFeatured: isFeatured,
          isTrending: isTrending,
          isBestSeller: isBestSeller,
          isActive: isActive,
        );
      }
      state = const InventoryMutationState();
      _ref.invalidate(allProductsAdminProvider);
      return true;
    } catch (e) {
      state = InventoryMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    state = const InventoryMutationState(isSubmitting: true);
    try {
      await _ref.read(adminInventoryDataSourceProvider).deleteProduct(id);
      state = const InventoryMutationState();
      _ref.invalidate(allProductsAdminProvider);
      return true;
    } catch (e) {
      state = InventoryMutationState(error: e.toString());
      return false;
    }
  }
}

final inventoryMutationProvider =
    StateNotifierProvider.autoDispose<InventoryMutationNotifier, InventoryMutationState>((ref) {
  return InventoryMutationNotifier(ref);
});
