import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../inventory_mgmt/presentation/providers/admin_inventory_providers.dart';
import '../../../order_mgmt/presentation/providers/admin_order_providers.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../../products/domain/entities/product_entity.dart';
import '../../domain/entities/sales_bucket_entity.dart';
import '../providers/sales_report_providers.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

// Products at or below this stock level count toward the "Low Stock" KPI.
const _lowStockThreshold = 5;

class AdminSalesScreen extends ConsumerWidget {
  const AdminSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granularity = ref.watch(selectedGranularityProvider);
    final bucketsAsync = ref.watch(salesBucketsProvider);
    final ordersAsync = ref.watch(allOrdersAdminProvider);
    final requestsAsync = ref.watch(allOrderRequestsAdminProvider);
    final productsAsync = ref.watch(allProductsAdminProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: const Text('Sales Reports')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Fixed KPI cards — these reflect current overall state and do
          // NOT change with the granularity selector below, unlike the
          // breakdown chart which is scoped to the selected time window.
          _KpiGrid(ordersAsync: ordersAsync, requestsAsync: requestsAsync, productsAsync: productsAsync),
          const SizedBox(height: AppSpacing.lg),
          const Text('Sales Over Time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: SalesGranularity.values.map((g) {
                final selected = g == granularity;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g.label),
                    selected: selected,
                    selectedColor: _green,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontSize: 12),
                    onSelected: (_) => ref.read(selectedGranularityProvider.notifier).state = g,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          bucketsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Could not load sales data: $e'),
            ),
            data: (buckets) {
              if (buckets.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('No orders in this time range yet.')),
                );
              }
              final maxRevenue = buckets.map((b) => b.revenue).fold(0.0, (a, b) => a > b ? a : b);
              return Column(children: buckets.reversed.map((b) => _BucketRow(bucket: b, maxRevenue: maxRevenue)).toList());
            },
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final AsyncValue<List<OrderEntity>> ordersAsync;
  final AsyncValue<List<OrderRequestEntity>> requestsAsync;
  final AsyncValue<List<ProductEntity>> productsAsync;

  const _KpiGrid({required this.ordersAsync, required this.requestsAsync, required this.productsAsync});

  @override
  Widget build(BuildContext context) {
    final orders = ordersAsync.valueOrNull ?? [];
    final totalSales = orders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold(0.0, (sum, o) => sum + o.totalAmount);
    final totalOrders = orders.where((o) => o.status != OrderStatus.cancelled).length;

    final requests = requestsAsync.valueOrNull ?? [];
    final pendingRequests = requests.where((r) => r.status == OrderRequestStatus.pending).length;

    final products = productsAsync.valueOrNull ?? [];
    final lowStockCount = products.where((p) => p.stockQty <= _lowStockThreshold).length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        _KpiCard(label: 'Total Sales', value: '₹${totalSales.toStringAsFixed(0)}', icon: Icons.payments_outlined, color: _green),
        _KpiCard(label: 'Total Orders', value: '$totalOrders', icon: Icons.receipt_long_outlined, color: _orange),
        _KpiCard(label: 'Pending Requests', value: '$pendingRequests', icon: Icons.pending_actions_outlined, color: Colors.blueGrey),
        _KpiCard(
          label: 'Low Stock (≤$_lowStockThreshold)',
          value: '$lowStockCount',
          icon: Icons.warning_amber_outlined,
          color: _red,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  final SalesBucketEntity bucket;
  final double maxRevenue;
  const _BucketRow({required this.bucket, required this.maxRevenue});

  @override
  Widget build(BuildContext context) {
    final ratio = maxRevenue == 0 ? 0.0 : (bucket.revenue / maxRevenue).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bucket.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('₹${bucket.revenue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: _green)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: const AlwaysStoppedAnimation(_green),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${bucket.orderCount} order${bucket.orderCount == 1 ? '' : 's'}${bucket.cancelledCount > 0 ? ' • ${bucket.cancelledCount} cancelled' : ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
