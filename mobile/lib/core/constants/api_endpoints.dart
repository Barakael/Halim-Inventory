/// Paths are relative to [RestClient] base URL, which must be the API root
/// (e.g. `http://host:8000/api`). Do not include `/api` again in each path.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';

  // Dashboard
  static const String dashboard = '/dashboard';

  // Users (super_admin)
  static const String users = '/users';
  static String userById(String id) => '/users/$id';

  // Shops (super_admin)
  static const String shops = '/shops';
  static String shopById(String id) => '/shops/$id';

  // Branches (owner)
  static const String branches = '/branches';
  static String branchById(String id) => '/branches/$id';

  // Subscriptions (owner / admin)
  static const String subscriptions = '/subscriptions';
  static const String subscriptionPayments = '/subscription-payments';

  // Staff (owner)
  static const String staff = '/staff';
  static String staffById(String id) => '/staff/$id';

  // Customers & debts (owner)
  static const String customers = '/customers';
  static String customerById(String id) => '/customers/$id';
  static String customerLoyaltyRefresh(String id) =>
      '/customers/$id/loyalty/refresh';
  static const String debts = '/debts';
  static const String debtsSummary = '/debts/summary';
  static String debtPayments(String id) => '/debts/$id/payments';
  static String debtWriteOff(String id) => '/debts/$id/write-off';

  // Products / inventory
  static const String products = '/products';
  static String productById(String id) => '/products/$id';
  static String productImage(String id) => '/products/$id/image';
  static const String categories = '/categories';
  static String categoryById(int id) => '/categories/$id';

  // Purchases / suppliers (owner inventory gate)
  static const String suppliers = '/suppliers';
  static String supplierById(int id) => '/suppliers/$id';
  static const String purchases = '/purchases';
  static String purchaseById(int id) => '/purchases/$id';
  static String purchaseReceive(int id) => '/purchases/$id/receive';
  static String purchaseCancel(int id) => '/purchases/$id/cancel';

  // Sales
  static const String sales = '/sales';
  static String saleById(String id) => '/sales/$id';

  // Shop settings (owner)
  static const String settings = '/settings';
}
