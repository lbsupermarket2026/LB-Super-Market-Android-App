import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/order_remote_datasource.dart';
import '../../data/repositories_impl/order_repository_impl.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/get_my_orders_usecase.dart';
import '../../domain/usecases/get_order_by_id_usecase.dart';
import '../../domain/usecases/create_order_usecase.dart';
import '../../domain/usecases/submit_order_rating_usecase.dart';
import '../../domain/usecases/cancel_order_usecase.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSource();
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(ref.watch(orderRemoteDataSourceProvider));
});

final getMyOrdersUseCaseProvider = Provider<GetMyOrdersUseCase>((ref) {
  return GetMyOrdersUseCase(ref.watch(orderRepositoryProvider));
});

final getOrderByIdUseCaseProvider = Provider<GetOrderByIdUseCase>((ref) {
  return GetOrderByIdUseCase(ref.watch(orderRepositoryProvider));
});

final createOrderUseCaseProvider = Provider<CreateOrderUseCase>((ref) {
  return CreateOrderUseCase(ref.watch(orderRepositoryProvider));
});

final submitOrderRatingUseCaseProvider = Provider<SubmitOrderRatingUseCase>((ref) {
  return SubmitOrderRatingUseCase(ref.watch(orderRepositoryProvider));
});

final cancelOrderUseCaseProvider = Provider<CancelOrderUseCase>((ref) {
  return CancelOrderUseCase(ref.watch(orderRepositoryProvider));
});

class CancelOrderState {
  final bool isSubmitting;
  final String? error;
  const CancelOrderState({this.isSubmitting = false, this.error});
}

class CancelOrderNotifier extends StateNotifier<CancelOrderState> {
  final Ref _ref;
  CancelOrderNotifier(this._ref) : super(const CancelOrderState());

  Future<bool> cancel(String orderId) async {
    state = const CancelOrderState(isSubmitting: true);
    final result = await _ref.read(cancelOrderUseCaseProvider).call(orderId);
    return result.match(
      (failure) {
        state = CancelOrderState(error: failure.message);
        return false;
      },
      (_) {
        state = const CancelOrderState();
        _ref.invalidate(myOrdersProvider);
        _ref.invalidate(orderByIdProvider(orderId));
        return true;
      },
    );
  }
}

final cancelOrderProvider = StateNotifierProvider.autoDispose<CancelOrderNotifier, CancelOrderState>((ref) {
  return CancelOrderNotifier(ref);
});

/// Watches currentUserProvider so this automatically refreshes on
/// sign-in/out rather than caching a stale empty list for a guest.
final myOrdersProvider = FutureProvider.autoDispose<List<OrderEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final result = await ref.watch(getMyOrdersUseCaseProvider).call(user.uid);
  return result.match((failure) => throw failure, (orders) => orders);
});

final orderByIdProvider = FutureProvider.autoDispose.family<OrderEntity, String>((ref, orderId) async {
  // Without a timeout, a stalled network call leaves this stuck in
  // AsyncLoading forever — an infinite spinner with no way out. This
  // guarantees it eventually surfaces as a real, retryable error instead.
  final result = await ref.watch(getOrderByIdUseCaseProvider).call(orderId).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Taking too long to load — check your connection and try again.'),
      );
  return result.match((failure) => throw failure, (order) => order);
});
