import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/error_state.dart';
import 'package:freshcart/features/business_info/presentation/providers/business_info_providers.dart';
import 'package:freshcart/features/business_info/domain/entities/business_info_entity.dart';

class AboutUsScreen extends ConsumerWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(businessInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: infoAsync.when(
        data: (info) => _AboutUsContent(info: info),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load business information.',
          onRetry: () => ref.invalidate(businessInfoProvider),
        ),
      ),
    );
  }
}

class _AboutUsContent extends StatelessWidget {
  final BusinessInfoEntity info;
  const _AboutUsContent({required this.info});

  Future<void> _launch(String uri) async {
    final parsed = Uri.parse(uri);
    if (await canLaunchUrl(parsed)) await launchUrl(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Section heading — centered title with a short accent-colored
          // underline, matching the website's "About Us" section header.
          Text(
            'About Us',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(width: 48, height: 3, color: cs.tertiary),
          const SizedBox(height: AppSpacing.xl),

          // Logo + description row — mirrors the website's layout of the
          // brand mark beside the About Us paragraph, wrapping to a
          // column on narrow screens so nothing gets cramped.
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final logo = Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset('assets/images/bs_logo.png', fit: BoxFit.contain),
              );
              final text = Text(
                info.aboutUsText.isNotEmpty ? info.aboutUsText : 'About us content coming soon.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                textAlign: isNarrow ? TextAlign.center : TextAlign.start,
              );

              if (isNarrow) {
                return Column(
                  children: [
                    logo,
                    const SizedBox(height: AppSpacing.md),
                    text,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  logo,
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: text),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),

          if (info.physicalAddress?.isNotEmpty == true)
            _InfoRow(icon: Icons.location_on_outlined, label: info.physicalAddress!),
          if (info.contactPhone?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.call_outlined,
              label: info.contactPhone!,
              onTap: () => _launch('tel:${info.contactPhone}'),
            ),
          if (info.contactEmail?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.email_outlined,
              label: info.contactEmail!,
              onTap: () => _launch('mailto:${info.contactEmail}'),
            ),

          if (info.businessHours.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Business Hours', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...info.businessHours.map(
              (h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(h.day, style: theme.textTheme.bodyMedium),
                    Text('${h.openTime} – ${h.closeTime}', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Social row — filled circular buttons in the brand green,
          // similar weight to the website footer's social icon row.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (info.whatsappBusinessNumber?.isNotEmpty == true)
                _SocialButton(
                  icon: Icons.chat_bubble_outline,
                  tooltip: 'WhatsApp',
                  onPressed: () => _launch('https://wa.me/${info.whatsappBusinessNumber}'),
                ),
              if (info.instagram?.isNotEmpty == true)
                _SocialButton(
                  icon: Icons.camera_alt_outlined,
                  tooltip: 'Instagram',
                  onPressed: () => _launch(info.instagram!),
                ),
              if (info.facebook?.isNotEmpty == true)
                _SocialButton(
                  icon: Icons.facebook_outlined,
                  tooltip: 'Facebook',
                  onPressed: () => _launch(info.facebook!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _SocialButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: cs.primary,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: cs.onPrimary, size: 20),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _InfoRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
