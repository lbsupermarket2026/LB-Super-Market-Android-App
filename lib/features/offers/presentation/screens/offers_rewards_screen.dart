import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

/// Placeholder — full Offers banners + Coupons + Loyalty ledger module
/// is built after Cart/Checkout, since coupons apply at checkout and
/// loyalty points are earned from real orders.
class OffersRewardsScreen extends ConsumerWidget {
  const OffersRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offers & Rewards')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(AppSpacing.md),
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
          const Expanded(
            child: EmptyStateWidget(
              message: 'Offers and coupons will appear here soon.',
              icon: Icons.local_offer_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
