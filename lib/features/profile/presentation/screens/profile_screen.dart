import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/edit_profile_dialog.dart';

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
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showEditProfileDialog(context, user),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          (user?.name?.isNotEmpty == true ? user!.name![0] : user?.email?[0] ?? '?')
                              .toUpperCase(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                          child: Icon(Icons.edit, size: 14, color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(user?.name ?? 'Guest', style: Theme.of(context).textTheme.titleLarge),
                  Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            label: 'My Addresses',
            onTap: () => context.push(RouteNames.addresses),
          ),
          _ProfileTile(
            icon: Icons.lock_outline,
            label: 'Change Password',
            onTap: () => showChangePasswordDialog(context),
          ),
          const _ProfileTile(icon: Icons.favorite_border, label: 'Wishlist'),
          const _ProfileTile(icon: Icons.notifications_outlined, label: 'Notifications'),
          _ProfileTile(
            icon: Icons.support_agent_outlined,
            label: 'Support / FAQ',
            onTap: () => context.push('/faqs'),
          ),
          _ProfileTile(
            icon: Icons.description_outlined,
            label: 'Terms & Conditions',
            onTap: () => context.push('/terms-conditions'),
          ),
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
  final VoidCallback? onTap;
  const _ProfileTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ??
          () {
            // Not built yet — Wishlist and Notifications modules aren't
            // in scope for this pass.
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
          },
    );
  }
}
