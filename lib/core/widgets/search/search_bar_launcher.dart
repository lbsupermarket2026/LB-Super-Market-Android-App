import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// A non-editable, tappable search "field" that navigates to the real
/// Search screen on tap. Hardcoded white pill on the cream background,
/// matching the website's rounded search styling.
class SearchBarLauncher extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;

  const SearchBarLauncher({super.key, required this.onTap, this.hint = 'Search for products'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.black45),
                const SizedBox(width: AppSpacing.sm),
                Text(hint, style: const TextStyle(color: Colors.black45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
