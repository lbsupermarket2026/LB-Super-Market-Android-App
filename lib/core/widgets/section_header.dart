import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Two-tone title + small accent underline — the same treatment used on
/// Categories and About Us ("Shop by Category" style), so every section
/// heading across the app reads as one consistent visual language rather
/// than plain default Material titles.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? accentWord;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, this.accentWord, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final words = title.split(' ');
    final accent = accentWord ?? words.last;
    // When accentWord is explicitly passed, strip it off the end of title
    // (if present) to get the lead text — previously this used the full
    // title as the lead AND appended accentWord again, producing
    // duplicated text like "Shop by Category Category".
    final lead = accentWord != null
        ? (title.endsWith(accentWord!) ? title.substring(0, title.length - accentWord!.length).trim() : title)
        : words.sublist(0, words.length - 1).join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: Colors.black87),
                    children: [
                      if (lead.isNotEmpty) TextSpan(text: '$lead '),
                      TextSpan(text: accent, style: const TextStyle(color: Color(0xFFEF6C00))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(width: 32, height: 3, color: const Color(0xFFEF6C00)),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('See all'), Icon(Icons.chevron_right, size: 18)],
              ),
            ),
        ],
      ),
    );
  }
}
