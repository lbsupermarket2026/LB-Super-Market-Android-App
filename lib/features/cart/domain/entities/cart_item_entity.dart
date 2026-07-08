class CartItemEntity {
  final String productId;
  final String name;
  final String unit;
  final String imageUrl;
  final double price; // snapshot of displayPrice at time of adding
  final int quantity;

  const CartItemEntity({
    required this.productId,
    required this.name,
    required this.unit,
    required this.imageUrl,
    required this.price,
    required this.quantity,
  });

  double get lineTotal => price * quantity;

  CartItemEntity copyWith({int? quantity}) => CartItemEntity(
        productId: productId,
        name: name,
        unit: unit,
        imageUrl: imageUrl,
        price: price,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unit': unit,
        'imageUrl': imageUrl,
        'price': price,
        'quantity': quantity,
      };

  factory CartItemEntity.fromJson(Map<String, dynamic> json) => CartItemEntity(
        productId: json['productId'] as String,
        name: json['name'] as String,
        unit: json['unit'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
      );
}
