import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/location/location_picker_screen.dart';
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
  final _gstController = TextEditingController();
  final _minOrderController = TextEditingController(text: '200');
  final _flatChargeController = TextEditingController(text: '30');
  bool _onlinePaymentsEnabled = true;
  double? _lat;
  double? _lng;
  bool _isLoadingLocation = false;
  bool _initialized = false;

  @override
  void dispose() {
    _addressController.dispose();
    _gstController.dispose();
    _minOrderController.dispose();
    _flatChargeController.dispose();
    super.dispose();
  }

  void _initFrom(DeliverySettingsEntity settings) {
    if (_initialized) return;
    _initialized = true;
    _addressController.text = settings.storeAddress;
    _gstController.text = settings.gstNumber;
    _minOrderController.text = settings.minimumOrderAmount.toStringAsFixed(0);
    _flatChargeController.text = settings.flatDeliveryCharge.toStringAsFixed(0);
    _onlinePaymentsEnabled = settings.onlinePaymentsEnabled;
    _lat = settings.storeLatitude;
    _lng = settings.storeLongitude;
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
      flatDeliveryCharge: double.tryParse(_flatChargeController.text) ?? 30,
      onlinePaymentsEnabled: _onlinePaymentsEnabled,
      gstNumber: _gstController.text.trim(),
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
                      'Used for the "view on map" links employees see for each delivery.',
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPickerScreen(initialLatitude: _lat, initialLongitude: _lng),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _lat = result.latitude;
                            _lng = result.longitude;
                          });
                        }
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Fine-tune on Map'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Store Address (for display only)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _gstController,
                      decoration: const InputDecoration(labelText: 'GST Number (shown on customer bills)'),
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
                title: 'Delivery Charge',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'One flat charge for every delivery — no distance calculation. As long as a customer\'s address is confirmed (a saved address, or a new one pinpointed on the map), this is what they\'re charged.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _flatChargeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Delivery charge'),
                    ),
                  ],
                ),
              ),
              _Card(
                title: 'Payment Methods',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onlinePaymentsEnabled,
                  title: const Text('Accept online payments (UPI)'),
                  subtitle: Text(
                    _onlinePaymentsEnabled
                        ? 'Customers can pay via UPI at checkout, alongside Cash and Card Swipe.'
                        : 'UPI is hidden at checkout — customers can only choose Cash or Card Swipe.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => setState(() => _onlinePaymentsEnabled = v),
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
