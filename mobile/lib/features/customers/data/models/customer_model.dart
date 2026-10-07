import '../../domain/entities/customer_entity.dart';

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

class CustomerModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? notes;
  final int discountPercent;
  final String loyaltyTier;
  final int purchaseCount;
  final double totalSpent;
  final double openDebtBalance;
  final bool isActive;
  final String shopId;
  final DateTime createdAt;
  final List<CustomerDebtModel> debts;

  const CustomerModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.notes,
    this.discountPercent = 0,
    this.loyaltyTier = 'standard',
    this.purchaseCount = 0,
    this.totalSpent = 0,
    this.openDebtBalance = 0,
    this.isActive = true,
    this.shopId = '',
    required this.createdAt,
    this.debts = const [],
  });

  factory CustomerModel.fromApi(Map<String, dynamic> json) {
    final debtsRaw = json['debts'];
    return CustomerModel(
      id: '${json['id'] ?? ''}',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      notes: json['notes']?.toString(),
      discountPercent: _asInt(json['discount_percent']),
      loyaltyTier: json['loyalty_tier']?.toString() ?? 'standard',
      purchaseCount: _asInt(json['purchase_count']),
      totalSpent: _asDouble(json['total_spent']),
      openDebtBalance: _asDouble(json['open_debt_balance']),
      isActive: json['is_active'] != false,
      shopId: '${json['shop_id'] ?? ''}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      debts: debtsRaw is List
          ? debtsRaw
              .whereType<Map>()
              .map((e) =>
                  CustomerDebtModel.fromApi(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  CustomerEntity toEntity() => CustomerEntity(
        id: id,
        name: name,
        email: email,
        phone: phone,
        address: address,
        notes: notes,
        discountPercent: discountPercent,
        loyaltyTier: loyaltyTier,
        purchaseCount: purchaseCount,
        totalSpent: totalSpent,
        openDebtBalance: openDebtBalance,
        isActive: isActive,
        shopId: shopId,
        createdAt: createdAt,
        debts: debts.map((d) => d.toEntity()).toList(),
      );
}

class CustomerDebtModel {
  final String id;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final double amount;
  final double amountPaid;
  final double balance;
  final String status;
  final String? note;
  final DateTime? dueDate;
  final DateTime createdAt;

  const CustomerDebtModel({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.amount,
    required this.amountPaid,
    required this.balance,
    required this.status,
    this.note,
    this.dueDate,
    required this.createdAt,
  });

  factory CustomerDebtModel.fromApi(Map<String, dynamic> json) {
    final customer = json['customer'];
    Map<String, dynamic>? custMap;
    if (customer is Map) {
      custMap = Map<String, dynamic>.from(customer);
    }
    final amount = _asDouble(json['amount']);
    final paid = _asDouble(json['amount_paid']);
    final balance = json.containsKey('balance')
        ? _asDouble(json['balance'], amount - paid)
        : (amount - paid);

    return CustomerDebtModel(
      id: '${json['id'] ?? ''}',
      customerId: '${json['customer_id'] ?? custMap?['id'] ?? ''}',
      customerName: custMap?['name']?.toString(),
      customerPhone: custMap?['phone']?.toString(),
      amount: amount,
      amountPaid: paid,
      balance: balance < 0 ? 0 : balance,
      status: json['status']?.toString() ?? 'open',
      note: json['note']?.toString(),
      dueDate: DateTime.tryParse('${json['due_date'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
          DateTime.now(),
    );
  }

  CustomerDebtEntity toEntity() => CustomerDebtEntity(
        id: id,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        amount: amount,
        amountPaid: amountPaid,
        balance: balance,
        status: status,
        note: note,
        dueDate: dueDate,
        createdAt: createdAt,
      );
}
