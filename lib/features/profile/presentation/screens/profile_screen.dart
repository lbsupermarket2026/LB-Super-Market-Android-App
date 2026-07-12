import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/edit_profile_dialog.dart';

const _green = Color(0xFF2E7D32);
const _greenLight = Color(0xFFEAF3DE);
const _ink = Color(0xFF232620);
const _red = Color(0xFFE53935);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final ordersAsync = ref.watch(myOrdersProvider);
    final addressesAsync = ref.watch(addressListProvider);

    final orderCount = ordersAsync.valueOrNull?.length ?? 0;
    final addressCount = addressesAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
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
              decoration: const BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Text(
                      (user?.name?.isNotEmpty == true ? user!.name![0] : user?.email?[0] ?? '?').toUpperCase(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _green),
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
                  icon: Icons.local_offer_outlined,
                  title: 'Coupons & offers',
                  subtitle: 'Coming soon',
                  onTap: null,
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Order and offer alerts',
                  onTap: () => openAppSettings(),
                ),
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
                  iconColor: _red,
                  titleColor: _red,
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
    final disabled = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEECE2)),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: disabled ? Colors.grey : (iconColor ?? _green)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: disabled ? Colors.grey : (titleColor ?? _ink))),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!, style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A8D82))),
                    ),
                ],
              ),
            ),
            if (!disabled) const Icon(Icons.chevron_right, color: Color(0xFFC9C7BB)),
          ],
        ),
      ),
    );
  }
}
