import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/edit_profile_dialog.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFEF6C00);
const _red = Color(0xFFE53935);

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
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => showEditProfileDialog(context, user),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: _green.withOpacity(0.12),
                        child: Text(
                          (user?.name?.isNotEmpty == true ? user!.name![0] : user?.email?[0] ?? '?').toUpperCase(),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _green),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(user?.name ?? 'Guest',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                  Text(user?.email ?? '', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            color: _green,
            label: 'My Addresses',
            onTap: () => context.push(RouteNames.addresses),
          ),
          _ProfileTile(
            icon: Icons.lock_outline,
            color: _orange,
            label: 'Change Password',
            onTap: () async {
              final changed = await showChangePasswordDialog(context);
              if (changed == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully.')),
                );
              }
            },
          ),
          _ProfileTile(
            icon: Icons.favorite_border,
            color: _red,
            label: 'Wishlist',
            onTap: () => context.push(RouteNames.wishlist),
          ),
          _ProfileTile(
            icon: Icons.notifications_outlined,
            color: _green,
            label: 'Notifications',
            onTap: () => openAppSettings(),
          ),
          _ProfileTile(
            icon: Icons.support_agent_outlined,
            color: _orange,
            label: 'Support / FAQ',
            onTap: () => context.push('/faqs'),
          ),
          _ProfileTile(
            icon: Icons.description_outlined,
            color: Colors.blueGrey,
            label: 'Terms & Conditions',
            onTap: () => context.push('/terms-conditions'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProfileTile(
            icon: Icons.science_outlined,
            color: Colors.purple,
            label: 'Seed Sample Products (Dev)',
            onTap: () => context.push('/dev/seed-products'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.logout, color: _red),
              title: const Text('Sign Out', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
              onTap: () => ref.read(signOutUseCaseProvider).call(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  const _ProfileTile({required this.icon, required this.color, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
            },
      ),
    );
  }
}
