import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges a Stream (e.g. FirebaseAuth.authStateChanges()) into a
/// Listenable that GoRouter's `refreshListenable` can use to re-run
/// redirect logic whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
