import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../../../../products/domain/entities/product_entity.dart';
import '../../../offers_mgmt/presentation/providers/admin_offer_card_providers.dart';
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
  final _thresholdController = TextEditingController(text: '5');
  String? _categoryId;
  String? _offerId;
  File? _pickedImage;
  Uint8List? _pickedImageBytes;
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
      _thresholdController.text = p.lowStockThreshold.toString();
      _categoryId = p.categoryId;
      _offerId = p.offerId;
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
    _thresholdController.dispose();
    super.dispose();
  }

  // Whichever field the admin is actively typing in drives the other
  // two — editing Selling Price recomputes Discount %, editing
  // Discount % recomputes Selling Price, and editing MRP recomputes
  // whichever of the other two currently has a value (preferring to
  // keep Discount % fixed, since that's usually the "policy" the admin
  // is setting, and let the actual price move with it).
  //
  // These only ever assign controller.text directly rather than
  // calling setState — TextEditingController already notifies its own
  // TextField on a text change, and since none of this touches other
  // state, there's nothing extra a full setState would accomplish here.
  void _recalculateFromPrice() {
    final mrp = double.tryParse(_mrpController.text);
    final price = double.tryParse(_priceController.text);
    if (mrp == null || mrp <= 0 || price == null) return;
    final discount = ((mrp - price) / mrp * 100).clamp(0, 100);
    _discountController.text = discount.toStringAsFixed(1);
  }

  void _recalculateFromDiscount() {
    final mrp = double.tryParse(_mrpController.text);
    final discount = double.tryParse(_discountController.text);
    if (mrp == null || mrp <= 0 || discount == null) return;
    final price = mrp * (1 - discount.clamp(0, 100) / 100);
    _priceController.text = price.toStringAsFixed(2);
  }

  void _recalculateFromMrp() {
    final mrp = double.tryParse(_mrpController.text);
    if (mrp == null || mrp <= 0) return;

    final discount = double.tryParse(_discountController.text);
    if (discount != null) {
      final price = mrp * (1 - discount.clamp(0, 100) / 100);
      _priceController.text = price.toStringAsFixed(2);
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price != null) {
      final newDiscount = ((mrp - price) / mrp * 100).clamp(0, 100);
      _discountController.text = newDiscount.toStringAsFixed(1);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (picked == null) return;

    // Reading full bytes rather than just wrapping the path in a File —
    // this is what actually avoids the isFinite/layout crash, since a
    // bare File reference gets re-read lazily whenever rendered, which
    // can race with the OS still flushing the picked photo to disk.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = File(picked.path);
      _pickedImageBytes = bytes;
    });
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
          offerId: _offerId,
          clearOfferId: _offerId == null,
          imageFile: _pickedImage,
          existingImageUrl: widget.existing?.thumbnailUrl,
          basePrice: double.tryParse(_priceController.text) ?? 0,
          mrp: _mrpController.text.trim().isEmpty ? null : double.tryParse(_mrpController.text),
          discountPercent: double.tryParse(_discountController.text) ?? 0,
          unit: _unitController.text.trim(),
          stockQty: int.tryParse(_stockController.text) ?? 0,
          lowStockThreshold: int.tryParse(_thresholdController.text) ?? 5,
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

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
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
                  child: _pickedImageBytes != null
                      ? const Center(
                          child: Icon(Icons.check_circle, color: _green, size: 40),
                        )
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
            Consumer(
              builder: (context, ref, _) {
                final offersAsync = ref.watch(allOfferCardsAdminProvider);
                return offersAsync.when(
                  data: (offers) => DropdownButtonFormField<String?>(
                    value: _offerId,
                    decoration: const InputDecoration(labelText: 'Part of an Offer (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None')),
                      ...offers.map((o) => DropdownMenuItem<String?>(value: o.id, child: Text(o.title))),
                    ],
                    onChanged: (v) => setState(() => _offerId = v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
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
                    onChanged: (_) => _recalculateFromPrice(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _mrpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'MRP (optional)'),
                    onChanged: (_) => _recalculateFromMrp(),
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
                    onChanged: (_) => _recalculateFromDiscount(),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock Quantity'),
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a whole number' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Low Stock Alert At'),
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a whole number' : null,
                  ),
                ),
              ],
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
