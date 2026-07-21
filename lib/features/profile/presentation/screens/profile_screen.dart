import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/edit_profile_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(currentUserProvider);
    final ordersAsync = ref.watch(myOrdersProvider);
    final addressesAsync = ref.watch(addressListProvider);

    final orderCount = ordersAsync.valueOrNull?.length ?? 0;
    final addressCount = addressesAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: colors.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Green header block — matches the reference design instead of
          // the earlier plain white card + separate avatar treatment.
          GestureDetector(
            onTap: () => showEditProfileDialog(context, user),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 40, AppSpacing.md, 24),
              decoration: BoxDecoration(
                color: colors.green,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    backgroundImage: user?.photoUrl?.isNotEmpty == true
                        ? CachedNetworkImageProvider(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl?.isNotEmpty == true
                        ? null
                        : Text(
                            (user?.name?.isNotEmpty == true ? user!.name![0] : user?.email?[0] ?? '?').toUpperCase(),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.green),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(user?.name ?? 'Guest', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (user?.phone?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(user!.phone!, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatItem(value: '$orderCount', label: 'Orders'),
                      const SizedBox(width: 26),
                      _StatItem(value: '${user?.loyaltyPoints ?? 0}', label: 'Points'),
                      const SizedBox(width: 26),
                      _StatItem(value: '$addressCount', label: 'Addresses'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'My orders',
                  subtitle: 'Track, reorder or return',
                  onTap: () => context.push(RouteNames.orders),
                ),
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Saved addresses',
                  subtitle: addressCount > 0 ? '$addressCount saved' : 'Add your first address',
                  onTap: () => context.push(RouteNames.addresses),
                ),
                _MenuItem(
                  icon: Icons.lock_outline,
                  title: 'Change password',
                  subtitle: 'Update your login password',
                  onTap: () async {
                    final changed = await showChangePasswordDialog(context);
                    if (changed == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
                    }
                  },
                ),
                _MenuItem(
                  icon: Icons.favorite_border,
                  title: 'Wishlist',
                  subtitle: 'Items you\'ve saved',
                  onTap: () => context.push(RouteNames.wishlist),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Order and offer alerts',
                  onTap: () => openAppSettings(),
                ),
                const _ThemeModeMenuItem(),
                _MenuItem(
                  icon: Icons.support_agent_outlined,
                  title: 'Help & support',
                  subtitle: 'FAQs and contact us',
                  onTap: () => context.push('/faqs'),
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  onTap: () => context.push('/terms-conditions'),
                ),
                _MenuItem(
                  icon: Icons.science_outlined,
                  title: 'Seed Sample Products (Dev)',
                  onTap: () => context.push('/dev/seed-products'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MenuItem(
                  icon: Icons.logout,
                  title: 'Log out',
                  iconColor: colors.red,
                  titleColor: colors.red,
                  onTap: () => ref.read(signOutUseCaseProvider).call(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}

class _ThemeModeMenuItem extends ConsumerWidget {
  const _ThemeModeMenuItem();

  String _label(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final mode = ref.watch(themeModeProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: colors.green.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(Icons.dark_mode_outlined, size: 18, color: colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Appearance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.ink)),
          ),
          DropdownButton<ThemeMode>(
            value: mode,
            underline: const SizedBox.shrink(),
            dropdownColor: colors.card,
            items: ThemeMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(_label(m), style: TextStyle(fontSize: 13, color: colors.ink))))
                .toList(),
            onChanged: (m) {
              if (m != null) ref.read(themeModeProvider.notifier).setThemeMode(m);
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final disabled = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: colors.green.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: disabled ? colors.muted : (iconColor ?? colors.green)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: disabled ? colors.muted : (titleColor ?? colors.ink))),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: TextStyle(fontSize: 10.5, color: colors.muted)),
                    ),
                ],
              ),
            ),
            if (!disabled) Icon(Icons.chevron_right, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
