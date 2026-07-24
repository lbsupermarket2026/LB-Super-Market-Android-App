class CartItemEntity {
  final String productId;
  final String name;
  final String unit;
  final String imageUrl;
  final double price; // snapshot of displayPrice at time of adding
  final int quantity;
  final String? categoryId; // snapshot, used to look up GST % at checkout

  const CartItemEntity({
    required this.productId,
    required this.name,
    required this.unit,
    required this.imageUrl,
    required this.price,
    required this.quantity,
    this.categoryId,
  });

  double get lineTotal => price * quantity;

  CartItemEntity copyWith({int? quantity}) => CartItemEntity(
        productId: productId,
        name: name,
        unit: unit,
        imageUrl: imageUrl,
        price: price,
        quantity: quantity ?? this.quantity,
        categoryId: categoryId,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unit': unit,
        'imageUrl': imageUrl,
        'price': price,
        'quantity': quantity,
        'categoryId': categoryId,
      };

  factory CartItemEntity.fromJson(Map<String, dynamic> json) => CartItemEntity(
        productId: json['productId'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        categoryId: json['categoryId'] as String?,
      );
}
