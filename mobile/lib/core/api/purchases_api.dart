import 'dart:convert';
import 'dart:io';

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
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: json['product_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PurchasePaymentModel {
  const PurchasePaymentModel({
    required this.id,
    required this.amount,
    this.paidAt,
    this.paymentMethod,
    this.notes,
    this.receiptUrl,
  });

  final int id;
  final double amount;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? notes;
  final String? receiptUrl;

  factory PurchasePaymentModel.fromJson(Map<String, dynamic> json) {
    return PurchasePaymentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      paymentMethod: json['payment_method']?.toString(),
      notes: json['notes']?.toString(),
      receiptUrl: json['receipt_url']?.toString(),
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
    this.paymentType,
    this.paymentStatus,
    this.amountPaid = 0,
    this.remaining = 0,
    this.deliveredByName,
    this.deliveredByPhone,
    this.productNames = const [],
    this.totalQty = 0,
    this.items = const [],
    this.payments = const [],
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
  final String? paymentType;
  final String? paymentStatus;
  final double amountPaid;
  final double remaining;
  final String? deliveredByName;
  final String? deliveredByPhone;
  final List<String> productNames;
  final int totalQty;
  final List<PurchaseItemModel> items;
  final List<PurchasePaymentModel> payments;

  bool get isDraft => status == 'draft';
  bool get isReceived => status == 'received';
  bool get isCancelled => status == 'cancelled';
  bool get canLipa => remaining > 0.009 && !isCancelled;

  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'];
    final creator = json['creator'];
    final itemsRaw = json['items'];
    final paymentsRaw = json['payments'];
    final namesRaw = json['product_names'];
    final subtotal = (json['subtotal'] as num?)?.toDouble() ?? 0;
    final paid = (json['amount_paid'] as num?)?.toDouble() ?? 0;
    final remaining = json['remaining'] != null
        ? (json['remaining'] as num).toDouble()
        : (subtotal - paid).clamp(0, double.infinity);
    return PurchaseModel(
      id: (json['id'] as num).toInt(),
      status: json['status']?.toString() ?? 'draft',
      subtotal: subtotal,
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
      paymentType: json['payment_type']?.toString(),
      paymentStatus: json['payment_status']?.toString(),
      amountPaid: paid,
      remaining: remaining.toDouble(),
      deliveredByName: json['delivered_by_name']?.toString(),
      deliveredByPhone: json['delivered_by_phone']?.toString(),
      productNames: namesRaw is List
          ? namesRaw.map((e) => e.toString()).toList()
          : const [],
      totalQty: (json['total_qty'] as num?)?.toInt() ?? 0,
      items: itemsRaw is List
          ? itemsRaw
              .map((e) =>
                  PurchaseItemModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      payments: paymentsRaw is List
          ? paymentsRaw
              .map((e) =>
                  PurchasePaymentModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

class SupplierStatementRow {
  const SupplierStatementRow({
    required this.type,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.receiptUrl,
    this.deliveredByName,
    this.deliveredByPhone,
    this.products,
    this.quantity,
    this.jumla,
    this.malipo,
  });

  final String type;
  final String date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String? receiptUrl;
  final String? deliveredByName;
  final String? deliveredByPhone;
  final String? products;
  final int? quantity;
  final double? jumla;
  final double? malipo;

  factory SupplierStatementRow.fromJson(Map<String, dynamic> json) {
    return SupplierStatementRow(
      type: json['type']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ??
          (json['deni'] as num?)?.toDouble() ??
          0,
      receiptUrl: json['receipt_url']?.toString(),
      deliveredByName: json['delivered_by_name']?.toString(),
      deliveredByPhone: json['delivered_by_phone']?.toString(),
      products: json['products']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt(),
      jumla: (json['jumla'] as num?)?.toDouble() ??
          (json['debit'] as num?)?.toDouble(),
      malipo: (json['malipo'] as num?)?.toDouble() ??
          (json['credit'] as num?)?.toDouble(),
    );
  }

  String get titleLine {
    if (type == 'payment') {
      return description.isNotEmpty ? description : 'Malipo';
    }
    final parts = <String>[];
    if (products != null && products!.isNotEmpty) parts.add(products!);
    if (quantity != null && quantity! > 0) parts.add('×$quantity');
    if (parts.isEmpty && description.isNotEmpty) return description;
    return parts.isEmpty ? 'Manunuzi' : parts.join(' ');
  }

  String get subtitleLine {
    final bits = <String>[date];
    if (deliveredByName != null && deliveredByName!.isNotEmpty) {
      bits.add(deliveredByName!);
    }
    if (deliveredByPhone != null && deliveredByPhone!.isNotEmpty) {
      bits.add(deliveredByPhone!);
    }
    return bits.join(' · ');
  }
}

class SupplierStatementModel {
  const SupplierStatementModel({
    required this.from,
    required this.to,
    required this.openingBalance,
    required this.closingBalance,
    required this.deliveries,
    required this.paid,
    required this.remaining,
    required this.rows,
    this.supplierName,
  });

  final String from;
  final String to;
  final double openingBalance;
  final double closingBalance;
  final double deliveries;
  final double paid;
  final double remaining;
  final List<SupplierStatementRow> rows;
  final String? supplierName;

  factory SupplierStatementModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] is Map
        ? json['totals'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final supplier = json['supplier'];
    final rowsRaw = json['rows'];
    return SupplierStatementModel(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
      closingBalance: (json['closing_balance'] as num?)?.toDouble() ?? 0,
      deliveries: (totals['deliveries'] as num?)?.toDouble() ?? 0,
      paid: (totals['paid'] as num?)?.toDouble() ?? 0,
      remaining: (totals['remaining'] as num?)?.toDouble() ?? 0,
      supplierName: supplier is Map ? supplier['name']?.toString() : null,
      rows: rowsRaw is List
          ? rowsRaw
              .map((e) =>
                  SupplierStatementRow.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
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

  Future<List<PurchasePaymentModel>> listPayments(int purchaseId) async {
    return _api.get<List<PurchasePaymentModel>>(
      endpoint: ApiEndpoints.purchasePayments(purchaseId),
      parser: (json) {
        final list = json is List ? json : (json['data'] as List? ?? const []);
        return list
            .map((e) =>
                PurchasePaymentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      },
    );
  }

  Future<PurchasePaymentModel> pay({
    required int purchaseId,
    required double amount,
    String? paymentMethod,
    String? notes,
    DateTime? paidAt,
    File? receiptFile,
  }) async {
    final payload = <String, dynamic>{
      'amount': amount,
      'payment_method': paymentMethod ?? 'cash',
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (paidAt != null) 'paid_at': paidAt.toIso8601String().split('T').first,
    };
    if (receiptFile != null && await receiptFile.exists()) {
      final bytes = await receiptFile.readAsBytes();
      payload['receipt_base64'] = base64Encode(bytes);
      payload['receipt_filename'] = receiptFile.path.split(RegExp(r'[/\\]')).last;
    }
    return _api.post<PurchasePaymentModel>(
      endpoint: ApiEndpoints.purchasePayments(purchaseId),
      data: payload,
      parser: (json) {
        final map = json is Map<String, dynamic>
            ? (json['data'] is Map
                ? json['data'] as Map<String, dynamic>
                : json)
            : <String, dynamic>{};
        return PurchasePaymentModel.fromJson(map);
      },
    );
  }

  Future<SupplierStatementModel> supplierStatement({
    required int supplierId,
    String preset = 'month',
    String? from,
    String? to,
  }) async {
    return _api.get<SupplierStatementModel>(
      endpoint: ApiEndpoints.supplierStatement(supplierId),
      queryParameters: {
        if (from != null && to != null) ...{'from': from, 'to': to},
        if (from == null || to == null) 'preset': preset,
      },
      parser: (json) {
        final map = json is Map<String, dynamic>
            ? (json['data'] is Map && json['rows'] == null
                ? json['data'] as Map<String, dynamic>
                : json)
            : <String, dynamic>{};
        return SupplierStatementModel.fromJson(map);
      },
    );
  }
}
