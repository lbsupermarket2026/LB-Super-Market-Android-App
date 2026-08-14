import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../domain/entities/offer_card_entity.dart';
import '../providers/offer_card_providers.dart';
import '../widgets/offer_card_tile.dart';
import '../widgets/offer_card_carousel.dart' show ExpandedOfferPhoto;

class OffersRewardsScreen extends ConsumerWidget {
  const OffersRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final cardsAsync = ref.watch(enabledOfferCardsProvider);

    return Scaffold(
      backgroundColor: colors.surface,
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
            itemBuilder: (context, index) => _ExpandableOfferListTile(card: cards[index]),
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

/// NEW: same tap-to-expand-then-navigate interaction as the Home
/// screen's carousel, so offer cards behave consistently wherever
/// they appear — first tap shows the full uncropped photo in place,
/// second tap (while expanded) navigates to that offer's products.
class _ExpandableOfferListTile extends StatefulWidget {
  final OfferCardEntity card;
  const _ExpandableOfferListTile({required this.card});

  @override
  State<_ExpandableOfferListTile> createState() => _ExpandableOfferListTileState();
}

class _ExpandableOfferListTileState extends State<_ExpandableOfferListTile> {
  bool _isExpanded = false;
  static const double _collapsedHeight = 172;
  static const double _expandedHeight = 320;

  void _onTap() {
    if (_isExpanded) {
      context.push('/offer-products/${widget.card.id}', extra: widget.card.title);
      setState(() => _isExpanded = false);
    } else {
      setState(() => _isExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: _isExpanded ? _expandedHeight : _collapsedHeight,
      child: _isExpanded
          ? ExpandedOfferPhoto(card: widget.card, onTap: _onTap)
          : OfferCardTile(card: widget.card, height: _collapsedHeight, onTap: _onTap),
    );
  }
}
