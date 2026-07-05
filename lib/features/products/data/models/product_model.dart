import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product_entity.dart';

class ProductModel {
  final String id;
  final String name;
  final String? description;
  final String? brand;
  final String categoryId;
  final String? subCategoryId;
  final List<String> images;
  final String? thumbnailUrl;
  final double basePrice;
  final double? mrp;
  final double discountPercent;
  final double taxPercent;
  final String unit;
  final List<Map<String, dynamic>> variants;
  final int stockQty;
  final bool isFeatured;
  final bool isTrending;
  final bool isBestSeller;
  final bool isActive;
  final double ratingAvg;
  final int ratingCount;

  const ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.brand,
    required this.categoryId,
    this.subCategoryId,
    this.images = const [],
    this.thumbnailUrl,
    required this.basePrice,
    this.mrp,
    this.discountPercent = 0,
    this.taxPercent = 0,
    this.unit = '',
    this.variants = const [],
    this.stockQty = 0,
    this.isFeatured = false,
    this.isTrending = false,
    this.isBestSeller = false,
    this.isActive = true,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ProductModel(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      brand: data['brand'] as String?,
      categoryId: (data['categoryId'] as String?) ?? '',
      subCategoryId: data['subCategoryId'] as String?,
      images: (data['images'] as List<dynamic>?)?.cast<String>() ?? const [],
      thumbnailUrl: data['thumbnailUrl'] as String?,
      basePrice: (data['basePrice'] as num?)?.toDouble() ?? 0,
      mrp: (data['mrp'] as num?)?.toDouble(),
      discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
      taxPercent: (data['taxPercent'] as num?)?.toDouble() ?? 0,
      unit: (data['unit'] as String?) ?? '',
      variants: (data['variants'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [],
      stockQty: (data['stockQty'] as num?)?.toInt() ?? (data['stock'] as num?)?.toInt() ?? 0,
      isFeatured: (data['isFeatured'] as bool?) ?? false,
      isTrending: (data['isTrending'] as bool?) ?? false,
      isBestSeller: (data['isBestSeller'] as bool?) ?? false,
      isActive: (data['isActive'] as bool?) ?? true,
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }

  ProductEntity toEntity() => ProductEntity(
        id: id,
        name: name,
        description: description,
        brand: brand,
        categoryId: categoryId,
        subCategoryId: subCategoryId,
        images: images,
        thumbnailUrl: thumbnailUrl,
        basePrice: basePrice,
        mrp: mrp,
        discountPercent: discountPercent,
        taxPercent: taxPercent,
        unit: unit,
        variants: variants
            .map((v) => ProductVariantEntity(
                  variantId: (v['variantId'] as String?) ?? '',
                  label: (v['label'] as String?) ?? '',
                  priceDelta: (v['priceDelta'] as num?)?.toDouble() ?? 0,
                  stockQty: (v['stockQty'] as num?)?.toInt() ?? 0,
                  sku: v['sku'] as String?,
                ))
            .toList(),
        stockQty: stockQty,
        isFeatured: isFeatured,
        isTrending: isTrending,
        isBestSeller: isBestSeller,
        isActive: isActive,
        ratingAvg: ratingAvg,
        ratingCount: ratingCount,
      );
}
