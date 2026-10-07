import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

class ShopCategory {
  const ShopCategory({
    required this.id,
    required this.name,
    this.parentId,
  });

  final int id;
  final String name;
  final int? parentId;

  bool get isRoot => parentId == null;

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    return ShopCategory(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      parentId: (json['parent_id'] as num?)?.toInt(),
    );
  }
}

class CategoriesApi {
  CategoriesApi(this._api);

  final ApiClient _api;

  Future<List<ShopCategory>> getAll() async {
    return _api.get<List<ShopCategory>>(
      endpoint: ApiEndpoints.categories,
      parser: (json) {
        final list = json is List ? json : (json['data'] as List? ?? const []);
        return list
            .map((e) => ShopCategory.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<ShopCategory> create(String name, {int? parentId}) async {
    return _api.post<ShopCategory>(
      endpoint: ApiEndpoints.categories,
      data: {
        'name': name.trim(),
        if (parentId != null) 'parent_id': parentId,
      },
      parser: (json) => ShopCategory.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> delete(int id) async {
    await _api.delete(endpoint: ApiEndpoints.categoryById(id));
  }
}
