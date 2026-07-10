import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'freshcart/lib/app.dart';
import 'core/config/firebase_options.dart';
import 'core/services/cache_service.dart';

/// Default entrypoint — points at whatever DefaultFirebaseOptions
/// resolves to (single-project setup). Once you split dev/staging/prod
/// Firebase projects, use main_dev.dart / main_staging.dart / main_prod.dart
/// instead, each passing a different FirebaseOptions.
Future<void> main() async {
  await bootstrap();
}

Future<void> bootstrap({FirebaseOptions? firebaseOptions}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: firebaseOptions ?? DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence — free read caching + queued writes.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  await CacheService.init();

  // Triggers the OS-native notification permission prompt (system dialog
  // on Android 13+, native alert on iOS) the first time the app launches
  // after install — same as most apps do out of the box. From here on,
  // users manage the permission through their phone's own Settings app,
  // not a custom in-app toggle.
  await FirebaseMessaging.instance.requestPermission();

  // Route uncaught errors to Crashlytics (skip in debug to avoid noise
  // during local development).
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: FreshCartApp()));
}
