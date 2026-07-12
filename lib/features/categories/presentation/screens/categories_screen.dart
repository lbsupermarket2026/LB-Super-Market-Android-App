import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../providers/category_providers.dart';
import '../widgets/category_card.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 4),
              child: Text('All categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/search'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E2D6))),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text('Search categories', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) => categories.isEmpty
                    ? const EmptyStateWidget(message: 'No categories available yet.', icon: Icons.category_outlined)
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 1.35,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return CategoryCard(
                            category: category,
                            index: index,
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
            ),
          ],
        ),
      ),
    );
  }
}
