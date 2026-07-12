import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/category_entity.dart';

// Cycled for categories without an admin-uploaded image.
const _fallbackPalette = [
  Color(0xFFFFF3D6),
  Color(0xFFFFE1D6),
  Color(0xFFE3E9FF),
  Color(0xFFE0F5E9),
  Color(0xFFDFF7F1),
];

/// Full-bleed image tile with a dark gradient + name overlay at the
/// bottom — matches the reference design's Categories grid exactly,
/// replacing the earlier circular-badge-in-a-card style.
class CategoryCard extends ConsumerWidget {
  final CategoryEntity category;
  final int index;
  final VoidCallback onTap;

  const CategoryCard({super.key, required this.category, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = category.imageUrl ?? category.iconUrl;
    final fallbackColor = _fallbackPalette[index % _fallbackPalette.length];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl?.isNotEmpty == true
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: fallbackColor),
                    errorWidget: (_, __, ___) => Container(
                      color: fallbackColor,
                      child: const Icon(Icons.category_outlined, color: Colors.black38),
                    ),
                  )
                : Container(color: fallbackColor, child: const Icon(Icons.category_outlined, color: Colors.black38)),
            // Dark gradient rising from the bottom so the white label text
            // stays legible over any image, not just dark ones.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Colors.black45, Colors.transparent],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
