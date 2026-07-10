import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/order_request_remote_datasource.dart';
import '../../data/repositories_impl/order_request_repository_impl.dart';
import '../../domain/entities/order_request_entity.dart';
import '../../domain/repositories/order_request_repository.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

final orderRequestRemoteDataSourceProvider = Provider<OrderRequestRemoteDataSource>((ref) {
  return OrderRequestRemoteDataSource();
});

final orderRequestRepositoryProvider = Provider<OrderRequestRepository>((ref) {
  return OrderRequestRepositoryImpl(ref.watch(orderRequestRemoteDataSourceProvider));
});

final myOrderRequestsProvider = FutureProvider.autoDispose<List<OrderRequestEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final result = await ref.watch(orderRequestRepositoryProvider).getMyOrderRequests(user.uid);
  return result.match((failure) => throw failure, (requests) => requests);
});

final orderByIdInRequestsProvider = Provider.family<OrderRequestEntity?, String>((ref, requestId) {
  final requests = ref.watch(myOrderRequestsProvider).valueOrNull ?? [];
  try {
    return requests.firstWhere((r) => r.id == requestId);
  } catch (_) {
    return null;
  }
});

class OrderRequestSubmission {
  final bool isSubmitting;
  final String? error;
  const OrderRequestSubmission({this.isSubmitting = false, this.error});
}

class OrderRequestSubmitter extends StateNotifier<OrderRequestSubmission> {
  final Ref _ref;
  OrderRequestSubmitter(this._ref) : super(const OrderRequestSubmission());

  Future<String?> submit({
    required OrderRequestType type,
    List<String> itemLines = const [],
    File? photoFile,
    required String contactPhone,
    required FulfillmentMethod fulfillmentMethod,
    String? deliveryAddress,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = const OrderRequestSubmission(error: 'You need to be signed in to place an order.');
      return null;
    }

    state = const OrderRequestSubmission(isSubmitting: true);
    final repo = _ref.read(orderRequestRepositoryProvider);

    String? photoUrl;
    if (photoFile != null) {
      final uploadResult = await repo.uploadListPhoto(user.uid, photoFile);
      final failed = uploadResult.match((f) => f, (_) => null);
      if (failed != null) {
        state = OrderRequestSubmission(error: failed.message);
        return null;
      }
      photoUrl = uploadResult.match((f) => null, (url) => url);
    }

    final result = await repo.createOrderRequest(
      userId: user.uid,
      type: type,
      itemLines: itemLines,
      photoUrl: photoUrl,
      contactPhone: contactPhone,
      fulfillmentMethod: fulfillmentMethod,
      deliveryAddress: deliveryAddress,
    );

    return result.match(
      (failure) {
        state = OrderRequestSubmission(error: failure.message);
        return null;
      },
      (requestId) {
        state = const OrderRequestSubmission();
        _ref.invalidate(myOrderRequestsProvider);
        return requestId;
      },
    );
  }
}

final orderRequestSubmitterProvider =
    StateNotifierProvider.autoDispose<OrderRequestSubmitter, OrderRequestSubmission>((ref) {
  return OrderRequestSubmitter(ref);
});
