import 'dart:io';
import '../../../../core/error/result.dart';
import '../entities/order_request_entity.dart';

abstract class OrderRequestRepository {
  Future<Result<String>> uploadListPhoto(String userId, File file);

  Future<Result<String>> createOrderRequest({
    required String userId,
    required OrderRequestType type,
    List<String> itemLines = const [],
    String? photoUrl,
    required String contactPhone,
    required FulfillmentMethod fulfillmentMethod,
    String? deliveryAddress,
  });

  Future<Result<List<OrderRequestEntity>>> getMyOrderRequests(String userId);
}
