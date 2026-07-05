import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';
import 'route_names.dart';

/// Centralizes the redirect decision so app_router.dart stays declarative.
/// Returns null when no redirect is needed (stay on the requested route).
class RouteGuard {
  final Ref ref;
  const RouteGuard(this.ref);

  static const _authRoutes = {
    RouteNames.login,
    RouteNames.signup,
    RouteNames.forgotPassword,
    RouteNames.otp,
  };

  String? redirect(String currentLocation) {
    final authState = ref.read(authStateChangesProvider);

    // While the very first auth-state emission is pending, keep the user
    // on splash rather than bouncing them to login and back.
    if (authState.isLoading) {
      return currentLocation == RouteNames.splash ? null : RouteNames.splash;
    }

    final user = authState.valueOrNull;
    final isLoggedIn = user != null;
    final isOnAuthRoute = _authRoutes.contains(currentLocation);
    final isOnSplash = currentLocation == RouteNames.splash;

    if (!isLoggedIn) {
      // Not signed in: only allow auth routes.
      if (isOnAuthRoute) return null;
      return RouteNames.login;
    }

    // Signed in but currently sitting on splash/auth routes: send them
    // to the correct home for their role.
    if (isOnSplash || isOnAuthRoute) {
      return _homeForRole(user.role);
    }

    // Signed in, on some other route: block customers from admin routes.
    final isAdminRoute = currentLocation.startsWith('/admin');
    if (isAdminRoute && !user.isStaff) {
      return RouteNames.home;
    }

    return null; // no redirect needed
  }

  String _homeForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.employee:
        return RouteNames.adminDashboard;
      case UserRole.customer:
        return RouteNames.home;
    }
  }
}
