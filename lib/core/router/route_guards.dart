import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';
import 'route_names.dart';

/// Centralizes the redirect decision so app_router.dart stays declarative.
/// Returns null when no redirect is needed.
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
    final firebaseAuthState = ref.read(firebaseAuthUserProvider);

    // Firebase itself is still restoring the session.
    if (firebaseAuthState.isLoading) {
      return currentLocation == RouteNames.splash
          ? null
          : RouteNames.splash;
    }

    final firebaseUser = firebaseAuthState.valueOrNull;

    // ------------------------------------------------------------
    // Firebase explicitly says there is NO authenticated user.
    // This is a real logout.
    // ------------------------------------------------------------
    if (firebaseUser == null) {
      final isOnAuthRoute = _authRoutes.contains(currentLocation);

      if (isOnAuthRoute) {
        return null;
      }

      return RouteNames.login;
    }

    // ------------------------------------------------------------
    // Firebase says the user IS authenticated.
    // Now resolve the Firestore profile.
    // ------------------------------------------------------------
    final authState = ref.read(authStateChangesProvider);

    if (authState.isLoading) {
      return currentLocation == RouteNames.splash
          ? null
          : RouteNames.splash;
    }

    final user = authState.valueOrNull;

    // Firebase is authenticated but Firestore profile is not ready.
    // DO NOT send the user to Login.
    if (user == null) {
      return currentLocation == RouteNames.splash
          ? null
          : RouteNames.splash;
    }

    final isOnAuthRoute = _authRoutes.contains(currentLocation);
    final isOnSplash = currentLocation == RouteNames.splash;

    if (isOnSplash || isOnAuthRoute) {
      return _homeForRole(user.role);
    }

    // Email verification.
    final hasVerifiedPhone =
        firebaseUser.providerData.any(
          (provider) => provider.providerId == 'phone',
        );

    final needsEmailVerification =
        user.role == UserRole.customer &&
        firebaseUser.email != null &&
        !firebaseUser.emailVerified &&
        !hasVerifiedPhone;

    if (needsEmailVerification) {
      return currentLocation == RouteNames.verifyEmail
          ? null
          : RouteNames.verifyEmail;
    }

    if (currentLocation == RouteNames.verifyEmail) {
      return _homeForRole(user.role);
    }

    // Role protection.
    final isAdminRoute = currentLocation.startsWith('/admin');
    final isEmployeeRoute = currentLocation.startsWith('/employee');

    if ((isAdminRoute || isEmployeeRoute) && !user.isStaff) {
      return RouteNames.home;
    }

    if (isAdminRoute && user.role == UserRole.employee) {
      return '/employee/home';
    }

    return null;
  }
  String _homeForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return RouteNames.adminDashboard;

      case UserRole.employee:
        return '/employee/home';

      case UserRole.customer:
        return RouteNames.home;
    }
  }
}