import '../constants/api_endpoints.dart';
import '../api/api_service.dart';

class SalesApi {
  final ApiService _apiService;

  SalesApi(this._apiService);

  /// Backend: optional `date` (Y-m-d); default window is last 30 days.
  Future<List<dynamic>> getSales({String? date}) async {
    final result = await _apiService.get<dynamic>(
      ApiEndpoints.sales,
      queryParameters: {
        if (date != null && date.isNotEmpty) 'date': date,
      },
    );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) {
        if (data is List) return data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          return data['data'] as List<dynamic>;
        }
        return <dynamic>[];
      },
    );
  }

  Future<Map<String, dynamic>> getSale(String id) async {
    final result = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.saleById(id),
    );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }

  /// Body: `{ "payment_method": "cash"|"card"|"mobile", "items": [{ "product_id", "quantity" }] }`
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    final result = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.sales,
      data: saleData,
    );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }
}
