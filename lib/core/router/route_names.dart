class RouteNames {
  RouteNames._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String forgotPassword = '/auth/forgot-password';
  static const String otp = '/auth/otp';

  static const String home = '/home';
  static const String categories = '/categories';
  static const String cart = '/cart';
  static const String orders = '/orders';
  static const String profile = '/profile';

  static const String productDetail = '/product/:productId';
  static const String categoryDetail = '/category/:categoryId';

  static const String checkout = '/checkout';
  static const String checkoutAddress = '/checkout/address';
  static const String checkoutPayment = '/checkout/payment';
  static const String checkoutReview = '/checkout/review';
  static const String checkoutConfirmation = '/checkout/confirmation/:orderId';

  static const String orderDetail = '/orders/:orderId';
  static const String wishlist = '/wishlist';

  static const String adminDashboard = '/admin/dashboard';
  static const String adminLogin = '/admin/login';
}
