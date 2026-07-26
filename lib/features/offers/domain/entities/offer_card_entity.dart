enum OfferTemplate { percentageOff, newArrival, freeDelivery, custom }

extension OfferTemplateX on OfferTemplate {
  String get label {
    switch (this) {
      case OfferTemplate.percentageOff:
        return 'Percentage Off';
      case OfferTemplate.newArrival:
        return 'New Arrival';
      case OfferTemplate.freeDelivery:
        return 'Free Delivery';
      case OfferTemplate.custom:
        return 'Custom';
    }
  }

  static OfferTemplate fromString(String value) {
    return OfferTemplate.values.firstWhere((t) => t.name == value, orElse: () => OfferTemplate.custom);
  }
}

/// A single scrolling promo card on Home — built from a fixed template
/// (layout + color, defined in code) with admin-editable text on top.
/// imageUrl is optional — cards work fine without one (falls back to
/// the template's gradient), but admin can attach a photo to make the
/// card feel less like a plain color block.
class OfferCardEntity {
  final String id;
  final OfferTemplate template;
  final String title;
  final String subtitle;
  final String? highlightText; // e.g. "25" for a percentage-off card
  final String? imageUrl;
  final bool isEnabled;
  final int sortOrder;

  const OfferCardEntity({
    required this.id,
    required this.template,
    required this.title,
    required this.subtitle,
    this.highlightText,
    this.imageUrl,
    required this.isEnabled,
    this.sortOrder = 0,
  });
}
