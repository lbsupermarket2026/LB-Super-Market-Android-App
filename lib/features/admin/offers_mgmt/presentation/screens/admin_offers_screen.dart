import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../offers/domain/entities/offer_card_entity.dart';
import '../providers/admin_offer_card_providers.dart';
import '../widgets/offer_card_form_dialog.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

class AdminOffersScreen extends ConsumerWidget {
  const AdminOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(allOfferCardsAdminProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: const Text('Home Offer Cards')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        onPressed: () => showDialog(context: context, builder: (_) => const OfferCardFormDialog()),
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load offer cards: $e')),
        data: (cards) {
          if (cards.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No offer cards yet. Tap "Add Card" to create one from a template — it\'ll show as a scrolling card on the customer Home screen once enabled.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            itemCount: cards.length,
            itemBuilder: (context, index) {
              final card = cards[index];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(card.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${card.template.label} • ${card.subtitle}'),
                  onTap: () => showDialog(context: context, builder: (_) => OfferCardFormDialog(existing: card)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: card.isEnabled,
                        activeColor: _green,
                        onChanged: (v) => ref.read(offerCardMutationProvider.notifier).setEnabled(card.id, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: _red),
                        onPressed: () => _confirmDelete(context, ref, card),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, OfferCardEntity card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this offer card?'),
        content: Text('"${card.title}" will be removed from Home immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(offerCardMutationProvider.notifier).delete(card.id);
    }
  }
}
