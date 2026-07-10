import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/category_entity.dart';

/// Compact circular badge for horizontal scrollers (Home screen). Same
/// visual language as the full CategoryCard grid on the Categories tab —
/// white ring, soft shadow, hardcoded colors so it never flips dark in
/// system dark mode, matching the (light-themed) website.
class CategoryTile extends StatelessWidget {
  final CategoryEntity category;
  final VoidCallback onTap;

  const CategoryTile({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.iconUrl ?? category.imageUrl;

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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
