import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/signup_screen.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/products/presentation/screens/category_detail_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
import 'route_guards.dart';
import 'route_names.dart';

/// Bridges Riverpod provider updates into a Listenable GoRouter can use.
/// Deliberately driven by the SAME authStateChangesProvider that
/// RouteGuard.redirect() reads — using a separate raw FirebaseAuth stream
/// here (as an earlier version of this file did) creates a race: two
/// independent subscriptions to the same underlying stream can resolve
/// in the wrong order, leaving the redirect stuck evaluating a stale
/// "still loading" state indefinitely (splash screen never leaves).
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authStateChangesProvider, (_, __) => notifier.notify());
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final guard = RouteGuard(ref);
  final refreshNotifier = ref.watch(_routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => guard.redirect(state.matchedLocation),
    routes: [
      GoRoute(path: RouteNames.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: RouteNames.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: RouteNames.signup, builder: (context, state) => const SignupScreen()),
      GoRoute(path: RouteNames.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),

      GoRoute(path: RouteNames.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: RouteNames.categories, builder: (context, state) => const CategoriesScreen()),
      GoRoute(
        path: '/category/:categoryId',
        builder: (context, state) => CategoryDetailScreen(
          categoryId: state.pathParameters['categoryId']!,
          categoryName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/product/:productId',
        builder: (context, state) => ProductDetailScreen(productId: state.pathParameters['productId']!),
      ),

      GoRoute(path: RouteNames.adminDashboard, builder: (context, state) => const AdminDashboardScreen()),

      // Remaining routes (categories, product detail, cart, checkout,
      // orders, wishlist, profile, admin sub-sections) are added as each
      // feature module is built — the guard above already accounts for
      // any '/admin/**' path being staff-only.
    ],
  );
});
