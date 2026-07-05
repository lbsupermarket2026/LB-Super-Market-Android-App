import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

/// Shown briefly while authStateChangesProvider resolves its first value.
/// The router redirect logic moves the user on from here automatically —
/// this screen never navigates itself.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(AppConstants.appName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
