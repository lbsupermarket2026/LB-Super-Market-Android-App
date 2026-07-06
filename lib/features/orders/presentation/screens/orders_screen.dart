import 'package:flutter/material.dart';
import '../../../../core/widgets/states/empty_state.dart';

/// Placeholder — full Order History/Tracking module comes after Cart +
/// Checkout are built (orders can't really exist without those first).
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: const EmptyStateWidget(
        message: 'Your orders will show up here once you place one.',
        icon: Icons.receipt_long_outlined,
      ),
    );
  }
}
