import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/firestore_paths.dart';

/// Dev-only utility to populate a handful of mock products under whatever
/// categories already exist in Firestore, so the app has something to
/// browse/search/order during setup. Safe to run more than once — it
/// only ever adds products, never touches categories or deletes anything.
/// Delete this whole feature folder once real catalogue data is in.
class SeedProductsScreen extends StatefulWidget {
  const SeedProductsScreen({super.key});

  @override
  State<SeedProductsScreen> createState() => _SeedProductsScreenState();
}

// name, unit, basePrice, mrp (mrp > basePrice implies a discount badge)
const _mockCatalog = <String, List<(String, String, double, double)>>{
  'vegetable': [
    ('Tomato', '1 kg', 30, 40),
    ('Onion', '1 kg', 35, 40),
    ('Potato', '1 kg', 25, 30),
    ('Carrot', '500 g', 20, 25),
    ('Spinach', '250 g', 15, 15),
  ],
  'fruit': [
    ('Banana', '1 dozen', 50, 60),
    ('Apple', '1 kg', 150, 180),
    ('Mango', '1 kg', 90, 110),
    ('Orange', '1 kg', 70, 80),
    ('Grapes', '500 g', 45, 50),
  ],
  'dairy': [
    ('Milk', '1 L', 32, 32),
    ('Curd', '400 g', 28, 30),
    ('Paneer', '200 g', 80, 90),
    ('Butter', '100 g', 55, 60),
    ('Cheese Slices', '10 pcs', 110, 120),
  ],
  'snack': [
    ('Potato Chips', '90 g', 20, 20),
    ('Marie Biscuits', '250 g', 30, 35),
    ('Mixture Namkeen', '200 g', 45, 50),
    ('Popcorn', '150 g', 35, 40),
    ('Chocolate Bar', '50 g', 40, 45),
  ],
  'beverage': [
    ('Cola', '750 ml', 40, 45),
    ('Lemon Soda', '750 ml', 38, 40),
    ('Mixed Fruit Juice', '1 L', 99, 120),
    ('Packaged Water', '1 L', 20, 20),
    ('Tea Powder', '250 g', 85, 95),
  ],
};

const _fallbackItems = [
  ('Sample Item 1', '1 unit', 49.0, 49.0),
  ('Sample Item 2', '1 unit', 79.0, 89.0),
  ('Sample Item 3', '1 unit', 129.0, 129.0),
];

class _SeedProductsScreenState extends State<SeedProductsScreen> {
  bool _isRunning = false;
  String _log = '';

  Future<void> _run() async {
    setState(() {
      _isRunning = true;
      _log = 'Fetching categories...\n';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final categoriesSnapshot = await firestore.collection(FirestorePaths.categories).get();

      if (categoriesSnapshot.docs.isEmpty) {
        setState(() => _log += 'No categories found — create categories first.\n');
        return;
      }

      final batch = firestore.batch();
      final productsRef = firestore.collection(FirestorePaths.products);
      var count = 0;

      for (final categoryDoc in categoriesSnapshot.docs) {
        final categoryName = (categoryDoc.data()['name'] as String? ?? '').toLowerCase();
        final matchKey = _mockCatalog.keys.firstWhere(
          (key) => categoryName.contains(key),
          orElse: () => '',
        );
        final items = matchKey.isNotEmpty ? _mockCatalog[matchKey]! : _fallbackItems;

        for (final (name, unit, basePrice, mrp) in items) {
          final docRef = productsRef.doc();
          final discountPercent = mrp > basePrice ? ((mrp - basePrice) / mrp * 100) : 0.0;
          batch.set(docRef, {
            'name': name,
            'description': '$name — sample product for testing.',
            'brand': null,
            'categoryId': categoryDoc.id,
            'subCategoryId': null,
            'images': <String>[],
            // No external placeholder image URL — depending on a
            // third-party image host (placehold.co) for mock data risked
            // showing broken-image icons on networks that block/can't
            // reach it. The app's own product cards already show a clean
            // grey fallback icon when there's no image, which is more
            // reliable than betting on an outside service.
            'thumbnailUrl': null,
            'basePrice': basePrice,
            'mrp': mrp,
            'discountPercent': discountPercent,
            'taxPercent': 0,
            'unit': unit,
            'variants': <Map<String, dynamic>>[],
            'stockQty': 50,
            'isFeatured': false,
            'isTrending': false,
            'isBestSeller': false,
            'isActive': true,
            'ratingAvg': 0,
            'ratingCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
          count++;
        }
        setState(() => _log += 'Queued ${items.length} items for "${categoryDoc.data()['name']}"\n');
      }

      await batch.commit();
      setState(() => _log += '\nDone — added $count mock products.\n');
    } catch (e) {
      setState(() => _log += '\nError: $e\n');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Sample Products (Dev)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adds ~5 mock products to each existing category, matched by keyword '
              '(vegetable/fruit/dairy/snack/beverage) or generic sample items otherwise. '
              'Safe to run more than once.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isRunning ? null : _run,
              child: _isRunning
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Seed Mock Products'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_log, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
