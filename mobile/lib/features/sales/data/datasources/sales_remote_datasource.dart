import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/sale_model.dart';

class SalesRemoteDataSource {
  final ApiClient apiClient;
  const SalesRemoteDataSource({required this.apiClient});

  /// Backend returns a JSON array; optional [date] filter (Y-m-d).
  Future<List<SaleModel>> getSales({String? date}) =>
      apiClient.get<List<SaleModel>>(
        endpoint: ApiEndpoints.sales,
        queryParameters: {
          if (date != null && date.isNotEmpty) 'date': date,
        },
        parser: (json) => (json as List<dynamic>)
            .map((e) => SaleModel.fromLaravelJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<SaleModel> getSaleById(String id) =>
      apiClient.get<SaleModel>(
        endpoint: ApiEndpoints.saleById(id),
        parser: (json) =>
            SaleModel.fromLaravelJson(json as Map<String, dynamic>),
      );

  Future<SaleModel> createSale(Map<String, dynamic> data) =>
      apiClient.post<SaleModel>(
        endpoint: ApiEndpoints.sales,
        data: data,
        parser: (json) =>
            SaleModel.fromLaravelJson(json as Map<String, dynamic>),
      );
}
