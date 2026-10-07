import '../../domain/entities/transaction_entity.dart';

class TransactionModel {
  final String id;
  final String? serialNumber;
  final String cashierName;
  final String paymentMethod;
  final double total;
  final String status;
  final DateTime createdAt;
  final String? customerName;
  final List<TransactionItemModel> items;

  TransactionModel({
    required this.id,
    this.serialNumber,
    required this.cashierName,
    required this.paymentMethod,
    required this.total,
    required this.status,
    required this.createdAt,
    this.customerName,
    required this.items,
  });

  factory TransactionModel.fromLaravelJson(Map<String, dynamic> sale) {
    final cashierRaw = sale['cashier'];
    String cashierName = 'Cashier';
    if (cashierRaw is Map) {
      final name = cashierRaw['name']?.toString().trim();
      if (name != null && name.isNotEmpty) cashierName = name;
    } else {
      final fallback = sale['cashier_name']?.toString().trim();
      if (fallback != null && fallback.isNotEmpty) cashierName = fallback;
    }

    final createdRaw = sale['created_at'] ?? sale['createdAt'];
    final createdAt = createdRaw is String
        ? (DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final statusRaw = sale['status']?.toString().trim();
    final status = (statusRaw == null || statusRaw.isEmpty)
        ? 'completed'
        : statusRaw.toLowerCase();

    final serial = sale['serial_number']?.toString() ??
        sale['invoice_no']?.toString() ??
        sale['invoiceNo']?.toString();

    return TransactionModel(
      id: sale['id']?.toString() ?? '',
      serialNumber: serial,
      cashierName: cashierName,
      paymentMethod: sale['payment_method']?.toString() ?? 'cash',
      total: (sale['total'] as num?)?.toDouble() ?? 0.0,
      status: status,
      createdAt: createdAt,
      customerName: sale['customer_name']?.toString(),
      items: _parseItems(sale['items'] as List<dynamic>? ?? []),
    );
  }

  static List<TransactionItemModel> _parseItems(List<dynamic> itemsData) {
    return itemsData.map((item) {
      final m = item as Map<String, dynamic>;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final unit = (m['unit_price'] as num?)?.toDouble() ?? 0.0;
      final sub = (m['subtotal'] as num?)?.toDouble() ?? (unit * qty);
      return TransactionItemModel(
        productName: m['product_name']?.toString() ?? 'Product',
        quantity: qty,
        unitPrice: unit,
        totalPrice: sub,
      );
    }).toList();
  }

  TransactionEntity toEntity() {
    return TransactionEntity(
      id: id,
      serialNumber: serialNumber,
      cashierName: cashierName,
      paymentMethod: paymentMethod,
      total: total,
      status: status,
      createdAt: createdAt,
      customerName: customerName,
      items: items.map((item) => item.toEntity()).toList(),
    );
  }
}

class TransactionItemModel {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  TransactionItemModel({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  TransactionItemEntity toEntity() {
    return TransactionItemEntity(
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
    );
  }
}
