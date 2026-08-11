import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final trimmed = _controller.text.trim();
    // FIXED: results could go stale — e.g. a customer cancels an
    // order after admin already has this screen open with search
    // results loaded, and nothing here ever refreshed to reflect it.
    // Riverpod's FutureProvider.family won't automatically re-fetch
    // for the SAME query string, so re-tapping search with an
    // unchanged query previously did nothing. Explicitly invalidating
    // first forces a fresh read every time, not just on a query change.
    ref.invalidate(customerOrderSearchProvider(trimmed));
    setState(() => _submittedQuery = trimmed);
    _resolveDisplayName(trimmed);
  }

  // NEW: the search box used to keep showing whatever raw value you
  // typed/searched (a phone number, or a raw Firestore user ID like
  // "W2NsK2Zmds...") even after a customer was successfully found —
  // looked like a meaningless random string. Once resolved, swap the
  // box's own text to their actual name + customer code instead, same
  // information already shown in the header below, but now reflected
  // in the search field itself too rather than left looking like a
  // stray ID.
  Future<void> _resolveDisplayName(String query) async {
    if (query.isEmpty) return;
    try {
      QueryDocumentSnapshot<Map<String, dynamic>>? userDoc;
      final byPhone = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: query).limit(1).get();
      if (byPhone.docs.isNotEmpty) {
        userDoc = byPhone.docs.first;
      } else {
        final byId = await FirebaseFirestore.instance.collection('users').doc(query).get();
        if (byId.exists) {
          final name = byId.data()?['name'] as String?;
          final code = byId.data()?['customerCode'] as String?;
          if (mounted && (name != null || code != null)) {
            _controller.text = [name, code].where((s) => s != null && s.isNotEmpty).join(' • ');
          }
          return;
        }
      }
      if (userDoc != null && mounted) {
        final name = userDoc.data()['name'] as String?;
        final code = userDoc.data()['customerCode'] as String?;
        if (name != null || code != null) {
          _controller.text = [name, code].where((s) => s != null && s.isNotEmpty).join(' • ');
        }
      }
    } catch (_) {
      // Non-fatal — just leaves the original search text as-is.
    }
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
                          // FIXED: was summing every order regardless
                          // of status — a cancelled order (especially
                          // one that never actually got paid, or got
                          // refunded) was still counting toward
                          // "total spent," inflating the figure with
                          // money the business never actually received.
                          final totalSpent = orders
                              .where((o) => o.status != OrderStatus.cancelled)
                              .fold<double>(0, (sum, o) => sum + o.totalAmount);
                          // NEW: pull-to-refresh, same reasoning as the
                          // search-button fix above — lets admin
                          // manually pull fresh data if a status
                          // changed since this screen was opened.
                          return RefreshIndicator(
                            onRefresh: () async => ref.invalidate(customerOrderSearchProvider(_submittedQuery)),
                            child: ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                            children: [
                              // NEW: previously this screen never showed
                              // WHO the customer actually is — just a
                              // bare list of orders, with no name or
                              // customer code (e.g. CUST0001) anywhere,
                              // even though you searched specifically
                              // by their phone/ID. Looks up their user
                              // profile once and shows it as a header.
                              _CustomerInfoHeader(userId: orders.first.userId),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                child: Text(
                                  '${orders.length} order${orders.length == 1 ? '' : 's'} found • ₹${totalSpent.toStringAsFixed(0)} total',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: _green),
                                ),
                              ),
                              ...orders.map((order) => _OrderTile(order: order)),
                            ],
                            ),
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

class _CustomerInfoHeader extends StatelessWidget {
  final String userId;
  const _CustomerInfoHeader({required this.userId});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['name'] as String?;
        final code = data?['customerCode'] as String?;
        if (name == null && code == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _green.withOpacity(0.2),
                child: Text(
                  (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
                  style: const TextStyle(color: _green, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name ?? 'Unnamed customer', style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink)),
                    if (code != null)
                      Text(code, style: TextStyle(fontSize: 12, color: colors.muted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
