import '../constants/api_endpoints.dart';
import '../api/api_service.dart';

class ProductsApi {
  final ApiService _apiService;

  ProductsApi(this._apiService);

  Future<List<dynamic>> getProducts() async {
    final result = await _apiService.get<dynamic>(ApiEndpoints.products);

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

  Future<Map<String, dynamic>> getProduct(String id) async {
    final result = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.productById(id),
    );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }

  /// Backend: `GET /products?barcode=` returns a single product object.
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final result = await _apiService.get<dynamic>(
      ApiEndpoints.products,
      queryParameters: {'barcode': barcode},
    );

    return result.fold(
      (failure) => null,
      (data) {
        if (data is Map<String, dynamic>) return data;
        return null;
      },
    );
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> productData) async {
    final result = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.products,
      data: productData,
    );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }

  Future<Map<String, dynamic>> updateProduct(
    String id,
    Map<String, dynamic> productData,
  ) async {
    final result = await _apiService.put<Map<String, dynamic>>(
      ApiEndpoints.productById(id),
      data: productData,
    );

    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }

  Future<void> deleteProduct(String id) async {
    final result = await _apiService.delete<dynamic>(
      ApiEndpoints.productById(id),
    );

    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {},
    );
  }

  Future<Map<String, dynamic>> uploadImage(String id, String filePath) async {
    final result = await _apiService.upload<Map<String, dynamic>>(
      ApiEndpoints.productImage(id),
      filePath: filePath,
      fieldName: 'image',
    );
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }

  /// No dedicated categories endpoint; inventory UI can derive locally if needed.
  Future<List<String>> getCategories() async => <String>[];

  /// Stock changes go through product update (`PUT /products/{id}`).
  Future<Map<String, dynamic>> updateStock(String id, int quantity) async {
    return updateProduct(id, {'stock': quantity});
  }
}
