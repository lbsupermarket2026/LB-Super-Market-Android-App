import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../../../../products/domain/entities/product_entity.dart';
import '../providers/admin_inventory_providers.dart';
import '../widgets/category_form_dialog.dart';
import 'product_form_screen.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

class AdminInventoryScreen extends StatelessWidget {
  const AdminInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8ED),
        appBar: AppBar(
          title: const Text('Inventory'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Products'), Tab(text: 'Categories')],
          ),
        ),
        body: const TabBarView(children: [_ProductsTab(), _CategoriesTab()]),
      ),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(allProductsAdminProvider);
    final categoriesAsync = ref.watch(allCategoriesAdminProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () {
          final categories = categoriesAsync.valueOrNull ?? [];
          if (categories.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add a category first before adding products.')),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductFormScreen(categories: categories)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products: $e')),
        data: (products) {
          if (products.isEmpty) return const Center(child: Text('No products yet. Tap "Add Product" to create one.'));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allProductsAdminProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: product.primaryImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: product.primaryImage,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.image_outlined, size: 18)),
                              )
                            : Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.image_outlined, size: 18)),
                      ),
                    ),
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('₹${product.basePrice.toStringAsFixed(0)} • Stock: ${product.stockQty}${product.isActive ? '' : ' • Inactive'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: _red),
                      onPressed: () => _confirmDelete(context, ref, product),
                    ),
                    onTap: () {
                      final categories = categoriesAsync.valueOrNull ?? [];
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductFormScreen(existing: product, categories: categories)),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ProductEntity product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('This permanently removes "${product.name}" from your catalogue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(inventoryMutationProvider.notifier).deleteProduct(product.id);
    }
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesAdminProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => showDialog(context: context, builder: (_) => const CategoryFormDialog()),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load categories: $e')),
        data: (categories) {
          if (categories.isEmpty) return const Center(child: Text('No categories yet.'));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allCategoriesAdminProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF3F3F3),
                      backgroundImage: category.imageUrl?.isNotEmpty == true ? CachedNetworkImageProvider(category.imageUrl!) : null,
                      child: category.imageUrl?.isNotEmpty == true ? null : const Icon(Icons.category_outlined, color: Colors.black38),
                    ),
                    title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(category.isActive ? 'Active' : 'Inactive'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: _red),
                      onPressed: () => _confirmDelete(context, ref, category),
                    ),
                    onTap: () => showDialog(context: context, builder: (_) => CategoryFormDialog(existing: category)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, CategoryEntity category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('This removes "${category.name}". Products already in it will keep this category ID but it won\'t show up anywhere.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(inventoryMutationProvider.notifier).deleteCategory(category.id);
    }
  }
}
