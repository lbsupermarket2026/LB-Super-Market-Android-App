class CartItemEntity {
  final String productId;
  final String name;
  final String unit;
  final String imageUrl;
  final double price; // snapshot of displayPrice (post-discount) at time of adding
  final int quantity;
  final String? categoryId; // snapshot, used to look up GST % at checkout
  // NEW: snapshot of the product's MRP at time of adding — previously
  // only the final discounted price survived into the cart, so the
  // original price and discount amount were unrecoverable by the
  // time a bill needed to show them. Null for products with no MRP
  // set (i.e. price == mrp, no discount to show).
  final double? mrp;

  const CartItemEntity({
    required this.productId,
    required this.name,
    required this.unit,
    required this.imageUrl,
    required this.price,
    required this.quantity,
    this.categoryId,
    this.mrp,
  });

  double get lineTotal => price * quantity;
  double get originalLineTotal => (mrp ?? price) * quantity;
  double get discountLineTotal => originalLineTotal - lineTotal;

  CartItemEntity copyWith({int? quantity}) => CartItemEntity(
        productId: productId,
        name: name,
        unit: unit,
        imageUrl: imageUrl,
        price: price,
        quantity: quantity ?? this.quantity,
        categoryId: categoryId,
        mrp: mrp,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unit': unit,
        'imageUrl': imageUrl,
        'price': price,
        'quantity': quantity,
        'categoryId': categoryId,
        'mrp': mrp,
      };

  factory CartItemEntity.fromJson(Map<String, dynamic> json) => CartItemEntity(
        productId: json['productId'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        categoryId: json['categoryId'] as String?,
        mrp: (json['mrp'] as num?)?.toDouble(),
      );
}
