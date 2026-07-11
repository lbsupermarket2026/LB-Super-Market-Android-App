import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/admin_order_datasource.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';

final adminOrderDataSourceProvider = Provider<AdminOrderDataSource>((ref) {
  return AdminOrderDataSource();
});

final allOrdersAdminProvider = FutureProvider.autoDispose<List<OrderEntity>>((ref) {
  return ref.watch(adminOrderDataSourceProvider).getAllOrders();
});

final allOrderRequestsAdminProvider = FutureProvider.autoDispose<List<OrderRequestEntity>>((ref) {
  return ref.watch(adminOrderDataSourceProvider).getAllOrderRequests();
});

class AdminOrderMutationState {
  final bool isSubmitting;
  final String? error;
  const AdminOrderMutationState({this.isSubmitting = false, this.error});
}

class AdminOrderMutationNotifier extends StateNotifier<AdminOrderMutationState> {
  final Ref _ref;
  AdminOrderMutationNotifier(this._ref) : super(const AdminOrderMutationState());

  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    state = const AdminOrderMutationState(isSubmitting: true);
    try {
      await _ref.read(adminOrderDataSourceProvider).updateOrderStatus(orderId, status);
      state = const AdminOrderMutationState();
      _ref.invalidate(allOrdersAdminProvider);
      return true;
    } catch (e) {
      state = AdminOrderMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> assignDelivery(String orderId, String name, String phone) async {
    state = const AdminOrderMutationState(isSubmitting: true);
    try {
      await _ref.read(adminOrderDataSourceProvider).assignDelivery(orderId, name, phone);
      state = const AdminOrderMutationState();
      _ref.invalidate(allOrdersAdminProvider);
      return true;
    } catch (e) {
      state = AdminOrderMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> updateRequestStatus(String requestId, OrderRequestStatus status) async {
    state = const AdminOrderMutationState(isSubmitting: true);
    try {
      await _ref.read(adminOrderDataSourceProvider).updateRequestStatus(requestId, status);
      state = const AdminOrderMutationState();
      _ref.invalidate(allOrderRequestsAdminProvider);
      return true;
    } catch (e) {
      state = AdminOrderMutationState(error: e.toString());
      return false;
    }
  }

  Future<String?> convertRequestToOrder({
    required OrderRequestEntity request,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
  }) async {
    state = const AdminOrderMutationState(isSubmitting: true);
    try {
      final orderId = await _ref.read(adminOrderDataSourceProvider).convertRequestToOrder(
            request: request,
            items: items,
            totalAmount: totalAmount,
          );
      state = const AdminOrderMutationState();
      _ref.invalidate(allOrderRequestsAdminProvider);
      _ref.invalidate(allOrdersAdminProvider);
      return orderId;
    } catch (e) {
      state = AdminOrderMutationState(error: e.toString());
      return null;
    }
  }
}

final adminOrderMutationProvider =
    StateNotifierProvider.autoDispose<AdminOrderMutationNotifier, AdminOrderMutationState>((ref) {
  return AdminOrderMutationNotifier(ref);
});
