import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Full-screen interactive map for pinpointing an exact location — GPS
/// alone can be off by tens of meters (worse indoors), so this lets
/// whoever's picking a location pan/zoom the map until the FIXED
/// center pin sits exactly where they mean, then confirm. Uses
/// OpenStreetMap tiles rather than Google Maps specifically so this
/// works with no API key or billing account setup on your end.
class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerScreen({super.key, this.initialLatitude, this.initialLongitude});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Falls back to central India if nothing was captured yet — better
    // than defaulting to (0,0), which is out in the ocean off Africa
    // and unhelpful as a starting point to pan away from.
    _center = LatLng(widget.initialLatitude ?? 20.5937, widget.initialLongitude ?? 78.9629);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinpoint Location'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _center),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) setState(() => _center = position.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lbsupermarket.com',
              ),
            ],
          ),
          // Fixed in the exact center of the screen, not tied to the
          // map's coordinate system — the map moves underneath it, so
          // wherever this pin visually sits IS the selected location.
          const Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(Icons.location_pin, size: 48, color: Color(0xFFE53935)),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pan the map so the pin sits exactly on the spot, then tap Confirm.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
