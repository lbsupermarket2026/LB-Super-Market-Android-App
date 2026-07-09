import 'dart:io';
import '../../../../core/error/result.dart';
import '../../domain/entities/order_request_entity.dart';
import '../../domain/repositories/order_request_repository.dart';
import '../datasources/order_request_remote_datasource.dart';

class OrderRequestRepositoryImpl implements OrderRequestRepository {
  final OrderRequestRemoteDataSource _remote;
  const OrderRequestRepositoryImpl(this._remote);

  @override
  Future<Result<String>> uploadListPhoto(String userId, File file) {
    return guard(() => _remote.uploadListPhoto(userId, file));
  }

  @override
  Future<Result<String>> createOrderRequest({
    required String userId,
    required OrderRequestType type,
    List<String> itemLines = const [],
    String? photoUrl,
    required String contactPhone,
    required FulfillmentMethod fulfillmentMethod,
    String? deliveryAddress,
  }) {
    return guard(() => _remote.createOrderRequest(
          userId: userId,
          type: type,
          itemLines: itemLines,
          photoUrl: photoUrl,
          contactPhone: contactPhone,
          fulfillmentMethod: fulfillmentMethod,
          deliveryAddress: deliveryAddress,
        ));
  }

  @override
  Future<Result<List<OrderRequestEntity>>> getMyOrderRequests(String userId) {
    return guard(() => _remote.getMyOrderRequests(userId));
  }
}
