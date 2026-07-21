import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: const Text('Customer Order History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Phone number or Customer ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
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
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                child: Text(
                                  '${orders.length} order${orders.length == 1 ? '' : 's'} found',
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
    final statusColor = order.status == OrderStatus.cancelled
        ? _red
        : order.status == OrderStatus.delivered
            ? _green
            : _orange;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${order.itemCount} items • ₹${order.totalAmount.toStringAsFixed(0)} • ${order.paymentMethod.label}\n'
          '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
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
