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
/// Tap-to-expand. First tap on a card grows it to show the full photo
/// (uncropped, no text overlay) instead of navigating straight away —
/// pauses auto-advance while expanded. A second tap on the expanded
/// card is what actually navigates to the Offers page.
class OfferCardCarousel extends StatefulWidget {
  final List<OfferCardEntity> cards;
  final double height;
  final void Function(OfferCardEntity)? onCardTap;

  const OfferCardCarousel({super.key, required this.cards, this.height = 172, this.onCardTap});

  @override
  State<OfferCardCarousel> createState() => _OfferCardCarouselState();
}

class _OfferCardCarouselState extends State<OfferCardCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;
  bool _isExpanded = false;

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
      setState(() => _isExpanded = false);
      widget.onCardTap?.call(card);
    } else {
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
        // FIXED: was AnimatedContainer with a hardcoded expanded
        // height (320) — squeezing every photo into that fixed box
        // regardless of its actual proportions, which is exactly
        // what produced the black letterboxing bars (BoxFit.contain
        // inside a size that doesn't match the image's real aspect
        // ratio). AnimatedSize instead animates to whatever height
        // the CURRENT child naturally wants — the collapsed tile's
        // own fixed height, or the expanded photo's real aspect
        // ratio (see ExpandedOfferPhoto below) — so the card always
        // matches the actual image, no bars, no cropping.
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: SizedBox(
            height: _isExpanded ? null : widget.height,
            child: PageView.builder(
              controller: _controller,
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

/// The expanded state — shows the offer's actual photo uncropped, at
/// its OWN real aspect ratio (not squeezed into a fixed box), with a
/// small "Tap to view offer" hint so the second-tap-navigates
/// behavior is discoverable rather than hidden.
///
/// FIXED: previously used BoxFit.contain inside a fixed-height
/// container — any photo whose proportions didn't match that box
/// showed with black bars above/below (or left/right) it, exactly
/// like a letterboxed video. This resolves the image's REAL width/
/// height first, then sizes the whole card to that exact ratio via
/// AspectRatio — the image fills the entire card edge to edge, no
/// bars, regardless of whether the photo is square, portrait,
/// landscape, or a screenshot with odd proportions.
class ExpandedOfferPhoto extends StatefulWidget {
  final OfferCardEntity card;
  final VoidCallback onTap;
  const ExpandedOfferPhoto({super.key, required this.card, required this.onTap});

  @override
  State<ExpandedOfferPhoto> createState() => _ExpandedOfferPhotoState();
}

class _ExpandedOfferPhotoState extends State<ExpandedOfferPhoto> {
  double? _aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  bool get _hasUsableImage {
    final url = widget.card.imageUrl;
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  void initState() {
    super.initState();
    if (_hasUsableImage) _resolveAspectRatio();
  }

  void _resolveAspectRatio() {
    final provider = CachedNetworkImageProvider(widget.card.imageUrl!);
    _stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (mounted && height > 0) {
        setState(() => _aspectRatio = width / height);
      }
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // While the real ratio is still resolving (or if there's no
    // usable image at all), fall back to a sensible default rather
    // than collapsing to zero height.
    final ratio = _aspectRatio ?? (4 / 3);

    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: ratio,
        child: Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black12,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasUsableImage)
                CachedNetworkImage(
                  imageUrl: widget.card.imageUrl!,
                  // FIXED: BoxFit.cover, not .contain — now that the
                  // OUTER container is already sized to the image's
                  // exact aspect ratio, cover fills it completely
                  // with zero extra space to letterbox in the first
                  // place (cover and contain become equivalent once
                  // the container ratio already matches the image).
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
                )
              else
                Center(child: Text(widget.card.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
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
      ),
    );
  }
}
