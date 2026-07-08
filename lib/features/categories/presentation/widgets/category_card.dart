import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../domain/entities/category_entity.dart';

// Cycled for categories that don't have an admin-uploaded image, so empty
// slots still look intentional rather than like a broken image — same
// idea as the pastel icon badges on the website's "Shop by Category" strip.
const _fallbackPalette = [
  Color(0xFFFFF3D6),
  Color(0xFFFFE1D6),
  Color(0xFFE3E9FF),
  Color(0xFFE0F5E9),
  Color(0xFFDFF7F1),
];

class CategoryCard extends ConsumerWidget {
  final CategoryEntity category;
  final int index;
  final VoidCallback onTap;

  const CategoryCard({super.key, required this.category, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync = ref.watch(categoryProductCountProvider(category.id));
    final imageUrl = category.imageUrl ?? category.iconUrl;
    final fallbackColor = _fallbackPalette[index % _fallbackPalette.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // Hardcoded white/dark-text regardless of system theme — this
          // screen is meant to always look like the (light-themed)
          // website, not flip to dark colors when the phone is in system
          // dark mode.
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expanded gives this a bounded (but not necessarily square)
            // box, so the AspectRatio+Center inside picks the largest
            // centered *square* that fits — that's what keeps the badge
            // a true circle instead of stretching into an oval.
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: imageUrl?.isNotEmpty == true
                          ? CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: fallbackColor),
                              errorWidget: (_, __, ___) => Container(
                                color: fallbackColor,
                                child: const Icon(Icons.category_outlined),
                              ),
                            )
                          : Container(
                              color: fallbackColor,
                              child: const Icon(Icons.category_outlined),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            countAsync.when(
              data: (count) => Text(
                count == 1 ? '1 item' : '$count items',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              loading: () => Text('…', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
