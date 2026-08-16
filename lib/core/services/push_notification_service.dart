import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

/// Wires up Firebase Cloud Messaging end to end: permission request,
/// token registration/refresh against the signed-in user's Firestore
/// doc, a visible notification while the app is in the foreground
/// (FCM shows nothing on its own in that state — that's normal
/// platform behavior, not a bug), and routing to the right screen
/// when someone taps a notification either from the system tray or
/// from a cold start.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  GoRouter? _router;

  static const _channel = AndroidNotificationChannel(
    'freshcart_default',
    'FreshCart Notifications',
    description: 'Order updates, offers, and delivery assignments',
    importance: Importance.high,
  );

  Future<void> init(GoRouter router) async {
    _router = router;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.subscribeToTopic('new_offers');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _navigateForPayload(payload);
      },
    );

    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Foreground: FCM delivers the message but shows nothing itself —
    // this is what actually puts a notification in the tray while the
    // app is open, same as background/terminated get automatically.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // App was in background, user tapped the system notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _navigateForMessage(message));

    // App was fully closed, user tapped the system notification to
    // open it — the message that caused the open, if any.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _navigateForMessage(initialMessage);

    // Token can rotate at any time (reinstall, app data clear, backup
    // restore) — must keep Firestore in sync whenever that happens,
    // not just once at sign-in.
    _messaging.onTokenRefresh.listen(_saveToken);

    // Re-registers on every sign-in/out — a device's token needs to
    // move to whichever account is currently using it, and needs
    // removing when that account signs out so a shared/reused device
    // doesn't keep getting notifications for someone no longer using it.
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await _messaging.getToken();
        if (token != null) await _saveToken(token);

        final staffDoc = await FirebaseFirestore.instance.collection('staff_users').doc(user.uid).get();
        if (staffDoc.exists && staffDoc.data()?['role'] == 'admin') {
          await _messaging.subscribeToTopic('admin_alerts');
        } else {
          // Harmless no-op if not currently subscribed — covers an
          // admin account being demoted, or a non-admin signing into
          // a device that previously had an admin account on it.
          await _messaging.unsubscribeFromTopic('admin_alerts');
        }
      }
    });
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    // FIXED: this used to write to BOTH 'users' and 'staff_users'
    // unconditionally with set(..., merge: true) — which CREATES
    // whichever doc doesn't already exist rather than being a
    // harmless no-op. For a staff account, that silently recreated
    // users/{uid} (with only an fcmTokens field, no role/name) on
    // every token save — i.e. every app launch and every token
    // refresh, not just login — which shadowed the real staff_users
    // doc in resolveUserProfile()'s users-first check and caused
    // staff accounts to keep getting misidentified as customers even
    // right after the stray doc was manually deleted.
    //
    // Fix: check staff_users first (same pattern as updateProfile()
    // and the fixed touchLastLogin()) and only write to the
    // collection the account actually belongs to.
    final staffRef = firestore.collection('staff_users').doc(uid);
    final staffDoc = await staffRef.get();
    final targetRef = staffDoc.exists ? staffRef : firestore.collection('users').doc(uid);
    await targetRef.set(
      {'fcmTokens': FieldValue.arrayUnion([token])},
      SetOptions(merge: true),
    );
  }

  /// Called on sign-out so a device stops receiving pushes meant for
  /// whichever account just logged off it.
  Future<void> clearTokenOnSignOut(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return;
    final firestore = FirebaseFirestore.instance;
    // Same fix as _saveToken — only touch the collection this
    // account actually lives in, never both unconditionally.
    final staffRef = firestore.collection('staff_users').doc(uid);
    final staffDoc = await staffRef.get();
    final targetRef = staffDoc.exists ? staffRef : firestore.collection('users').doc(uid);
    await targetRef.set(
      {'fcmTokens': FieldValue.arrayRemove([token])},
      SetOptions(merge: true),
    );

    // NEW: removing the token only stops DIRECT per-device pushes —
    // topic subscriptions (admin_alerts, new_offers) are completely
    // separate from that token array and live independently at the
    // FCM/device level. Without this, a device that was subscribed to
    // a topic while signed in (e.g. an admin's admin_alerts, or a
    // customer's new_offers) stayed subscribed after logging out,
    // meaning it kept receiving those pushes for whichever account
    // used to be on it, even with nobody signed in anymore.
    // Unconditional on every sign-out regardless of prior role, so
    // there's nothing left over no matter which topics that account
    // happened to be subscribed to.
    await _messaging.unsubscribeFromTopic('admin_alerts');
    await _messaging.unsubscribeFromTopic('new_offers');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _encodePayload(message.data),
    );
  }

  String _encodePayload(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final orderId = data['orderId'] as String? ?? '';
    return '$type|$orderId';
  }

  void _navigateForMessage(RemoteMessage message) => _routeFor(message.data['type'] as String?, message.data['orderId'] as String?);

  void _navigateForPayload(String payload) {
    final parts = payload.split('|');
    _routeFor(parts.isNotEmpty ? parts[0] : null, parts.length > 1 ? parts[1] : null);
  }

  void _routeFor(String? type, String? orderId) {
    if (_router == null) return;
    switch (type) {
      case 'order_status':
        if (orderId != null && orderId.isNotEmpty) _router!.push('/orders/$orderId');
        break;
      case 'new_offer':
        _router!.push('/offers');
        break;
      case 'order_assigned':
        _router!.push('/employee/home');
        break;
      case 'new_order':
        _router!.push('/admin/orders');
        break;
      case 'low_stock':
        _router!.push('/admin/inventory');
        break;
      default:
        // Unrecognized/no type — land on notifications so it's never
        // a dead tap, even for a type this client doesn't know about yet.
        _router!.push('/notifications');
    }
  }
}

/// Must be a top-level function (not a class method) — this is a
/// platform requirement for background message handling, since it
/// runs in a separate isolate that doesn't have access to any of the
/// app's normal state.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Deliberately empty: FCM shows the system notification for
  // background/terminated automatically as long as the payload
  // includes a "notification" block (which every notification this
  // app sends does) — this handler only needs to exist so the SDK has
  // somewhere to route the isolate, not to do anything itself.
  if (kDebugMode) {
    debugPrint('Background message received: ${message.messageId}');
  }
}
