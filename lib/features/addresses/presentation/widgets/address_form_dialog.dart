import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/address_entity.dart';
import '../providers/address_providers.dart';
import '../../../../core/extensions/string_case_extensions.dart';

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
  bool _isLoadingLocation = false;
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

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
          throw Exception('Location permission was denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is permanently denied — enable it in phone Settings.');
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Turn on Location/GPS on this phone first.');

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Best-effort reverse geocode to prefill the text fields too, so
      // the customer doesn't have to type the address by hand after
      // capturing their location — they can still edit anything it gets
      // wrong before saving.
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() {
            if (_line1.text.trim().isEmpty) {
              _line1.text = [p.street, p.subLocality].where((s) => s?.isNotEmpty == true).join(', ');
            }
            if (_city.text.trim().isEmpty) _city.text = p.locality ?? '';
            if (_state.text.trim().isEmpty) _state.text = p.administrativeArea ?? '';
            if (_pincode.text.trim().isEmpty) _pincode.text = p.postalCode ?? '';
          });
        }
      } catch (_) {
        // Coordinates are captured either way — the address fields just
        // stay whatever the customer already typed if reverse geocoding
        // doesn't resolve to anything.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location captured.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Only geocodes the typed address as a FALLBACK when there's no
    // manual pinpoint at all — a manual pin is inherently more
    // accurate than geocoding informal address text (that's the whole
    // reason "Pinpoint on Map" exists), so it must never be silently
    // overwritten by a geocoding result once the user has set one.
    double? lat = _latitude;
    double? lng = _longitude;
    if (lat == null || lng == null) {
      try {
        final fullAddress = '${_line1.text} ${_line2.text}, ${_city.text}, ${_state.text} ${_pincode.text}';
        final locations = await locationFromAddress(fullAddress);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        }
      } catch (_) {
        // No coordinates at all yet — address still saves fine, just
        // won't have a map link or count toward delivery calculation
        // until pinpointed or edited with a more specific address.
      }
    }

    final address = AddressEntity(
      id: widget.existing?.id ?? _generateId(),
      label: _label.text.trim().toTitleCase(),
      line1: _line1.text.trim().toTitleCase(),
      line2: _line2.text.trim().toTitleCase(),
      city: _city.text.trim().toTitleCase(),
      state: _state.text.trim().toTitleCase(),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                  icon: _isLoadingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_latitude != null ? Icons.check_circle : Icons.my_location, size: 18),
                  label: Text(_isLoadingLocation
                      ? 'Locating…'
                      : (_latitude != null ? 'Located' : 'Fetch My Location')),
                ),
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
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required — needed so delivery can reach you' : null,
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
