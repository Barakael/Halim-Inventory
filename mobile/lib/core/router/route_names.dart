/// Route paths aligned with `frontend/src/App.tsx` (same segments & role access).
class RouteNames {
  RouteNames._();

  static const String home = '/';
  static const String login = '/login';

  static const String dashboard = '/dashboard';
  static const String pos = '/pos';
  static const String inventory = '/inventory';
  static const String purchases = '/purchases';
  static const String reports = '/reports';

  static const String users = '/users';
  static const String shops = '/shops';
  static const String staff = '/staff';
  static const String customers = '/customers';
  static const String transactions = '/transactions';
  static const String settings = '/settings';

  /// History / manual sales (not in web sidebar; used from POS and dashboard).
  static const String sales = '/sales';
  static const String createSale = '/sales/create';

  static String saleDetail(String id) => '/sales/$id';
}
