import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../domain/entities/sales_bucket_entity.dart';
import '../providers/sales_report_providers.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

class AdminSalesScreen extends ConsumerWidget {
  const AdminSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granularity = ref.watch(selectedGranularityProvider);
    final bucketsAsync = ref.watch(salesBucketsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: const Text('Sales Reports')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
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
          Expanded(
            child: bucketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load sales data: $e')),
              data: (buckets) {
                if (buckets.isEmpty) {
                  return const Center(child: Text('No orders in this time range yet.'));
                }

                final totalRevenue = buckets.fold(0.0, (sum, b) => sum + b.revenue);
                final totalOrders = buckets.fold(0, (sum, b) => sum + b.orderCount);
                final totalCancelled = buckets.fold(0, (sum, b) => sum + b.cancelledCount);
                final avgOrderValue = totalOrders == 0 ? 0.0 : totalRevenue / totalOrders;
                final maxRevenue = buckets.map((b) => b.revenue).fold(0.0, (a, b) => a > b ? a : b);

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _SummaryCard(label: 'Revenue', value: '₹${totalRevenue.toStringAsFixed(0)}', color: _green)),
                        const SizedBox(width: 8),
                        Expanded(child: _SummaryCard(label: 'Orders', value: '$totalOrders', color: _orange)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _SummaryCard(label: 'Avg Order', value: '₹${avgOrderValue.toStringAsFixed(0)}', color: _green)),
                        const SizedBox(width: 8),
                        Expanded(child: _SummaryCard(label: 'Cancelled', value: '$totalCancelled', color: _red)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: AppSpacing.sm),
                    ...buckets.reversed.map((b) => _BucketRow(bucket: b, maxRevenue: maxRevenue)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
