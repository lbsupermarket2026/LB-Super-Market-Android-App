import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final String? iconUrl;
  final String? parentCategoryId;
  final int sortOrder;
  final bool isActive;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.imageUrl,
    this.iconUrl,
    this.parentCategoryId,
    this.sortOrder = 0,
    this.isActive = true,
  });

  bool get isTopLevel => parentCategoryId == null;

  @override
  List<Object?> get props => [id, name, imageUrl, iconUrl, parentCategoryId, sortOrder, isActive];
}
