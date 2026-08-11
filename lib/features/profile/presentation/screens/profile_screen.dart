import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../addresses/presentation/providers/address_providers.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../wishlist/presentation/providers/wishlist_providers.dart';
import '../../../offers/presentation/providers/offer_card_providers.dart';
import '../../../notifications/presentation/providers/customer_notifications_providers.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/edit_profile_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(currentUserProfileProvider).valueOrNull ?? ref.watch(currentUserProvider);
    final ordersAsync = ref.watch(myOrdersProvider);
    final addressesAsync = ref.watch(addressListProvider);
    final wishlistAsync = ref.watch(wishlistProvider);
    final offersAsync = ref.watch(enabledOfferCardsProvider);
    final unreadCount = ref.watch(customerUnreadCountProvider);

    final orderCount = ordersAsync.valueOrNull?.length ?? 0;
    final addressCount = addressesAsync.valueOrNull?.length ?? 0;
    final wishlistCount = wishlistAsync.valueOrNull?.length ?? 0;
    final offersCount = offersAsync.valueOrNull?.length ?? 0;

    // Mirrors the same check RouteGuard uses to decide whether email
    // verification is still pending — phone-only accounts (no email
    // on file) count as verified here too, since they already went
    // through OTP verification at signup.
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    final isVerified = firebaseUser?.email == null || firebaseUser!.emailVerified;

    return Scaffold(
      backgroundColor: colors.surface,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // NEW: soft gradient header (green tint fading to the page
          // background) replacing the previous solid green block —
          // matches the lighter, airier reference design. Avatar sits
          // left-aligned with a small edit-pencil badge, name/phone/
          // verified badge to its right, bell + settings icons top-right.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 48, AppSpacing.md, AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.green.withOpacity(0.18), colors.surface],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => showEditProfileDialog(context, user),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colors.card,
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
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: const Icon(Icons.edit, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, ${user?.name?.split(' ').first ?? 'there'} 👋',
                          style: TextStyle(fontSize: 12.5, color: colors.muted)),
                      const SizedBox(height: 2),
                      Text(user?.name ?? 'Guest',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: colors.ink)),
                      if (user?.phone?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(user!.phone!, style: TextStyle(fontSize: 12, color: colors.muted)),
                        ),
                      if (isVerified) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: colors.green.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: colors.green),
                              const SizedBox(width: 4),
                              Text('Verified', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: colors.green)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _HeaderIconButton(
                  icon: Icons.notifications_outlined,
                  badgeCount: unreadCount,
                  onTap: () => context.push('/notifications'),
                ),
                const SizedBox(width: 8),
                _HeaderIconButton(
                  icon: Icons.settings_outlined,
                  onTap: () => showEditProfileDialog(context, user),
                ),
              ],
            ),
          ),
          // NEW: no spacing existed here at all between the header and
          // the stat cards row — when the Verified badge pushed the
          // header's content taller, the cards row (positioned right
          // after with zero gap) overlapped it. Header itself
          // untouched, just adding breathing room below it.
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: _StatCard(icon: Icons.receipt_long_outlined, value: orderCount, label: 'Orders', color: colors.green, onTap: () => context.push(RouteNames.orders))),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(icon: Icons.location_on_outlined, value: addressCount, label: 'Addresses', color: colors.green, onTap: () => context.push(RouteNames.addresses))),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(icon: Icons.favorite_border, value: wishlistCount, label: 'Wishlist', color: const Color(0xFFEF6C00), onTap: () => context.push(RouteNames.wishlist))),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(icon: Icons.local_offer_outlined, value: offersCount, label: 'Offers', color: const Color(0xFFEF6C00), onTap: () => context.push(RouteNames.offers))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel('Account'),
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  title: 'My orders',
                  subtitle: 'Track, reorder or return',
                  onTap: () => context.push(RouteNames.orders),
                ),
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Saved addresses',
                  subtitle: 'View and manage addresses',
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
                const SizedBox(height: AppSpacing.sm),
                _SectionLabel('Preferences'),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Order and offer alerts',
                  onTap: () => context.push('/notifications'),
                ),
                const _ThemeModeMenuItem(),
                const _LanguageMenuItem(),
                const SizedBox(height: AppSpacing.sm),
                _SectionLabel('Support'),
                _MenuItem(
                  icon: Icons.support_agent_outlined,
                  title: 'Help & support',
                  subtitle: 'FAQs and contact us',
                  onTap: () => context.push('/faqs'),
                ),
                _MenuItem(
                  icon: Icons.info_outline,
                  title: 'About us',
                  onTap: () => context.push('/about-us'),
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  onTap: () => context.push('/privacy-policy'),
                ),
                const SizedBox(height: AppSpacing.md),
                _MenuItem(
                  icon: Icons.logout,
                  title: 'Log out',
                  iconColor: colors.red,
                  titleColor: colors.red,
                  showChevron: false,
                  center: true,
                  onTap: () => ref.read(signOutUseCaseProvider).call(),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text('Version 1.0.0', style: TextStyle(fontSize: 11, color: colors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, this.badgeCount = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, size: 18, color: colors.ink),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: colors.red, shape: BoxShape.circle, border: Border.all(color: colors.surface, width: 1.5)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(height: 6),
            Text('$value', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.ink)),
            Text(label, style: TextStyle(fontSize: 10, color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4, left: 2),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colors.green)),
    );
  }
}

class _ThemeModeMenuItem extends ConsumerWidget {
  const _ThemeModeMenuItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final mode = ref.watch(themeModeProvider);
    // NEW: simple on/off Switch instead of opening a dialog, matching
    // the reference design. "On" = dark. Collapses ThemeMode.system
    // into whichever it currently resolves to for display purposes —
    // tapping the switch always sets an explicit light/dark from then
    // on, same as flipping a normal setting.
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

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
            child: Text('Dark mode', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.ink)),
          ),
          Switch(
            value: isDark,
            activeTrackColor: colors.green,
            onChanged: (value) => ref.read(themeModeProvider.notifier).setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
          ),
        ],
      ),
    );
  }
}

class _LanguageMenuItem extends StatelessWidget {
  const _LanguageMenuItem();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
            child: Icon(Icons.language, size: 18, color: colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Language', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.ink)),
          ),
          // NOTE: display-only for now — the app doesn't have a
          // localization system wired up yet, so this reflects the
          // fixed current language rather than being interactive.
          Text('English', style: TextStyle(fontSize: 13, color: colors.muted)),
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
  final bool showChevron;
  final bool center;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
    this.center = false,
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
          mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: colors.green.withOpacity(0.14), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: disabled ? colors.muted : (iconColor ?? colors.green)),
            ),
            const SizedBox(width: 12),
            if (center)
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: disabled ? colors.muted : (titleColor ?? colors.ink)))
            else
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
            if (!disabled && showChevron && !center) Icon(Icons.chevron_right, color: colors.muted),
          ],
        ),
      ),
    );
  }
}
