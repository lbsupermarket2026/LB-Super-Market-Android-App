import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_radii_shadows.dart';

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: baseColor.withOpacity(0.5),
      child: Container(
        width: 150,
        decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadii.card)),
            ),
            const SizedBox(height: 8),
            Container(height: 14, width: 100, color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 8)),
            const SizedBox(height: 6),
            Container(height: 14, width: 60, color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 8)),
          ],
        ),
      ),
    );
  }
}

class CategoryTileSkeleton extends StatelessWidget {
  const CategoryTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: baseColor.withOpacity(0.5),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Container(height: 10, width: 50, color: Colors.white),
        ],
      ),
    );
  }
}
