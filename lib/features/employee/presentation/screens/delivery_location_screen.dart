import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

const _green = Color(0xFF2E7D32);

/// Read-only view of a single order's delivery location, right inside
/// the app — the employee no longer has to leave to Google Maps just
/// to see roughly where they're headed. "Open in Google Maps" is still
/// offered as a button here for actual turn-by-turn navigation, which
/// this simple viewer isn't trying to replace.
class DeliveryLocationScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? customerAddress;
  final String? orderLabel;

  const DeliveryLocationScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.customerAddress,
    this.orderLabel,
  });

  Future<void> _openInGoogleMaps() async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    return Scaffold(
      appBar: AppBar(title: Text(orderLabel != null ? 'Delivery — $orderLabel' : 'Delivery Location')),
      body: Column(
        children: [
          if (customerAddress?.isNotEmpty == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: _green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(customerAddress!, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 16),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.lbsupermarket.com',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.location_pin, size: 48, color: Color(0xFFE53935)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: _openInGoogleMaps,
        icon: const Icon(Icons.directions_outlined),
        label: const Text('Open in Google Maps'),
      ),
    );
  }
}
