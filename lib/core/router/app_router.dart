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
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/offers/presentation/screens/offers_rewards_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/products/presentation/screens/category_detail_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../widgets/bottom_nav_shell.dart';
import 'route_guards.dart';
import 'route_names.dart';
import '../../features/business_info/presentation/about_us_screen.dart';
import '../../features/legal/presentation/screens/static_content_screen.dart';
import '../../features/legal/presentation/screens/faqs_screen.dart';
import '../../features/legal/presentation/providers/legal_providers.dart';
import '../../features/addresses/presentation/screens/addresses_screen.dart';
import '../../features/wishlist/presentation/screens/wishlist_screen.dart';

/// Bridges Riverpod provider updates into a Listenable GoRouter can use.
/// Deliberately driven by the SAME authStateChangesProvider that
/// RouteGuard.redirect() reads — using a separate raw FirebaseAuth stream
/// here creates a race between two independent subscriptions to the same
/// underlying stream, which can leave redirect stuck on a stale "loading"
/// read forever (this was the splash-screen-stuck bug).
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

      // 5 primary tabs — persistent bottom nav, each keeps its own stack.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => BottomNavShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.categories, builder: (context, state) => const CategoriesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.orders, builder: (context, state) => const OrdersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.offers, builder: (context, state) => const OffersRewardsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.profile, builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),

      // Full-screen pushes that sit ABOVE the bottom nav (no tab bar).
      GoRoute(path: RouteNames.search, builder: (context, state) => const SearchScreen()),
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

      GoRoute(path: RouteNames.addresses, builder: (context, state) => const AddressesScreen()),
      GoRoute(path: RouteNames.wishlist, builder: (context, state) => const WishlistScreen()),
      GoRoute(path: '/about-us', builder: (context, state) => const AboutUsScreen()),
      GoRoute(path: '/faqs', builder: (context, state) => const FaqsScreen()),
      GoRoute(
        path: '/terms-conditions',
        builder: (context, state) => StaticContentScreen(title: 'Terms & Conditions', provider: termsConditionsProvider),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => StaticContentScreen(title: 'Privacy Policy', provider: privacyPolicyProvider),
      ),
      GoRoute(
        path: '/refund-policy',
        builder: (context, state) => StaticContentScreen(title: 'Refund Policy', provider: refundPolicyProvider),
      ),


      GoRoute(path: RouteNames.adminDashboard, builder: (context, state) => const AdminDashboardScreen()),

      // Remaining routes (cart, checkout, wishlist, admin sub-sections)
      // are added as each feature module is built — the guard above
      // already accounts for any '/admin/**' path being staff-only.
    ],
  );
});
