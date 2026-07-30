import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/customer_notifications_datasource.dart';
import '../../domain/entities/customer_notification_entity.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';

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

/// Combines personal (order updates) and broadcast (new offers) into
/// one sorted list — kept as two separate underlying queries since
/// Firestore can't cleanly express "uid == mine OR uid is null" in a
/// single query, but the screen just wants one merged feed.
final customerNotificationsProvider = Provider.autoDispose<List<CustomerNotificationEntity>>((ref) {
  final personal = ref.watch(_personalNotificationsProvider).valueOrNull ?? [];
  final broadcast = ref.watch(_broadcastNotificationsProvider).valueOrNull ?? [];
  final combined = [...personal, ...broadcast];
  combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return combined;
});

final customerUnreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(customerNotificationsProvider).where((n) => !n.isRead).length;
});