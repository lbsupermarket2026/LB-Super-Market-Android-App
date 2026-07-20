import 'package:equatable/equatable.dart';

/// Deliberately linear — no "returned"/"refunded" branch yet since
/// there's no returns flow built. Add states here if that gets built.
enum OrderStatus { placed, confirmed, preparing, outForDelivery, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Step index for the tracking stepper — cancelled orders don't map
  /// onto the linear progression, so they're handled separately in the UI.
  int get stepIndex => index.clamp(0, 4);

  bool get isActive => this != OrderStatus.delivered && this != OrderStatus.cancelled;

  bool get canBeCancelled => this == OrderStatus.placed;

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OrderStatus.placed,
    );
  }
}

enum PaymentMethod { upi, cod, cardSwipe }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.cod:
        return 'Cash on Delivery';
      case PaymentMethod.cardSwipe:
        return 'Card (Swipe on Delivery)';
    }
  }

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere((m) => m.name == value, orElse: () => PaymentMethod.cod);
  }
}

class OrderItemEntity extends Equatable {
  final String productId;
  final String name;
  final String unit;
  final String imageUrl;
  final double price;
  final int quantity;

  const OrderItemEntity({
    required this.productId,
    required this.name,
    required this.unit,
    required this.imageUrl,
    required this.price,
    required this.quantity,
  });

  double get lineTotal => price * quantity;

  @override
  List<Object?> get props => [productId, name, unit, imageUrl, price, quantity];
}

class OrderEntity extends Equatable {
  final String id;
  final String userId;
  final List<OrderItemEntity> items;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String deliveryAddress;
  final String? customerPhone;
  final PaymentMethod paymentMethod;
  final String? razorpayPaymentId;
  final String? refundStatus; // null | 'processing' | 'processed' | 'failed'
  final String? refundId;
  final String? refundError;
  final String? assignedEmployeeUid;
  final String? deliveryPersonName;
  final String? deliveryPersonPhone;
  final double? rating;
  final String? ratingComment;

  const OrderEntity({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.deliveryAddress,
    this.customerPhone,
    this.paymentMethod = PaymentMethod.cod,
    this.razorpayPaymentId,
    this.refundStatus,
    this.refundId,
    this.refundError,
    this.assignedEmployeeUid,
    this.deliveryPersonName,
    this.deliveryPersonPhone,
    this.rating,
    this.ratingComment,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isRated => rating != null;
  bool get canBeRated => status == OrderStatus.delivered && !isRated;
  bool get canCallDelivery => deliveryPersonPhone?.isNotEmpty == true && status == OrderStatus.outForDelivery;

  @override
  List<Object?> get props => [
        id,
        userId,
        items,
        totalAmount,
        status,
        createdAt,
        deliveryAddress,
        customerPhone,
        paymentMethod,
        razorpayPaymentId,
        refundStatus,
        refundId,
        refundError,
        assignedEmployeeUid,
        deliveryPersonName,
        deliveryPersonPhone,
        rating,
        ratingComment,
      ];
}
