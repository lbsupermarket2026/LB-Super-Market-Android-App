import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/category_entity.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? imageUrl;
  final String? iconUrl;
  final String? parentCategoryId;
  final int sortOrder;
  final bool isActive;
  final String? offerId;

  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.iconUrl,
    this.parentCategoryId,
    this.sortOrder = 0,
    this.isActive = true,
    this.offerId,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CategoryModel(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      iconUrl: data['iconUrl'] as String?,
      parentCategoryId: data['parentCategoryId'] as String?,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: (data['isActive'] as bool?) ?? true,
      offerId: data['offerId'] as String?,
    );
  }

  CategoryEntity toEntity() => CategoryEntity(
        id: id,
        name: name,
        imageUrl: imageUrl,
        iconUrl: iconUrl,
        parentCategoryId: parentCategoryId,
        sortOrder: sortOrder,
        isActive: isActive,
        offerId: offerId,
      );
}
