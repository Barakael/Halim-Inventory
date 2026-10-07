class AppConstants {
  AppConstants._();

  static const String appName = 'Tera POS';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int defaultPageSize = 20;
  static const int firstPage = 1;

  // Token
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';

  // Hive boxes
  static const String salesBox = 'sales_cache';
  static const String productsBox = 'products_cache';
  static const String customersBox = 'customers_cache';
  static const String notificationsBox = 'notifications_cache';

  // Tanzania
  static const String currencySymbol = 'TZS';
}
