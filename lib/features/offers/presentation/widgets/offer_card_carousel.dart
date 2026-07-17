import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/offer_card_entity.dart';
import 'offer_card_tile.dart';

/// Full-width, one-card-at-a-time carousel — matches how most apps show
/// promo banners (Swiggy/Zomato/Blinkit style), as opposed to the
/// multi-peek AutoScrollRow used for categories/products. Auto-advances
/// on a timer and pauses while someone's actively swiping; shows dot
/// indicators only when there's more than one card.
class OfferCardCarousel extends StatefulWidget {
  final List<OfferCardEntity> cards;
  final double height;
  final void Function(OfferCardEntity)? onCardTap;

  const OfferCardCarousel({super.key, required this.cards, this.height = 150, this.onCardTap});

  @override
  State<OfferCardCarousel> createState() => _OfferCardCarouselState();
}

class _OfferCardCarouselState extends State<OfferCardCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.cards.length > 1) _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients || widget.cards.isEmpty) return;
      final next = (_currentPage + 1) % widget.cards.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final card = widget.cards[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OfferCardTile(card: card, onTap: () => widget.onCardTap?.call(card)),
              );
            },
          ),
        ),
        if (widget.cards.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.cards.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
