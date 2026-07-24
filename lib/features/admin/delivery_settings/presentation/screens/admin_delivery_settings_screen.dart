import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../domain/entities/delivery_settings_entity.dart';
import '../providers/delivery_settings_providers.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

class AdminDeliverySettingsScreen extends ConsumerStatefulWidget {
  const AdminDeliverySettingsScreen({super.key});

  @override
  ConsumerState<AdminDeliverySettingsScreen> createState() => _AdminDeliverySettingsScreenState();
}

class _AdminDeliverySettingsScreenState extends ConsumerState<AdminDeliverySettingsScreen> {
  final _addressController = TextEditingController();
  final _minOrderController = TextEditingController(text: '200');
  double? _lat;
  double? _lng;
  List<_SlabDraft> _slabs = [];
  bool _isLoadingLocation = false;
  bool _initialized = false;

  @override
  void dispose() {
    _addressController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  void _initFrom(DeliverySettingsEntity settings) {
    if (_initialized) return;
    _initialized = true;
    _addressController.text = settings.storeAddress;
    _minOrderController.text = settings.minimumOrderAmount.toStringAsFixed(0);
    _lat = settings.storeLatitude;
    _lng = settings.storeLongitude;
    _slabs = settings.slabs
        .map((s) => _SlabDraft(minKm: s.minKm, maxKm: s.maxKm, charge: s.charge))
        .toList();
    if (_slabs.isEmpty) {
      // Sensible starting point so admin isn't staring at a blank list —
      // matches the example ranges given when this was requested.
      _slabs = [
        _SlabDraft(minKm: 0, maxKm: 5, charge: 30),
        _SlabDraft(minKm: 5, maxKm: 10, charge: 50),
      ];
    }
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
        _lat = position.latitude;
        _lng = position.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store location captured.')));
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
    final settings = DeliverySettingsEntity(
      storeLatitude: _lat,
      storeLongitude: _lng,
      storeAddress: _addressController.text.trim(),
      minimumOrderAmount: double.tryParse(_minOrderController.text) ?? 200,
      slabs: _slabs
          .where((s) => s.minKmController.text.isNotEmpty && s.maxKmController.text.isNotEmpty && s.chargeController.text.isNotEmpty)
          .map((s) => DeliverySlabEntity(
                minKm: double.tryParse(s.minKmController.text) ?? 0,
                maxKm: double.tryParse(s.maxKmController.text) ?? 0,
                charge: double.tryParse(s.chargeController.text) ?? 0,
              ))
          .toList(),
    );

    final success = await ref.read(deliverySettingsMutationProvider.notifier).save(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Delivery settings saved.' : 'Could not save settings.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(deliverySettingsProvider);
    final mutation = ref.watch(deliverySettingsMutationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: const Text('Delivery Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings: $e')),
        data: (settings) {
          _initFrom(settings);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _Card(
                title: 'Store Location',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This is the fixed point delivery distance is measured from. Stand at the store when capturing it.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    if (_lat != null && _lng != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: _green, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}')),
                          ],
                        ),
                      )
                    else
                      const Text('No location captured yet.', style: TextStyle(color: _red)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                      onPressed: _isLoadingLocation ? null : _useCurrentLocation,
                      icon: _isLoadingLocation
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.my_location),
                      label: Text(_isLoadingLocation ? 'Getting location…' : 'Use My Current Location'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Store Address (for display only)'),
                    ),
                  ],
                ),
              ),
              _Card(
                title: 'Minimum Order for Delivery',
                child: TextField(
                  controller: _minOrderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Minimum amount'),
                ),
              ),
              _Card(
                title: 'Delivery Charges by Distance',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ranges shouldn\'t overlap or leave gaps you want covered — e.g. 0–5 km, then 5–10 km, and so on.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    ..._slabs.asMap().entries.map((entry) => _SlabRow(
                          draft: entry.value,
                          onRemove: () => setState(() => _slabs.removeAt(entry.key)),
                        )),
                    TextButton.icon(
                      onPressed: () => setState(() => _slabs.add(_SlabDraft(minKm: 0, maxKm: 0, charge: 0))),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Range'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: mutation.isSubmitting ? null : _save,
                child: mutation.isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Delivery Settings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlabDraft {
  final TextEditingController minKmController;
  final TextEditingController maxKmController;
  final TextEditingController chargeController;

  _SlabDraft({required double minKm, required double maxKm, required double charge})
      : minKmController = TextEditingController(text: minKm.toStringAsFixed(minKm % 1 == 0 ? 0 : 1)),
        maxKmController = TextEditingController(text: maxKm.toStringAsFixed(maxKm % 1 == 0 ? 0 : 1)),
        chargeController = TextEditingController(text: charge.toStringAsFixed(0));
}

class _SlabRow extends StatelessWidget {
  final _SlabDraft draft;
  final VoidCallback onRemove;
  const _SlabRow({required this.draft, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF6F8ED), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: draft.minKmController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'From (km)', isDense: true, filled: true, fillColor: Colors.white),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
                  Expanded(
                    child: TextField(
                      controller: draft.maxKmController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'To (km)', isDense: true, filled: true, fillColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.chargeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    labelText: 'Delivery Charge',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: _red),
                onPressed: onRemove,
                tooltip: 'Remove this range',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
