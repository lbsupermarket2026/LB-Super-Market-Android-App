import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolves to true only after a fixed minimum delay — used purely to
/// guarantee the splash illustration is actually seen, even when
/// authStateChangesProvider resolves near-instantly from a cached
/// session. RouteGuard checks this alongside authState.isLoading so
/// it won't redirect off splash until BOTH are ready.
final splashMinimumDurationProvider = FutureProvider<bool>((ref) async {
  await Future.delayed(const Duration(milliseconds: 1200));
  return true;
});