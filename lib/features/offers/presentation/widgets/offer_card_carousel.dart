import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/offer_card_entity.dart';
import 'offer_card_tile.dart';

/// Full-width, one-card-at-a-time carousel — matches how most apps show
/// promo banners (Swiggy/Zomato/Blinkit style), as opposed to the
/// multi-peek AutoScrollRow used for categories/products. Auto-advances
/// on a timer and pauses while someone's actively swiping; shows dot
/// indicators only when there's more than one card.
///
/// NEW: tap-to-expand. First tap on a card grows it to show the full
/// photo (uncropped, no text overlay) instead of navigating straight
/// away — pauses auto-advance while expanded. A second tap on the
/// expanded card is what actually navigates to the Offers page.
class OfferCardCarousel extends StatefulWidget {
  final List<OfferCardEntity> cards;
  final double height;
  final void Function(OfferCardEntity)? onCardTap;

  // FIXED: 150 wasn't tall enough for OfferCardTile's content in
  // the worst case (2-line title + 2-line subtitle) — see the note
  // in offer_card_tile.dart. Matched to the same 172 default.
  const OfferCardCarousel({super.key, required this.cards, this.height = 172, this.onCardTap});

  @override
  State<OfferCardCarousel> createState() => _OfferCardCarouselState();
}

class _OfferCardCarouselState extends State<OfferCardCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;
  bool _isExpanded = false;

  // A meaningfully taller height that still fits comfortably on
  // screen — shows the photo properly without needing a separate
  // fullscreen route just to preview it.
  static const double _expandedHeight = 320;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.cards.length > 1) _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients || widget.cards.isEmpty || _isExpanded) return;
      final next = (_currentPage + 1) % widget.cards.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  void _onCardTap(OfferCardEntity card) {
    if (_isExpanded) {
      // Second tap while already expanded — this is the "take me to
      // the offers page" tap.
      setState(() => _isExpanded = false);
      widget.onCardTap?.call(card);
    } else {
      // First tap — expand in place instead of navigating yet.
      setState(() => _isExpanded = true);
    }
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
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: _isExpanded ? _expandedHeight : widget.height,
          child: PageView.builder(
            controller: _controller,
            // Disabled while expanded — swiping to a different card
            // mid-expansion would be a confusing interaction; collapse
            // first (tap again), then swipe.
            physics: _isExpanded ? const NeverScrollableScrollPhysics() : null,
            itemCount: widget.cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final card = widget.cards[index];
              final isCurrentExpanded = _isExpanded && index == _currentPage;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isCurrentExpanded
                    ? ExpandedOfferPhoto(card: card, onTap: () => _onCardTap(card))
                    : OfferCardTile(card: card, height: widget.height, onTap: () => _onCardTap(card)),
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

/// The expanded state — shows the offer's actual photo uncropped
/// (BoxFit.contain, not cover), with a small "Tap to view offer" hint
/// so the second-tap-navigates behavior is discoverable rather than
/// hidden.
class ExpandedOfferPhoto extends StatelessWidget {
  final OfferCardEntity card;
  final VoidCallback onTap;
  const ExpandedOfferPhoto({super.key, required this.card, required this.onTap});

  bool get _hasUsableImage {
    final url = card.imageUrl;
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasUsableImage)
              CachedNetworkImage(
                imageUrl: card.imageUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
              )
            else
              Center(child: Text(card.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
            Positioned(
              bottom: 10,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tap to view offer', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
