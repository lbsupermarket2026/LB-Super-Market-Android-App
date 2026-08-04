import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../providers/auth_providers.dart';

const _green = Color(0xFF2E7D32);
const _lightGreenBox = Color(0xFFE3EFDD);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openDeveloperSite() async {
    final uri = Uri.parse('https://www.matricservices.in/');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(signInNotifierProvider.notifier).signIn(
          identifier: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!success && mounted) {
      final error = ref.read(signInNotifierProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Sign in failed.')));
    }
  }

  // NEW: icon badge for each field's prefixIcon. Theme-aware —
  // light mode: soft pastel-green rounded square (original design).
  // Dark mode: translucent green circle, matching the reference
  // screenshot exactly rather than just reusing the light-mode look
  // on a dark card.
  Widget _fieldIcon(IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? _green.withOpacity(0.25) : _lightGreenBox,
          shape: isDark ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isDark ? null : BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: isDark ? Colors.greenAccent.shade100 : _green),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signInState = ref.watch(signInNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundAsset = isDark ? 'assets/images/login_background_dark.png' : 'assets/images/login_background.png';

    // NEW: the whole form card, its text, and its dividers now
    // branch on theme — previously the card was hardcoded white
    // with black text in every theme, which looked fine in light
    // mode but fought against a dark background image and the rest
    // of the app's dark theme. Matches a reference screenshot of
    // the intended dark-mode look: a dark translucent card, light
    // text, and green-tinted (not pastel) accents.
    final cardColor = isDark ? Colors.black.withOpacity(0.55) : Colors.white.withOpacity(0.94);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade300 : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final bodyTextColor = isDark ? Colors.white : Colors.black87;
    final footerColor = isDark ? Colors.white70 : Colors.black.withOpacity(0.55);
    final trustCardColor = isDark ? Colors.black.withOpacity(0.45) : Colors.white.withOpacity(0.85);
    final trustTitleColor = isDark ? Colors.white : Colors.black87;
    final trustSubtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final trustIconBg = isDark ? _green.withOpacity(0.25) : _lightGreenBox;
    final trustIconColor = isDark ? Colors.greenAccent.shade100 : _green;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : const Color(0xFFF6F8ED),
          image: DecorationImage(
            image: AssetImage(backgroundAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - AppSpacing.lg * 2),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          Center(
                            child: Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/images/bs_logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.storefront, size: 56, color: _green),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Welcome back!',
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: titleColor)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.auto_awesome, size: 18, color: _green),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Center(
                                  child: Text(
                                    'Sign in to continue shopping',
                                    style: TextStyle(color: subtitleColor),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                AppTextField(
                                  controller: _emailController,
                                  label: 'Email or Phone Number',
                                  keyboardType: TextInputType.text,
                                  prefixIcon: _fieldIcon(Icons.person_outline, isDark),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Email or phone number is required';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                AppTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  obscureText: _obscurePassword,
                                  prefixIcon: _fieldIcon(Icons.lock_outline, isDark),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Password is required';
                                    return null;
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => context.push(RouteNames.forgotPassword),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                PrimaryButton(
                                  label: 'Sign In',
                                  isLoading: signInState.isLoading,
                                  onPressed: _onSignIn,
                                  gradientColors: const [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                                  trailingIcon: Icons.arrow_forward,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: dividerColor)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('OR', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                    Expanded(child: Divider(color: dividerColor)),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Don't have an account?", style: TextStyle(color: bodyTextColor)),
                                    TextButton(
                                      onPressed: () => context.push(RouteNames.signup),
                                      child: const Text('Sign Up'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: trustCardColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TrustBadge(
                                    icon: Icons.verified_outlined,
                                    title: 'Quality Products',
                                    subtitle: 'You can trust',
                                    iconBg: trustIconBg,
                                    iconColor: trustIconColor,
                                    titleColor: trustTitleColor,
                                    subtitleColor: trustSubtitleColor,
                                  ),
                                ),
                                Expanded(
                                  child: _TrustBadge(
                                    icon: Icons.shield_outlined,
                                    title: '100% Secure',
                                    subtitle: 'Safe & reliable',
                                    iconBg: trustIconBg,
                                    iconColor: trustIconColor,
                                    titleColor: trustTitleColor,
                                    subtitleColor: trustSubtitleColor,
                                  ),
                                ),
                                Expanded(
                                  child: _TrustBadge(
                                    icon: Icons.local_shipping_outlined,
                                    title: 'Fast Delivery',
                                    subtitle: 'Right to your door',
                                    iconBg: trustIconBg,
                                    iconColor: trustIconColor,
                                    titleColor: trustTitleColor,
                                    subtitleColor: trustSubtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Center(
                            child: GestureDetector(
                              onTap: _openDeveloperSite,
                              child: Text(
                                'Developed by Matric Services',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: footerColor,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;
  final Color titleColor;
  final Color subtitleColor;
  const _TrustBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(height: 6),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: titleColor)),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: subtitleColor)),
      ],
    );
  }
}
