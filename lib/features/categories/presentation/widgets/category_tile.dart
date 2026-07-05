import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/category_entity.dart';

class CategoryTile extends StatelessWidget {
  final CategoryEntity category;
  final VoidCallback onTap;

  const CategoryTile({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: (category.iconUrl ?? category.imageUrl)?.isNotEmpty == true
                ? CachedNetworkImage(
                    imageUrl: (category.iconUrl ?? category.imageUrl)!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const Icon(Icons.category_outlined),
                  )
                : const Icon(Icons.category_outlined),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
