import 'package:equatable/equatable.dart';

class ProductVariantEntity extends Equatable {
  final String variantId;
  final String label;
  final double priceDelta;
  final int stockQty;
  final String? sku;

  const ProductVariantEntity({
    required this.variantId,
    required this.label,
    this.priceDelta = 0,
    this.stockQty = 0,
    this.sku,
  });

  @override
  List<Object?> get props => [variantId, label, priceDelta, stockQty, sku];
}

class ProductEntity extends Equatable {
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
  final List<ProductVariantEntity> variants;
  final int stockQty;
  final bool isFeatured;
  final bool isTrending;
  final bool isBestSeller;
  final bool isActive;
  final double ratingAvg;
  final int ratingCount;

  const ProductEntity({
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

  /// Effective selling price after discount — the single source of truth
  /// UI should use, rather than each screen recomputing this itself.
  double get displayPrice {
    if (discountPercent <= 0) return basePrice;
    return basePrice - (basePrice * discountPercent / 100);
  }

  bool get hasDiscount => discountPercent > 0;
  bool get isInStock => stockQty > 0;
  String get primaryImage => thumbnailUrl ?? (images.isNotEmpty ? images.first : '');

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        brand,
        categoryId,
        subCategoryId,
        images,
        thumbnailUrl,
        basePrice,
        mrp,
        discountPercent,
        taxPercent,
        unit,
        variants,
        stockQty,
        isFeatured,
        isTrending,
        isBestSeller,
        isActive,
        ratingAvg,
        ratingCount,
      ];
}
