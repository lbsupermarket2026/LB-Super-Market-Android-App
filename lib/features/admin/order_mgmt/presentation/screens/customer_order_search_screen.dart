import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../providers/admin_order_providers.dart';
import 'admin_order_detail_screen.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

/// Lets staff pull a customer's full order history — past and present —
/// by either their phone number or their account/user ID, for whenever
/// a customer calls in asking about a previous order.
class CustomerOrderSearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const CustomerOrderSearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<CustomerOrderSearchScreen> createState() => _CustomerOrderSearchScreenState();
}

class _CustomerOrderSearchScreenState extends ConsumerState<CustomerOrderSearchScreen> {
  late final TextEditingController _controller;
  String _submittedQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery?.isNotEmpty == true) _submittedQuery = widget.initialQuery!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    setState(() => _submittedQuery = _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Customer Order History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              // FIXED: was hardcoded fillColor: Colors.white — in dark
              // mode the typed text (theme default, light) became
              // invisible against a permanently-white field. Now
              // themed via context.appColors.
              style: TextStyle(color: colors.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.card,
                hintText: 'Phone number or Customer ID',
                hintStyle: TextStyle(color: colors.muted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.search, color: colors.muted),
                suffixIcon: IconButton(icon: Icon(Icons.arrow_forward, color: colors.ink), onPressed: _search),
              ),
            ),
          ),
          Expanded(
            child: _submittedQuery.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Enter a customer\'s phone number or user ID to see every order they\'ve placed.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Consumer(
                    builder: (context, ref, _) {
                      final resultsAsync = ref.watch(customerOrderSearchProvider(_submittedQuery));
                      return resultsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Could not search orders: $e')),
                        data: (orders) {
                          if (orders.isEmpty) {
                            return const Center(child: Text('No orders found for that phone number or ID.'));
                          }
                          final totalSpent = orders.fold<double>(0, (sum, o) => sum + o.totalAmount);
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                child: Text(
                                  '${orders.length} order${orders.length == 1 ? '' : 's'} found • ₹${totalSpent.toStringAsFixed(0)} total',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: _green),
                                ),
                              ),
                              ...orders.map((order) => _OrderTile(order: order)),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderEntity order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = order.status == OrderStatus.cancelled
        ? _red
        : order.status == OrderStatus.delivered
            ? _green
            : _orange;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Order #${order.orderNumber ?? order.id.substring(0, order.id.length.clamp(0, 8))}',
            style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink)),
        subtitle: Text(
          '${order.itemCount} items • ₹${order.totalAmount.toStringAsFixed(0)} • ${order.paymentMethod.label}\n'
          '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
          style: TextStyle(color: colors.muted),
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(order.status.label, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order))),
      ),
    );
  }
}
