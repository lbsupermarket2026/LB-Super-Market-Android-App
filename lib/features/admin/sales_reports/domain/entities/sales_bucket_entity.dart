enum SalesGranularity { hourly, daily, weekly, monthly, quarterly, halfYearly, yearly }

extension SalesGranularityX on SalesGranularity {
  String get label {
    switch (this) {
      case SalesGranularity.hourly:
        return 'Hourly (Today)';
      case SalesGranularity.daily:
        return 'Daily';
      case SalesGranularity.weekly:
        return 'Weekly';
      case SalesGranularity.monthly:
        return 'Monthly';
      case SalesGranularity.quarterly:
        return 'Quarterly';
      case SalesGranularity.halfYearly:
        return 'Half-Yearly';
      case SalesGranularity.yearly:
        return 'Yearly';
    }
  }
}

class SalesBucketEntity {
  final String label;
  final DateTime start;
  final double revenue;
  final int orderCount;
  final int cancelledCount;

  const SalesBucketEntity({
    required this.label,
    required this.start,
    required this.revenue,
    required this.orderCount,
    required this.cancelledCount,
  });
}
