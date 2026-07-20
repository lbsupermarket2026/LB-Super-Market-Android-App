import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../providers/offer_card_providers.dart';
import '../widgets/offer_card_tile.dart';

class OffersRewardsScreen extends ConsumerWidget {
  const OffersRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(enabledOfferCardsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: const Text('Offers & Rewards')),
      body: cardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return const EmptyStateWidget(
              message: 'No active offers right now — check back soon.',
              icon: Icons.local_offer_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => OfferCardTile(card: cards[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyStateWidget(
          message: 'Could not load offers right now.',
          icon: Icons.local_offer_outlined,
        ),
      ),
    );
  }
}
