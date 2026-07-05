import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/banner_entity.dart';

class HomeRemoteDataSource {
  final FirebaseFirestore _firestore;
  HomeRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<BannerEntity>> getHomeBanners() async {
    final doc = await _firestore
        .collection(FirestorePaths.adminConfig)
        .doc(FirestorePaths.adminConfigBannerHome)
        .get();

    final data = doc.data();
    if (data == null) return const [];

    final rawBanners = (data['banners'] as List<dynamic>?) ?? const [];
    return rawBanners
        .cast<Map<String, dynamic>>()
        .map((b) => BannerEntity(
              imageUrl: (b['imageUrl'] as String?) ?? '',
              title: b['title'] as String?,
              deepLink: b['deepLink'] as String?,
            ))
        .where((b) => b.imageUrl.isNotEmpty)
        .toList();
  }
}
