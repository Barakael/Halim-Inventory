import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customers_repository.dart';
import '../models/customer_model.dart';

class CustomersRepositoryImpl implements CustomersRepository {
  final ApiClient _api;

  CustomersRepositoryImpl(this._api);

  Map<String, dynamic> _asMap(dynamic json) {
    if (json is Map<String, dynamic>) {
      if (json['data'] is Map<String, dynamic>) {
        return json['data'] as Map<String, dynamic>;
      }
      return json;
    }
    throw Exception('Invalid response');
  }

  List<dynamic> _asList(dynamic json) {
    if (json is List) return json;
    if (json is Map && json['data'] is List) return json['data'] as List;
    return const [];
  }

  @override
  Future<List<CustomerEntity>> getCustomers({
    String? search,
    bool topCustomers = false,
  }) async {
    final raw = await _api.get<dynamic>(
      endpoint: ApiEndpoints.customers,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (topCustomers) 'top_customers': 1,
      },
      parser: (j) => j,
    );
    return _asList(raw)
        .whereType<Map>()
        .map((e) => CustomerModel.fromApi(Map<String, dynamic>.from(e)).toEntity())
        .toList();
  }

  @override
  Future<CustomerEntity> getCustomer(String id) async {
    final raw = await _api.get<dynamic>(
      endpoint: ApiEndpoints.customerById(id),
      parser: (j) => j,
    );
    return CustomerModel.fromApi(_asMap(raw)).toEntity();
  }

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) async {
    final raw = await _api.post<dynamic>(
      endpoint: ApiEndpoints.customers,
      data: data,
      parser: (j) => j,
    );
    return CustomerModel.fromApi(_asMap(raw)).toEntity();
  }

  @override
  Future<CustomerEntity> updateCustomer(
    String id,
    Map<String, dynamic> data,
  ) async {
    final raw = await _api.put<dynamic>(
      endpoint: ApiEndpoints.customerById(id),
      data: data,
      parser: (j) => j,
    );
    return CustomerModel.fromApi(_asMap(raw)).toEntity();
  }

  @override
  Future<void> deleteCustomer(String id) async {
    await _api.delete(endpoint: ApiEndpoints.customerById(id));
  }

  @override
  Future<CustomerEntity> refreshLoyalty(String id) async {
    final raw = await _api.post<dynamic>(
      endpoint: ApiEndpoints.customerLoyaltyRefresh(id),
      parser: (j) => j,
    );
    return CustomerModel.fromApi(_asMap(raw)).toEntity();
  }

  @override
  Future<List<CustomerDebtEntity>> getDebts({
    String? status,
    String? customerId,
  }) async {
    final raw = await _api.get<dynamic>(
      endpoint: ApiEndpoints.debts,
      queryParameters: {
        if (status != null) 'status': status,
        if (customerId != null) 'customer_id': customerId,
      },
      parser: (j) => j,
    );
    return _asList(raw)
        .whereType<Map>()
        .map((e) =>
            CustomerDebtModel.fromApi(Map<String, dynamic>.from(e)).toEntity())
        .toList();
  }

  @override
  Future<DebtSummaryEntity> getDebtSummary() async {
    final raw = await _api.get<dynamic>(
      endpoint: ApiEndpoints.debtsSummary,
      parser: (j) => j,
    );
    final map = _asMap(raw);
    final debtors = (map['top_debtors'] is List)
        ? (map['top_debtors'] as List)
            .whereType<Map>()
            .map((e) =>
                CustomerModel.fromApi(Map<String, dynamic>.from(e)).toEntity())
            .toList()
        : <CustomerEntity>[];
    return DebtSummaryEntity(
      openCount: _asInt(map['open_count']),
      openBalance: _asDouble(map['open_balance']),
      topDebtors: debtors,
    );
  }

  int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  double _asDouble(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  @override
  Future<CustomerDebtEntity> createDebt(Map<String, dynamic> data) async {
    final raw = await _api.post<dynamic>(
      endpoint: ApiEndpoints.debts,
      data: data,
      parser: (j) => j,
    );
    return CustomerDebtModel.fromApi(_asMap(raw)).toEntity();
  }

  @override
  Future<CustomerDebtEntity> recordPayment(
    String debtId, {
    required double amount,
    String? note,
  }) async {
    final raw = await _api.post<dynamic>(
      endpoint: ApiEndpoints.debtPayments(debtId),
      data: {
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      parser: (j) => j,
    );
    return CustomerDebtModel.fromApi(_asMap(raw)).toEntity();
  }
}
