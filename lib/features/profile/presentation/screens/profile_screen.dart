import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              (user?.name?.isNotEmpty == true ? user!.name![0] : user?.email?[0] ?? '?').toUpperCase(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: Text(user?.name ?? 'Guest', style: Theme.of(context).textTheme.titleLarge)),
          Center(child: Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(height: AppSpacing.xl),
          const _ProfileTile(icon: Icons.location_on_outlined, label: 'My Addresses'),
          const _ProfileTile(icon: Icons.favorite_border, label: 'Wishlist'),
          const _ProfileTile(icon: Icons.notifications_outlined, label: 'Notifications'),
          const _ProfileTile(icon: Icons.support_agent_outlined, label: 'Support / FAQ'),
          const _ProfileTile(icon: Icons.description_outlined, label: 'Terms & Conditions'),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Sign Out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => ref.read(signOutUseCaseProvider).call(),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ProfileTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Wired up as each respective module (addresses, wishlist,
        // notifications, support, terms) is built.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
      },
    );
  }
}
