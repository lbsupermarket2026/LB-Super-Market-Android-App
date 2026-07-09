import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/dev/mock_product_seeder.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../providers/category_providers.dart';
import '../widgets/category_card.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      // Soft cream tint, echoing the website's hero-section background —
      // scoped to this screen only via Scaffold's own backgroundColor,
      // not a global theme change.
      backgroundColor: const Color(0xFFF6F8ED),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Two-tone heading + underline — same treatment as
                        // the website's "Shop by Category" section title.
                        // Hardcoded colors (not theme.colorScheme) so this
                        // always reads correctly even when the phone is in
                        // system dark mode — this screen is meant to always
                        // look like the (light-themed) website.
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                            children: const [
                              TextSpan(text: 'Shop by '),
                              TextSpan(text: 'Category', style: TextStyle(color: Color(0xFFEF6C00))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(width: 56, height: 3, color: const Color(0xFFEF6C00)),
                        const SizedBox(height: 6),
                        Text(
                          'Explore our wide range of products',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.black87),
                      tooltip: 'Search products',
                      onPressed: () => context.push('/search'),
                    ),
                  ),
                  // Debug-only — never shows in a release build. One tap
                  // seeds a handful of realistic mock products into every
                  // existing category, for regular setup/testing.
                  if (kDebugMode) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        icon: const Icon(Icons.science_outlined, color: Colors.black87),
                        tooltip: 'Seed mock products (debug only)',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(const SnackBar(content: Text('Seeding mock products…')));
                          try {
                            final count = await MockProductSeeder.seedAll(ref);
                            for (final category in categoriesAsync.valueOrNull ?? []) {
                              ref.invalidate(categoryProductCountProvider(category.id));
                            }
                            messenger.showSnackBar(SnackBar(content: Text('Seeded $count mock products.')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Seeding failed: $e')));
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) => categories.isEmpty
                    ? const EmptyStateWidget(message: 'No categories available yet.', icon: Icons.category_outlined)
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.78,
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
