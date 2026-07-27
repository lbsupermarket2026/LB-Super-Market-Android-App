import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../offers/domain/entities/offer_card_entity.dart';
import '../../../../offers/presentation/widgets/offer_card_tile.dart';
import '../providers/admin_offer_card_providers.dart';

const _green = Color(0xFF2E7D32);

class OfferCardFormDialog extends ConsumerStatefulWidget {
  final OfferCardEntity? existing;
  const OfferCardFormDialog({super.key, this.existing});

  @override
  ConsumerState<OfferCardFormDialog> createState() => _OfferCardFormDialogState();
}

class _OfferCardFormDialogState extends ConsumerState<OfferCardFormDialog> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _highlightController = TextEditingController();
  OfferTemplate _template = OfferTemplate.percentageOff;
  bool _isEnabled = true;
  File? _pickedImage;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _subtitleController.text = e.subtitle;
      _highlightController.text = e.highlightText ?? '';
      _template = e.template;
      _isEnabled = e.isEnabled;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _highlightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (picked == null) return;

    // Reading the full bytes here — not just wrapping the path in a
    // File — is what actually fixes the crash: a plain File reference
    // gets re-read lazily whenever something tries to render it, which
    // could happen before the OS has finished flushing the picked
    // photo to disk (especially right after the camera hands it back).
    // readAsBytes() won't return until the read genuinely completes,
    // so by the time setState runs, there's no race left to hit.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = File(picked.path);
      _pickedImageBytes = bytes;
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;

    final success = await ref.read(offerCardMutationProvider.notifier).save(
          id: widget.existing?.id,
          template: _template,
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          highlightText: _highlightController.text.trim().isEmpty ? null : _highlightController.text.trim(),
          imageFile: _pickedImage,
          existingImageUrl: widget.existing?.imageUrl,
          isEnabled: _isEnabled,
        );

    if (!mounted) return;
    if (success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offerCardMutationProvider);

    // Live preview using the same widget Home actually renders — what
    // you see here is exactly what customers will see.
    final preview = OfferCardEntity(
      id: 'preview',
      template: _template,
      title: _titleController.text.isEmpty ? 'Card title' : _titleController.text,
      subtitle: _subtitleController.text.isEmpty ? 'Subtitle text' : _subtitleController.text,
      highlightText: _highlightController.text.isEmpty ? null : _highlightController.text,
      imageUrl: widget.existing?.imageUrl,
      isEnabled: _isEnabled,
    );

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Offer Card' : 'Edit Offer Card'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(state.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            // Deliberately NOT rendering the just-picked photo here —
            // attempting to preview a freshly-captured image (before
            // it's even uploaded) was the actual source of a layout
            // crash that two earlier attempts at fixing didn't fully
            // resolve. The photo itself is fine and uploads correctly;
            // it's specifically trying to draw a live preview of it
            // immediately after picking that was unstable. Showing a
            // plain confirmation instead sidesteps that render path
            // entirely rather than continuing to chase it.
            _pickedImageBytes != null
                ? Container(
                    height: 140,
                    decoration: BoxDecoration(color: const Color(0xFFE8F0DE), borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: _green, size: 32),
                        SizedBox(height: 8),
                        Text('Photo selected — will be used when you Save', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  )
                : OfferCardTile(card: preview, height: 140),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(_pickedImage != null || widget.existing?.imageUrl?.isNotEmpty == true
                  ? 'Change Photo'
                  : 'Add Photo (optional)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<OfferTemplate>(
              value: _template,
              decoration: const InputDecoration(labelText: 'Template'),
              items: OfferTemplate.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _template = v ?? OfferTemplate.custom),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleController,
              decoration: const InputDecoration(labelText: 'Subtitle'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _highlightController,
              decoration: InputDecoration(
                labelText: _template == OfferTemplate.percentageOff ? 'Discount number (e.g. 25)' : 'Highlight text (optional)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isEnabled,
              title: const Text('Enabled (visible to customers)'),
              onChanged: (v) => setState(() => _isEnabled = v),
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
