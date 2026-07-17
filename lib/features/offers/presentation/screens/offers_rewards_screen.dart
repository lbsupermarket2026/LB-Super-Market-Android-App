import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../providers/offer_card_providers.dart';
import '../widgets/offer_card_carousel.dart';

class OffersRewardsScreen extends ConsumerWidget {
  const OffersRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final cardsAsync = ref.watch(enabledOfferCardsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8ED),
      appBar: AppBar(title: const Text('Offers & Rewards')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Points', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        '${user?.loyaltyPoints ?? 0}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.emoji_events_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 40),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          cardsAsync.when(
            data: (cards) {
              if (cards.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyStateWidget(
                    message: 'No active offers right now — check back soon.',
                    icon: Icons.local_offer_outlined,
                  ),
                );
              }
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Current Offers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OfferCardCarousel(cards: cards, height: 160),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl),
              child: EmptyStateWidget(
                message: 'Could not load offers right now.',
                icon: Icons.local_offer_outlined,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
