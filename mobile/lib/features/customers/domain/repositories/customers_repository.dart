import '../../domain/entities/customer_entity.dart';

abstract class CustomersRepository {
  Future<List<CustomerEntity>> getCustomers({
    String? search,
    bool topCustomers = false,
  });

  Future<CustomerEntity> getCustomer(String id);

  Future<CustomerEntity> createCustomer(Map<String, dynamic> data);

  Future<CustomerEntity> updateCustomer(String id, Map<String, dynamic> data);

  Future<void> deleteCustomer(String id);

  Future<CustomerEntity> refreshLoyalty(String id);

  Future<List<CustomerDebtEntity>> getDebts({String? status, String? customerId});

  Future<DebtSummaryEntity> getDebtSummary();

  Future<CustomerDebtEntity> createDebt(Map<String, dynamic> data);

  Future<CustomerDebtEntity> recordPayment(
    String debtId, {
    required double amount,
    String? note,
  });
}
