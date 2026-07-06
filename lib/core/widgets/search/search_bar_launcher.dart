import 'package:flutter/material.dart';
import '../../theme/app_radii_shadows.dart';
import '../../theme/app_spacing.dart';

/// A non-editable, tappable search "field" that navigates to the real
/// Search screen on tap — used on Home and Categories so the keyboard
/// only appears once the user has actually committed to searching.
class SearchBarLauncher extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;

  const SearchBarLauncher({super.key, required this.onTap, this.hint = 'Search for products'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.input,
        child: InkWell(
          borderRadius: AppRadii.input,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search, color: theme.colorScheme.outline),
                const SizedBox(width: AppSpacing.sm),
                Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
