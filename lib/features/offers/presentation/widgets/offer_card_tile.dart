import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/offer_card_entity.dart';

/// Renders one offer card in the style baked into its template —
/// admin only ever supplies the text, never the layout/colors, so
/// every card stays visually consistent no matter who fills it in.
///
/// Sets its own height by default (150) rather than relying on
/// whatever wraps it to provide bounded constraints — this widget
/// used to require a StackFit.expand parent with an explicit height,
/// and every place that got that wrong (a dialog preview, a plain
/// ListView item) crashed the whole surrounding layout instead of
/// just this card. Self-sizing means it can't happen again regardless
/// of where this gets used next. Pass [height] to override when a
/// caller genuinely wants a different size (the Home carousel does).
class OfferCardTile extends StatelessWidget {
  final OfferCardEntity card;
  final VoidCallback? onTap;
  final double height;

  // FIXED: default height 150 wasn't tall enough — with a 2-line
  // title (fontSize 20) + 2-line subtitle (fontSize 13) + the icon
  // row + 18px padding on all sides, real content could exceed the
  // available space by ~14px on longer offer text, causing a bottom
  // overflow. Bumped to 172 to comfortably fit the worst case
  // (both title and subtitle wrapping to their max 2 lines).
  const OfferCardTile({super.key, required this.card, this.onTap, this.height = 172});

  ({List<Color> gradient, Color fg, IconData icon}) _styleFor(OfferTemplate template) {
    switch (template) {
      case OfferTemplate.percentageOff:
        return (gradient: const [Color(0xFFE53935), Color(0xFFFF8A65)], fg: Colors.white, icon: Icons.sell_outlined);
      case OfferTemplate.newArrival:
        return (gradient: const [Color(0xFF1B5E20), Color(0xFF66BB6A)], fg: Colors.white, icon: Icons.fiber_new_outlined);
      case OfferTemplate.freeDelivery:
        return (gradient: const [Color(0xFF0D47A1), Color(0xFF42A5F5)], fg: Colors.white, icon: Icons.local_shipping_outlined);
      case OfferTemplate.custom:
        return (gradient: const [Color(0xFFEF6C00), Color(0xFFFFB74D)], fg: Colors.white, icon: Icons.local_offer_outlined);
    }
  }

  /// Only trusts imageUrl if it's genuinely a usable http(s) URL — a
  /// partially-failed upload (a real thing we've hit — Storage rules
  /// blocking the write) could otherwise leave a blank or malformed
  /// string in this field, and CachedNetworkImage can throw
  /// synchronously on a URL that isn't parseable at all, which is a
  /// different failure mode than "image failed to load" and doesn't
  /// go through errorWidget.
  bool get _hasUsableImage {
    final url = card.imageUrl;
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(card.template);
    final hasImage = _hasUsableImage;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: style.gradient.first.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: card.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: style.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: style.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
              ),
            // A dark gradient scrim over a photo keeps the white text
            // legible regardless of what's in the image — without it,
            // a bright photo could make title/subtitle unreadable.
            if (hasImage)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black26, Colors.black54],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: Icon(style.icon, color: style.fg, size: 20),
                      ),
                      if (card.highlightText?.isNotEmpty == true) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            card.template == OfferTemplate.percentageOff ? '${card.highlightText}% OFF' : card.highlightText!,
                            style: TextStyle(color: style.fg, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: style.fg, fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: style.fg.withOpacity(0.9), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
