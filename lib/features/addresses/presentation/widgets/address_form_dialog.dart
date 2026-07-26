import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/widgets/location/location_picker_screen.dart';
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_latitude != null ? Icons.check_circle : Icons.my_location, size: 18),
                      label: Text(_isLoadingLocation
                          ? 'Locating…'
                          : (_latitude != null ? 'Located' : 'Use GPS'), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPickerScreen(initialLatitude: _latitude, initialLongitude: _longitude),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _latitude = result.latitude;
                            _longitude = result.longitude;
                          });
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Pinpoint on Map', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
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
