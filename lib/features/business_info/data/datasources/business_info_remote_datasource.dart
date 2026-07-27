import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/business_info_entity.dart';

class BusinessInfoRemoteDataSource {
  final FirebaseFirestore _firestore;
  BusinessInfoRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<BusinessInfoEntity> getBusinessInfo() async {
    final doc = await _firestore
        .collection(FirestorePaths.adminConfig)
        .doc(FirestorePaths.adminConfigBusinessInfo)
        .get();

    final data = doc.data();
    if (data == null) return const BusinessInfoEntity();

    final socialLinks = (data['socialLinks'] as Map<String, dynamic>?) ?? const {};
    final rawHours = (data['businessHours'] as List<dynamic>?) ?? const [];

    final businessHours = <BusinessHourEntity>[];
    for (final raw in rawHours) {
      if (raw is! Map) continue;
      businessHours.add(BusinessHourEntity(
        day: (raw['day'] as String?) ?? '',
        openTime: (raw['openTime'] as String?) ?? '',
        closeTime: (raw['closeTime'] as String?) ?? '',
      ));
    }

    return BusinessInfoEntity(
      aboutUsText: (data['aboutUsText'] as String?) ?? '',
      physicalAddress: data['physicalAddress'] as String?,
      contactPhone: data['contactPhone'] as String?,
      contactEmail: data['contactEmail'] as String?,
      instagram: socialLinks['instagram'] as String?,
      facebook: socialLinks['facebook'] as String?,
      whatsappBusinessNumber: socialLinks['whatsappBusinessNumber'] as String?,
      businessHours: businessHours,
    );
  }
}