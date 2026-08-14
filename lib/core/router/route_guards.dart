import 'package:firebase_auth/firebase_auth.dart' as fb;
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
    // ignore: avoid_print
    print(
        '[DEBUG redirect] called for currentLocation=$currentLocation isLoading=${authState.isLoading} hasValue=${authState.hasValue} value=${authState.valueOrNull}');

    // While the very first auth-state emission is pending, keep the user
    // on splash rather than bouncing them to login and back.
    if (authState.isLoading) {
      // ignore: avoid_print
      print('[DEBUG redirect] STILL LOADING - staying on/going to splash');
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

    // Email/password accounts must verify before using the app — but
    // only customer accounts. Staff (admin/employee) accounts are
    // created directly through Employee Management, not public
    // self-signup, so there's no spam/fake-account risk to guard
    // against here — and an admin locked out of their own dashboard
    // because their account predates this feature is strictly worse
    // than the problem verification was meant to solve. Phone accounts
    // have no email at all, so this only applies when one's on file.
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    final hasVerifiedPhone = firebaseUser?.providerData.any(
      (provider) => provider.providerId == 'phone',
    ) ??
    false;

    final needsEmailVerification =
        user.role == UserRole.customer &&
        firebaseUser != null &&
        firebaseUser.email != null &&
        !firebaseUser.emailVerified &&
        !hasVerifiedPhone;
    if (needsEmailVerification) {
      return currentLocation == RouteNames.verifyEmail ? null : RouteNames.verifyEmail;
    }
    if (currentLocation == RouteNames.verifyEmail) {
      return _homeForRole(user.role);
    }

    // Signed in, on some other route: block customers from admin/employee
    // routes, and keep employees off the full admin dashboard — they get
    // their own simpler "my deliveries" screen instead.
    final isAdminRoute = currentLocation.startsWith('/admin');
    final isEmployeeRoute = currentLocation.startsWith('/employee');
    if ((isAdminRoute || isEmployeeRoute) && !user.isStaff) {
      return RouteNames.home;
    }
    if (isAdminRoute && user.role == UserRole.employee) {
      return '/employee/home';
    }

    return null; // no redirect needed
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
