/// Single source of truth for every Firestore collection/document path.
/// Never hardcode a collection name string anywhere else in the app —
/// always reference this file, so a schema change is a one-file edit.
class FirestorePaths {
  FirestorePaths._();

  // Top-level collections
  static const String users = 'users';
  static const String staffUsers = 'staff_users';
  static const String categories = 'categories';
  static const String products = 'products';
  static const String inventory = 'inventory';
  static const String carts = 'carts';
  static const String orderRequests = 'order_requests';
  static const String orders = 'orders';
  static const String offers = 'offers';
  static const String coupons = 'coupons';
  static const String loyaltyLedger = 'loyalty_ledger';
  static const String notifications = 'notifications';
  static const String salesReportsCache = 'sales_reports_cache';
  static const String supportRequests = 'support_requests';
  static const String adminConfig = 'admin_config';

  // Subcollection names (used under a parent doc reference)
  static const String addressesSubcollection = 'addresses';
  static const String wishlistSubcollection = 'wishlist';
  static const String recentlyViewedSubcollection = 'recentlyViewed';
  static const String reviewsSubcollection = 'reviews';
  static const String invoiceSubcollection = 'invoice';

  // Fixed-ID documents inside admin_config
  static const String adminConfigAppSettings = 'appSettings';
  static const String adminConfigBusinessInfo = 'businessInfo';
  static const String adminConfigBannerHome = 'bannerHome';

  static const String adminConfigTermsConditions = 'termsConditions';
  static const String adminConfigPrivacyPolicy = 'privacyPolicy';
  static const String adminConfigRefundPolicy = 'refundPolicy';
  static const String adminConfigFaqs = 'faqs';
}
