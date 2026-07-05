class AppConstants {
  AppConstants._();

  static const String appName = 'LB Super Market';

  // Pagination
  static const int defaultPageSize = 20;
  static const int recentlyViewedCap = 20;

  // Roles (matches staff_users.role and implicit users role)
  static const String roleAdmin = 'admin';
  static const String roleEmployee = 'employee';
  static const String roleCustomer = 'customer';

  // Order request modes (order_requests.mode)
  static const String modeTypedList = 'typed_list';
  static const String modeWhatsapp = 'whatsapp';
  static const String modePhotoUpload = 'photo_upload';
  static const String modeBrowseSelect = 'browse_select';

  // Order request status
  static const String requestStatusSubmitted = 'submitted';
  static const String requestStatusCallPending = 'call_pending';
  static const String requestStatusConfirmed = 'confirmed_with_customer';
  static const String requestStatusConverted = 'converted_to_order';
  static const String requestStatusRejected = 'rejected';

  // Payment methods (orders.paymentMethod)
  static const String paymentCOD = 'COD';
  static const String paymentUPI = 'UPI';
  static const String paymentCardOnDelivery = 'CARD_ON_DELIVERY';

  // Payment status (orders.paymentStatus)
  static const String paymentStatusPending = 'pending';
  static const String paymentStatusAwaitingVerification = 'awaiting_verification';
  static const String paymentStatusVerified = 'verified';
  static const String paymentStatusFailed = 'failed';
  static const String paymentStatusCollected = 'collected';

  // Order status (orders.orderStatus)
  static const String orderStatusPlaced = 'placed';
  static const String orderStatusConfirmed = 'confirmed';
  static const String orderStatusPacked = 'packed';
  static const String orderStatusOutForDelivery = 'out_for_delivery';
  static const String orderStatusDelivered = 'delivered';
  static const String orderStatusCancelled = 'cancelled';

  // Order approval status
  static const String approvalPending = 'pending';
  static const String approvalAccepted = 'accepted';
  static const String approvalDenied = 'denied';
}
