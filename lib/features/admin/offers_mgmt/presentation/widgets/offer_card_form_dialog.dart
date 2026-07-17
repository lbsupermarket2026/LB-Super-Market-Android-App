import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;

    final success = await ref.read(offerCardMutationProvider.notifier).save(
          id: widget.existing?.id,
          template: _template,
          title: _titleController.text.trim(),
          subtitle: _subtitleController.text.trim(),
          highlightText: _highlightController.text.trim().isEmpty ? null : _highlightController.text.trim(),
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
            OfferCardTile(card: preview),
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
