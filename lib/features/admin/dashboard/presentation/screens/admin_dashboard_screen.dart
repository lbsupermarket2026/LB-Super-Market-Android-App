import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../authentication/presentation/providers/auth_providers.dart';

/// Placeholder — full Admin dashboard (KPIs, low-stock alerts, quick
/// links) is built once the customer-facing modules are complete.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(signOutUseCaseProvider).call(),
          ),
        ],
      ),
      body: Center(
        child: Text('Signed in as admin: ${user?.name ?? user?.email ?? ''}'),
      ),
    );
  }
}
