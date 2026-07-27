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

  // Falls back to the old per-distance field only if the flat one
    // was never saved yet — lets an existing settings document keep
    // working with a sensible number instead of suddenly reading 0.
    double flatCharge = 30;
    if (data['flatDeliveryCharge'] is num) {
      flatCharge = (data['flatDeliveryCharge'] as num).toDouble();
    } else if (data['slabs'] is List && (data['slabs'] as List).isNotEmpty) {
      final firstSlab = (data['slabs'] as List).first;
      if (firstSlab is Map && firstSlab['charge'] is num) {
        flatCharge = (firstSlab['charge'] as num).toDouble();
      }
    }

    return DeliverySettingsEntity(
      storeLatitude: (data['storeLatitude'] as num?)?.toDouble(),
      storeLongitude: (data['storeLongitude'] as num?)?.toDouble(),
      storeAddress: (data['storeAddress'] as String?) ?? '',
      minimumOrderAmount: (data['minimumOrderAmount'] as num?)?.toDouble() ?? 200,
      flatDeliveryCharge: flatCharge,
      onlinePaymentsEnabled: (data['onlinePaymentsEnabled'] as bool?) ?? true,
      gstNumber: (data['gstNumber'] as String?) ?? '',
    );

  }

  Future<void> saveSettings(DeliverySettingsEntity settings) async {
    await _doc.set({
      'storeLatitude': settings.storeLatitude,
      'storeLongitude': settings.storeLongitude,
      'storeAddress': settings.storeAddress,
      'minimumOrderAmount': settings.minimumOrderAmount,
      'flatDeliveryCharge': settings.flatDeliveryCharge,
      'onlinePaymentsEnabled': settings.onlinePaymentsEnabled,
      'gstNumber': settings.gstNumber,
    }, SetOptions(merge: true));
  }
}
