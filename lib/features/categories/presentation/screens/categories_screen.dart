import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../../domain/entities/category_entity.dart';
import '../providers/category_providers.dart';
import '../widgets/category_card.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isTileView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(topLevelCategoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('All categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
                  // Toggles between the image-tile grid and a compact
                  // list layout — list is handy once there are enough
                  // categories that scanning names quickly matters more
                  // than seeing each one's photo.
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: IconButton(
                      icon: Icon(_isTileView ? Icons.view_list_outlined : Icons.grid_view_outlined, size: 20),
                      tooltip: _isTileView ? 'Switch to list view' : 'Switch to tile view',
                      onPressed: () => setState(() => _isTileView = !_isTileView),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E2D6)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search categories',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade600),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  final filtered = _query.isEmpty
                      ? categories
                      : categories.where((c) => c.name.toLowerCase().contains(_query)).toList();

                  if (filtered.isEmpty) {
                    return EmptyStateWidget(
                      message: _query.isEmpty ? 'No categories available yet.' : 'No categories match "$_query".',
                      icon: Icons.category_outlined,
                    );
                  }

                  return _isTileView
                      ? GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 1.35,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final category = filtered[index];
                            return CategoryCard(
                              category: category,
                              index: index,
                              onTap: () => context.push('/category/${category.id}', extra: category.name),
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _CategoryListRow(category: filtered[index]),
                        );
                },
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

class _CategoryListRow extends StatelessWidget {
  final CategoryEntity category;
  const _CategoryListRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.imageUrl ?? category.iconUrl;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/category/${category.id}', extra: category.name),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: imageUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.category_outlined, color: Colors.black38)),
                        )
                      : Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.category_outlined, color: Colors.black38)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(category.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
