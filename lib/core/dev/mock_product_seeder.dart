import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/categories/domain/entities/category_entity.dart';
import '../../features/categories/presentation/providers/category_providers.dart';

/// Debug-only helper to populate a handful of realistic mock products
/// under each existing category, so the app has something to browse
/// during regular setup/testing. Never referenced from any production
/// screen flow — only wired behind a kDebugMode-gated button.
///
/// Uses a small name/unit/price lookup for common grocery category names,
/// falling back to generic placeholder items for anything it doesn't
/// recognize, so this stays useful even as more categories get added.
class MockProductSeeder {
  static const Map<String, List<(String name, String unit, double price)>> _catalog = {
    'vegetables': [
      ('Tomato', '1 kg', 40),
      ('Onion', '1 kg', 35),
      ('Potato', '1 kg', 30),
      ('Carrot', '500 g', 25),
    ],
    'fruits': [
      ('Banana', '1 dozen', 50),
      ('Apple', '1 kg', 150),
      ('Mango', '1 kg', 120),
      ('Orange', '1 kg', 90),
    ],
    'dairy': [
      ('Milk', '500 ml', 30),
      ('Curd', '400 g', 35),
      ('Paneer', '200 g', 80),
      ('Butter', '100 g', 55),
    ],
    'snacks': [
      ('Potato Chips', '150 g', 20),
      ('Marie Biscuits', '200 g', 25),
      ('Mixture Namkeen', '200 g', 45),
      ('Chocolate Cookies', '150 g', 40),
    ],
    'beverages': [
      ('Cola', '750 ml', 40),
      ('Orange Juice', '1 L', 99),
      ('Packaged Water', '1 L', 20),
      ('Green Tea (25 bags)', '1 pack', 150),
    ],
  };

  static List<(String, String, double)> _itemsFor(String categoryName) {
    final key = categoryName.trim().toLowerCase();
    if (_catalog.containsKey(key)) return _catalog[key]!;
    // Generic fallback for any category name not in the lookup above.
    return List.generate(4, (i) => ('$categoryName Item ${i + 1}', '1 unit', 30.0 + (i * 15)));
  }

  /// Seeds ~4 products per top-level category. Returns how many products
  /// were written, so the calling UI can show a confirmation.
  static Future<int> seedAll(WidgetRef ref) async {
    final categories = await ref.read(topLevelCategoriesProvider.future);
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final productsRef = firestore.collection('products');

    int count = 0;
    for (final CategoryEntity category in categories) {
      final items = _itemsFor(category.name);
      for (var i = 0; i < items.length; i++) {
        final (name, unit, price) = items[i];
        // Every other item gets a discount so the "% OFF" badge and
        // strikethrough MRP have something to show during testing too.
        final hasDiscount = i.isEven;
        final mrp = hasDiscount ? (price * 1.2).roundToDouble() : null;

        final docRef = productsRef.doc();
        batch.set(docRef, {
          'name': name,
          'description': 'Sample $name for testing.',
          'brand': null,
          'categoryId': category.id,
          'subCategoryId': null,
          'images': <String>[],
          'thumbnailUrl': null,
          'basePrice': price,
          'mrp': mrp,
          'discountPercent': hasDiscount ? 20.0 : 0.0,
          'taxPercent': 0.0,
          'unit': unit,
          'variants': <Map<String, dynamic>>[],
          'stockQty': 50,
          'isFeatured': i == 0,
          'isTrending': i == 1,
          'isBestSeller': i == 2,
          'isActive': true,
          'ratingAvg': 0.0,
          'ratingCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
    }

    await batch.commit();
    return count;
  }
}
