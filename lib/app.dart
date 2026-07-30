import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class FreshCartApp extends ConsumerStatefulWidget {
  const FreshCartApp({super.key});

  @override
  ConsumerState<FreshCartApp> createState() => _FreshCartAppState();
}

class _FreshCartAppState extends ConsumerState<FreshCartApp> {
  @override
  void initState() {
    super.initState();
    // Deferred to post-frame — the router provider needs to have been
    // read by build() at least once first, and this keeps push
    // notification setup from ever blocking or delaying first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(appRouterProvider);
      PushNotificationService.instance.init(router);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
