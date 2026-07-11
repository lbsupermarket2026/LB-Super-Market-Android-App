import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../../../../products/domain/entities/product_entity.dart';
import '../providers/admin_inventory_providers.dart';

const _green = Color(0xFF2E7D32);

class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductEntity? existing;
  final List<CategoryEntity> categories;
  const ProductFormScreen({super.key, this.existing, required this.categories});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _brandController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _discountController = TextEditingController();
  final _unitController = TextEditingController();
  final _stockController = TextEditingController();
  String? _categoryId;
  File? _pickedImage;
  bool _isFeatured = false;
  bool _isTrending = false;
  bool _isBestSeller = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameController.text = p.name;
      _descController.text = p.description ?? '';
      _brandController.text = p.brand ?? '';
      _priceController.text = p.basePrice.toStringAsFixed(2);
      _mrpController.text = p.mrp?.toStringAsFixed(2) ?? '';
      _discountController.text = p.discountPercent.toStringAsFixed(1);
      _unitController.text = p.unit;
      _stockController.text = p.stockQty.toString();
      _categoryId = p.categoryId;
      _isFeatured = p.isFeatured;
      _isTrending = p.isTrending;
      _isBestSeller = p.isBestSeller;
      _isActive = p.isActive;
    } else if (widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _discountController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category.')));
      return;
    }

    final success = await ref.read(inventoryMutationProvider.notifier).saveProduct(
          id: widget.existing?.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
          brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
          categoryId: _categoryId!,
          imageFile: _pickedImage,
          existingImageUrl: widget.existing?.thumbnailUrl,
          basePrice: double.tryParse(_priceController.text) ?? 0,
          mrp: _mrpController.text.trim().isEmpty ? null : double.tryParse(_mrpController.text),
          discountPercent: double.tryParse(_discountController.text) ?? 0,
          unit: _unitController.text.trim(),
          stockQty: int.tryParse(_stockController.text) ?? 0,
          isFeatured: _isFeatured,
          isTrending: _isTrending,
          isBestSeller: _isBestSeller,
          isActive: _isActive,
        );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product saved.')));
      Navigator.pop(context, true);
    } else {
      final error = ref.read(inventoryMutationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Could not save product.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryMutationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: Text(widget.existing == null ? 'Add Product' : 'Edit Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: _pickedImage != null
                      ? Image.file(_pickedImage!, fit: BoxFit.cover)
                      : widget.existing?.thumbnailUrl?.isNotEmpty == true
                          ? CachedNetworkImage(imageUrl: widget.existing!.thumbnailUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.black38),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              decoration: const InputDecoration(labelText: 'Brand (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Selling Price (₹)'),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a number' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _mrpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'MRP (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _discountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount %'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Unit (e.g. 1 kg)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock Quantity'),
              validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a whole number' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isFeatured,
              title: const Text('Featured (shows on Home)'),
              onChanged: (v) => setState(() => _isFeatured = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isTrending,
              title: const Text('Trending'),
              onChanged: (v) => setState(() => _isTrending = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isBestSeller,
              title: const Text('Best Seller'),
              onChanged: (v) => setState(() => _isBestSeller = v ?? false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: const Text('Active (visible to customers)'),
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: state.isSubmitting ? null : _submit,
              child: state.isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Product'),
            ),
          ],
        ),
      ),
    );
  }
}
