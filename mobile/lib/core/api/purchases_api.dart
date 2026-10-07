import '../constants/api_endpoints.dart';
import '../network/api_client.dart';

class PurchaseItemModel {
  const PurchaseItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.lineTotal,
  });

  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final double unitCost;
  final double lineTotal;

  factory PurchaseItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num).toInt(),
      productName: json['product_name']?.toString() ?? '',
      quantity: (json['quantity'] as num).toInt(),
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PurchaseModel {
  const PurchaseModel({
    required this.id,
    required this.status,
    required this.subtotal,
    this.supplierId,
    this.supplierName,
    this.reference,
    this.notes,
    this.purchasedAt,
    this.receivedAt,
    this.creatorName,
    this.items = const [],
  });

  final int id;
  final String status;
  final double subtotal;
  final int? supplierId;
  final String? supplierName;
  final String? reference;
  final String? notes;
  final DateTime? purchasedAt;
  final DateTime? receivedAt;
  final String? creatorName;
  final List<PurchaseItemModel> items;

  bool get isDraft => status == 'draft';
  bool get isReceived => status == 'received';
  bool get isCancelled => status == 'cancelled';

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'];
    final creator = json['creator'];
    final itemsRaw = json['items'];
    return PurchaseModel(
      id: (json['id'] as num).toInt(),
      status: json['status']?.toString() ?? 'draft',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      supplierId: (json['supplier_id'] as num?)?.toInt() ??
          (supplier is Map ? (supplier['id'] as num?)?.toInt() : null),
      supplierName: supplier is Map
          ? supplier['name']?.toString()
          : json['supplier_name']?.toString(),
      reference: json['reference']?.toString(),
      notes: json['notes']?.toString(),
      purchasedAt: _parseDate(json['purchased_at']),
      receivedAt: _parseDate(json['received_at']),
      creatorName: creator is Map ? creator['name']?.toString() : null,
      items: itemsRaw is List
          ? itemsRaw
              .map((e) =>
                  PurchaseItemModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

class PurchasesApi {
  PurchasesApi(this._api);

  final ApiClient _api;

  Future<List<PurchaseModel>> getAll({
    String? status,
    int? supplierId,
    String? search,
    String? from,
    String? to,
  }) async {
    return _api.get<List<PurchaseModel>>(
      endpoint: ApiEndpoints.purchases,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (supplierId != null) 'supplier_id': supplierId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
      parser: (json) {
        final list = json is List ? json : (json['data'] as List? ?? const []);
        return list
            .map((e) => PurchaseModel.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<PurchaseModel> getById(int id) async {
    return _api.get<PurchaseModel>(
      endpoint: ApiEndpoints.purchaseById(id),
      parser: (json) => PurchaseModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PurchaseModel> create(Map<String, dynamic> data) async {
    return _api.post<PurchaseModel>(
      endpoint: ApiEndpoints.purchases,
      data: data,
      parser: (json) => PurchaseModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PurchaseModel> update(int id, Map<String, dynamic> data) async {
    return _api.put<PurchaseModel>(
      endpoint: ApiEndpoints.purchaseById(id),
      data: data,
      parser: (json) => PurchaseModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PurchaseModel> receive(int id) async {
    return _api.post<PurchaseModel>(
      endpoint: ApiEndpoints.purchaseReceive(id),
      data: const {},
      parser: (json) => PurchaseModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PurchaseModel> cancel(int id) async {
    return _api.post<PurchaseModel>(
      endpoint: ApiEndpoints.purchaseCancel(id),
      data: const {},
      parser: (json) => PurchaseModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
