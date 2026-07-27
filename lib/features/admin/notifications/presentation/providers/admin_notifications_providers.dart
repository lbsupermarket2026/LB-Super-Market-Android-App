import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/admin_notifications_datasource.dart';
import '../../domain/entities/admin_notification_entity.dart';

final adminNotificationsDataSourceProvider = Provider<AdminNotificationsDataSource>((ref) {
  return AdminNotificationsDataSource();
});

final adminNotificationsProvider = StreamProvider.autoDispose<List<AdminNotificationEntity>>((ref) {
  return ref.watch(adminNotificationsDataSourceProvider).watchAll();
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(adminNotificationsProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isRead).length;
});
