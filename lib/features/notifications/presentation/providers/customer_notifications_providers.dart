import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/customer_notifications_datasource.dart';
import '../../domain/entities/customer_notification_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../authentication/domain/entities/user_entity.dart';

final customerNotificationsDataSourceProvider = Provider<CustomerNotificationsDataSource>((ref) {
  return CustomerNotificationsDataSource();
});

final _personalNotificationsProvider = StreamProvider.autoDispose<List<CustomerNotificationEntity>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(customerNotificationsDataSourceProvider).watchPersonal(uid);
});

final _broadcastNotificationsProvider = StreamProvider.autoDispose<List<CustomerNotificationEntity>>((ref) {
  return ref.watch(customerNotificationsDataSourceProvider).watchBroadcast();
});

/// Combines personal (order updates / delivery assignments) and
/// broadcast (new offers) into one sorted list — kept as two separate
/// underlying queries since Firestore can't cleanly express "uid ==
/// mine OR uid is null" in a single query.
///
/// FIXED: broadcast notifications were being merged in for EVERY
/// signed-in user regardless of role — this screen is shared between
/// customers and employees, so an employee ended up seeing every
/// offer broadcast in their notification list alongside their actual
/// delivery assignments. Offers are customer-only; employees should
/// only ever see their personal feed (which naturally only contains
/// order_assigned entries for them, since nothing else ever writes a
/// notification with an employee's uid).
final customerNotificationsProvider = Provider.autoDispose<List<CustomerNotificationEntity>>((ref) {
  final personal = ref.watch(_personalNotificationsProvider).valueOrNull ?? [];
  final user = ref.watch(currentUserProvider);
  final isCustomer = user != null && user.role == UserRole.customer;

  final combined = <CustomerNotificationEntity>[
    ...personal,
    if (isCustomer) ...ref.watch(_broadcastNotificationsProvider).valueOrNull ?? [],
  ];
  combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return combined;
});

final customerUnreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(customerNotificationsProvider).where((n) => !n.isRead).length;
});
