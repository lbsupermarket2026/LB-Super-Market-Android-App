import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../providers/admin_inventory_providers.dart';

const _green = Color(0xFF2E7D32);

class CategoryFormDialog extends ConsumerStatefulWidget {
  final CategoryEntity? existing;
  const CategoryFormDialog({super.key, this.existing});

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _nameController = TextEditingController();
  File? _pickedImage;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _isActive = widget.existing!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;

    final success = await ref.read(inventoryMutationProvider.notifier).saveCategory(
          id: widget.existing?.id,
          name: _nameController.text.trim(),
          imageFile: _pickedImage,
          existingImageUrl: widget.existing?.imageUrl,
          isActive: _isActive,
        );

    if (!mounted) return;
    if (success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryMutationProvider);

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Category' : 'Edit Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(state.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(48),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedImage != null
                    ? Image.file(_pickedImage!, fit: BoxFit.cover)
                    : widget.existing?.imageUrl?.isNotEmpty == true
                        ? CachedNetworkImage(imageUrl: widget.existing!.imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.add_a_photo_outlined, color: Colors.black38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            if (widget.existing != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                title: const Text('Active (visible to customers)'),
                onChanged: (v) => setState(() => _isActive = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
          onPressed: state.isSubmitting ? null : _submit,
          child: state.isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
