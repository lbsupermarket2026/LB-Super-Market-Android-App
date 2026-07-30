import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../inventory_mgmt/presentation/providers/admin_inventory_providers.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

class LowStockProductsScreen extends ConsumerWidget {
  const LowStockProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(allProductsAdminProvider);

    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Low Stock Products')),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products: $e')),
        data: (products) {
          final lowStock = products.where((p) => p.isLowStock).toList()
            ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

          if (lowStock.isEmpty) {
            return const Center(child: Text('Nothing is low on stock right now.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: lowStock.length,
            itemBuilder: (context, index) {
              final product = lowStock[index];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: product.primaryImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImage,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.image_outlined, size: 18)),
                            )
                          : Container(color: const Color(0xFFF3F3F3), child: const Icon(Icons.image_outlined, size: 18)),
                    ),
                  ),
                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Threshold: ${product.lowStockThreshold}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _red.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text('${product.stockQty} left', style: const TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
