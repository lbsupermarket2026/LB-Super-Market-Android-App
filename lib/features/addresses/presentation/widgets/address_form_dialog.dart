import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import '../../domain/entities/address_entity.dart';
import '../providers/address_providers.dart';

// Simple unique-enough ID for locally stored addresses — avoids pulling
// in the uuid package just for this, since it's not already a direct
// dependency in pubspec.yaml.
String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

class AddressFormDialog extends ConsumerStatefulWidget {
  final AddressEntity? existing;
  const AddressFormDialog({super.key, this.existing});

  @override
  ConsumerState<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;
  late final TextEditingController _phone;
  bool _isDefault = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? 'Home');
    _line1 = TextEditingController(text: e?.line1 ?? '');
    _line2 = TextEditingController(text: e?.line2 ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _state = TextEditingController(text: e?.state ?? '');
    _pincode = TextEditingController(text: e?.pincode ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _isDefault = e?.isDefault ?? false;
    _latitude = e?.latitude;
    _longitude = e?.longitude;
  }

  @override
  void dispose() {
    _label.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Geocode the typed address into coordinates — used for both the
    // "View on Map" link and for calculating distance-based delivery
    // charges at checkout. Best-effort: if it fails (unusual/informal
    // address, no network), the address still saves fine, it just won't
    // have a map link or count toward delivery-distance calculation
    // until edited again with a more specific address.
    double? lat = _latitude;
    double? lng = _longitude;
    try {
      final fullAddress = '${_line1.text} ${_line2.text}, ${_city.text}, ${_state.text} ${_pincode.text}';
      final locations = await locationFromAddress(fullAddress);
      if (locations.isNotEmpty) {
        lat = locations.first.latitude;
        lng = locations.first.longitude;
      }
    } catch (_) {
      // Keep whatever coordinates (if any) were already on this address.
    }

    final address = AddressEntity(
      id: widget.existing?.id ?? _generateId(),
      label: _label.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
      phone: _phone.text.trim(),
      isDefault: _isDefault,
      latitude: lat,
      longitude: lng,
    );

    await ref.read(addressListProvider.notifier).addOrUpdate(address);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Address' : 'Edit Address'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: ['Home', 'Work', 'Other'].contains(_label.text) ? _label.text : 'Other',
                decoration: const InputDecoration(labelText: 'Label'),
                items: const [
                  DropdownMenuItem(value: 'Home', child: Text('Home')),
                  DropdownMenuItem(value: 'Work', child: Text('Work')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _label.text = v ?? 'Other'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _line1,
                decoration: const InputDecoration(labelText: 'Address Line 1'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _line2,
                decoration: const InputDecoration(labelText: 'Address Line 2 (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _state,
                decoration: const InputDecoration(labelText: 'State'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pincode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pincode'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                title: const Text('Set as default address'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
