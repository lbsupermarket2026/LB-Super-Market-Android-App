import '../../../../orders/domain/entities/order_entity.dart';
import '../entities/sales_bucket_entity.dart';

/// Pure aggregation logic — takes every order and a chosen granularity,
/// returns time-bucketed revenue/order-count. Cancelled orders are
/// excluded from revenue (they were never actually fulfilled) but still
/// tracked as a separate count, so cancellation rate is visible too.
class SalesAggregator {
  static List<SalesBucketEntity> aggregate(List<OrderEntity> orders, SalesGranularity granularity) {
    final now = DateTime.now();
    final buckets = <String, _BucketAccumulator>{};
    final bucketOrder = <String>[];

    void addToBucket(String key, String label, DateTime start, OrderEntity order) {
      final acc = buckets.putIfAbsent(key, () {
        bucketOrder.add(key);
        return _BucketAccumulator(label: label, start: start);
      });
      if (order.status == OrderStatus.cancelled) {
        acc.cancelledCount++;
      } else {
        acc.revenue += order.totalAmount;
        acc.orderCount++;
      }
    }

    for (final order in orders) {
      final d = order.createdAt;

      switch (granularity) {
        case SalesGranularity.hourly:
          // Today only — bucketing all history by hour-of-day would be a
          // huge, not-very-useful number of buckets. This matches how
          // most POS dashboards treat "hourly" as an intraday view.
          if (d.year == now.year && d.month == now.month && d.day == now.day) {
            final key = 'h${d.hour}';
            final label = _hourLabel(d.hour);
            addToBucket(key, label, DateTime(d.year, d.month, d.day, d.hour), order);
          }
          break;

        case SalesGranularity.daily:
          final cutoff = now.subtract(const Duration(days: 14));
          if (d.isAfter(cutoff)) {
            final key = '${d.year}-${d.month}-${d.day}';
            final label = '${d.day}/${d.month}';
            addToBucket(key, label, DateTime(d.year, d.month, d.day), order);
          }
          break;

        case SalesGranularity.weekly:
          final cutoff = now.subtract(const Duration(days: 56));
          if (d.isAfter(cutoff)) {
            final weekStart = d.subtract(Duration(days: d.weekday - 1));
            final key = '${weekStart.year}-w${_weekOfYear(weekStart)}';
            final label = '${weekStart.day}/${weekStart.month}';
            addToBucket(key, label, DateTime(weekStart.year, weekStart.month, weekStart.day), order);
          }
          break;

        case SalesGranularity.monthly:
          final monthsAgo = (now.year - d.year) * 12 + (now.month - d.month);
          if (monthsAgo >= 0 && monthsAgo < 12) {
            final key = '${d.year}-${d.month}';
            final label = _monthLabel(d.month, d.year);
            addToBucket(key, label, DateTime(d.year, d.month), order);
          }
          break;

        case SalesGranularity.quarterly:
          final dQuarter = ((d.month - 1) ~/ 3) + 1;
          final nowQuarter = ((now.month - 1) ~/ 3) + 1;
          final quartersAgo = (now.year - d.year) * 4 + (nowQuarter - dQuarter);
          if (quartersAgo >= 0 && quartersAgo < 8) {
            final key = '${d.year}-q$dQuarter';
            final label = 'Q$dQuarter ${d.year}';
            addToBucket(key, label, DateTime(d.year, (dQuarter - 1) * 3 + 1), order);
          }
          break;

        case SalesGranularity.halfYearly:
          final dHalf = d.month <= 6 ? 1 : 2;
          final nowHalf = now.month <= 6 ? 1 : 2;
          final halvesAgo = (now.year - d.year) * 2 + (nowHalf - dHalf);
          if (halvesAgo >= 0 && halvesAgo < 4) {
            final key = '${d.year}-h$dHalf';
            final label = 'H$dHalf ${d.year}';
            addToBucket(key, label, DateTime(d.year, dHalf == 1 ? 1 : 7), order);
          }
          break;

        case SalesGranularity.yearly:
          final key = '${d.year}';
          final label = '${d.year}';
          addToBucket(key, label, DateTime(d.year), order);
          break;
      }
    }

    final result = bucketOrder
        .map((key) => buckets[key]!)
        .map((acc) => SalesBucketEntity(
              label: acc.label,
              start: acc.start,
              revenue: acc.revenue,
              orderCount: acc.orderCount,
              cancelledCount: acc.cancelledCount,
            ))
        .toList();

    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  static String _hourLabel(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour $period';
  }

  static String _monthLabel(int month, int year) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${names[month - 1]} $year';
  }

  static int _weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSince = date.difference(firstDayOfYear).inDays;
    return (daysSince / 7).ceil();
  }
}

class _BucketAccumulator {
  final String label;
  final DateTime start;
  double revenue = 0;
  int orderCount = 0;
  int cancelledCount = 0;

  _BucketAccumulator({required this.label, required this.start});
}
