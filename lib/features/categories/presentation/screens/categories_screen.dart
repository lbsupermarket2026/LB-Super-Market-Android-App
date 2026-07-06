import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../providers/category_providers.dart';
import '../widgets/category_tile.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search products',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) => categories.isEmpty
            ? const EmptyStateWidget(message: 'No categories available yet.', icon: Icons.category_outlined)
            : GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 100,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.8,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return CategoryTile(
                    category: category,
                    onTap: () => context.push('/category/${category.id}', extra: category.name),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load categories.',
          onRetry: () => ref.invalidate(topLevelCategoriesProvider),
        ),
      ),
    );
  }
}
