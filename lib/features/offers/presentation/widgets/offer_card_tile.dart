import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/offer_card_entity.dart';

/// Renders one offer card in the style baked into its template —
/// admin only ever supplies the text, never the layout/colors, so
/// every card stays visually consistent no matter who fills it in.
/// Always sized by the caller (full-width in the carousel) rather than
/// choosing its own width, so it works the same on Home and the
/// Offers screen.
class OfferCardTile extends StatelessWidget {
  final OfferCardEntity card;
  final VoidCallback? onTap;

  const OfferCardTile({super.key, required this.card, this.onTap});

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

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(card.template);
    final hasImage = card.imageUrl?.isNotEmpty == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
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
