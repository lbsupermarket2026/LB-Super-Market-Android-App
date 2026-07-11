import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../order_mgmt/presentation/providers/admin_order_providers.dart';
import '../../domain/entities/sales_bucket_entity.dart';
import '../../domain/utils/sales_aggregator.dart';

final selectedGranularityProvider = StateProvider.autoDispose<SalesGranularity>((ref) => SalesGranularity.daily);

final salesBucketsProvider = Provider.autoDispose<AsyncValue<List<SalesBucketEntity>>>((ref) {
  final ordersAsync = ref.watch(allOrdersAdminProvider);
  final granularity = ref.watch(selectedGranularityProvider);

  return ordersAsync.whenData((orders) => SalesAggregator.aggregate(orders, granularity));
});
