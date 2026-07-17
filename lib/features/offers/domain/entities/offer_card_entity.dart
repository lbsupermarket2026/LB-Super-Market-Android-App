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
/// (layout + color, defined in code) with admin-editable text on top,
/// so no image upload is required to run a new offer.
class OfferCardEntity {
  final String id;
  final OfferTemplate template;
  final String title;
  final String subtitle;
  final String? highlightText; // e.g. "25" for a percentage-off card
  final bool isEnabled;
  final int sortOrder;

  const OfferCardEntity({
    required this.id,
    required this.template,
    required this.title,
    required this.subtitle,
    this.highlightText,
    required this.isEnabled,
    this.sortOrder = 0,
  });
}
