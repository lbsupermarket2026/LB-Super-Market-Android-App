import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/employee_order_datasource.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

final employeeOrderDataSourceProvider = Provider<EmployeeOrderDataSource>((ref) {
  return EmployeeOrderDataSource();
});

final myAssignedOrdersProvider = FutureProvider.autoDispose<List<OrderEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(employeeOrderDataSourceProvider).getMyAssignedOrders(user.uid);
});

class MarkDeliveredNotifier extends StateNotifier<bool> {
  final Ref _ref;
  MarkDeliveredNotifier(this._ref) : super(false);

  Future<bool> markDelivered(String orderId) async {
    state = true;
    try {
      await _ref.read(employeeOrderDataSourceProvider).markDelivered(orderId);
      _ref.invalidate(myAssignedOrdersProvider);
      return true;
    } catch (_) {
      return false;
    } finally {
      state = false;
    }
  }
}

final markDeliveredProvider = StateNotifierProvider.autoDispose<MarkDeliveredNotifier, bool>((ref) {
  return MarkDeliveredNotifier(ref);
});
