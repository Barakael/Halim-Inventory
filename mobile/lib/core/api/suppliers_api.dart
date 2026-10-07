import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

class SupplierModel {
  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class SuppliersApi {
  SuppliersApi(this._api);

  final ApiClient _api;

  Future<List<SupplierModel>> getAll({String? search}) async {
    return _api.get<List<SupplierModel>>(
      endpoint: ApiEndpoints.suppliers,
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
      parser: (json) {
        final list = json is List ? json : (json['data'] as List? ?? const []);
        return list
            .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<SupplierModel> create(Map<String, dynamic> data) async {
    return _api.post<SupplierModel>(
      endpoint: ApiEndpoints.suppliers,
      data: data,
      parser: (json) => SupplierModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<SupplierModel> update(int id, Map<String, dynamic> data) async {
    return _api.put<SupplierModel>(
      endpoint: ApiEndpoints.supplierById(id),
      data: data,
      parser: (json) => SupplierModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> delete(int id) async {
    await _api.delete(endpoint: ApiEndpoints.supplierById(id));
  }
}
