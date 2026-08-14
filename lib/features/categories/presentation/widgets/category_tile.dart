import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/category_entity.dart';
import '../../../../core/theme/app_semantic_colors.dart';

/// Compact circular badge for horizontal scrollers (Home screen). The
/// icon circle itself is deliberately always white in every theme
/// (matches the light-themed website design), but the name text below
/// it sits on the PAGE background, not on that white circle — so it
/// needs to stay theme-adaptive or it goes invisible in dark mode.
class CategoryTile extends StatelessWidget {
  final CategoryEntity category;
  final VoidCallback onTap;

  const CategoryTile({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.iconUrl ?? category.imageUrl;
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            padding: const EdgeInsets.all(6),
            child: ClipOval(
              child: imageUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.category_outlined, color: Color(0xFF2E7D32)),
                    )
                  : const Icon(Icons.category_outlined, color: Color(0xFF2E7D32)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // FIXED: was hardcoded Colors.black87 — this text sits
              // on the page background (not the always-white icon
              // circle above it), so it went invisible in dark mode.
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
