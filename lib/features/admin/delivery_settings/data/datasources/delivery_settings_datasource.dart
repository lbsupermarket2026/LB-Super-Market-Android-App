import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/delivery_settings_entity.dart';

class DeliverySettingsDataSource {
  final FirebaseFirestore _firestore;
  DeliverySettingsDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(FirestorePaths.adminConfig)
      .doc(FirestorePaths.adminConfigDeliverySettings);

  Future<DeliverySettingsEntity> getSettings() async {
    final snapshot = await _doc.get();
    final data = snapshot.data();
    if (data == null) return const DeliverySettingsEntity();

    final rawSlabs = (data['slabs'] as List<dynamic>?) ?? const [];
    return DeliverySettingsEntity(
      storeLatitude: (data['storeLatitude'] as num?)?.toDouble(),
      storeLongitude: (data['storeLongitude'] as num?)?.toDouble(),
      storeAddress: (data['storeAddress'] as String?) ?? '',
      minimumOrderAmount: (data['minimumOrderAmount'] as num?)?.toDouble() ?? 200,
      onlinePaymentsEnabled: (data['onlinePaymentsEnabled'] as bool?) ?? true,
      slabs: rawSlabs
          .cast<Map<String, dynamic>>()
          .map((s) => DeliverySlabEntity(
                minKm: (s['minKm'] as num).toDouble(),
                maxKm: (s['maxKm'] as num).toDouble(),
                charge: (s['charge'] as num).toDouble(),
              ))
          .toList(),
    );
  }

  Future<void> saveSettings(DeliverySettingsEntity settings) async {
    await _doc.set({
      'storeLatitude': settings.storeLatitude,
      'storeLongitude': settings.storeLongitude,
      'storeAddress': settings.storeAddress,
      'minimumOrderAmount': settings.minimumOrderAmount,
      'onlinePaymentsEnabled': settings.onlinePaymentsEnabled,
      'slabs': settings.slabs
          .map((s) => {'minKm': s.minKm, 'maxKm': s.maxKm, 'charge': s.charge})
          .toList(),
    });
  }
}
