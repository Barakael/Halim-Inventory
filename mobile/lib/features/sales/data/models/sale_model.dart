import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/sale_entity.dart';
import '../../../shops/domain/entities/shop_entity.dart';
import '../../../shops/data/models/shop_model.dart';

part 'sale_model.g.dart';

@JsonSerializable()
class SaleItemModel {
  final String id;
  final String productId;
  @JsonKey(name: 'product')
  final ProductRefModel? product;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const SaleItemModel({
    required this.id,
    required this.productId,
    this.product,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) =>
      _$SaleItemModelFromJson(json);
  Map<String, dynamic> toJson() => _$SaleItemModelToJson(this);

  SaleItemEntity toEntity() => SaleItemEntity(
        id: id,
        productId: productId,
        productName: product?.name ?? '',
        quantity: quantity,
        unitPrice: unitPrice,
        subtotal: subtotal,
      );
}

@JsonSerializable()
class ProductRefModel {
  final String id;
  final String name;

  const ProductRefModel({required this.id, required this.name});

  factory ProductRefModel.fromJson(Map<String, dynamic> json) =>
      _$ProductRefModelFromJson(json);
  Map<String, dynamic> toJson() => _$ProductRefModelToJson(this);
}

@JsonSerializable()
class SaleModel {
  final String id;
  final String invoiceNo;
  final String status;
  final String taxType;
  final String vatType;
  final String paymentMethod;
  final double subtotal;
  final double netAmount;
  final double totalVat;
  final double total;
  final double discount;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? customerAddress;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? customerIdType;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String serialNumber;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String znr;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String uin;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String verificationCode;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double totalExclTax;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double totalTax;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double amountTendered;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final double cashChange;
  final String cashierId;
  final String companyId;
  @JsonKey(name: 'saleItems', defaultValue: [])
  final List<SaleItemModel> items;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final ShopEntity? shop;
  final DateTime createdAt;

  const SaleModel({
    required this.id,
    required this.invoiceNo,
    required this.status,
    required this.taxType,
    required this.vatType,
    required this.paymentMethod,
    required this.subtotal,
    required this.netAmount,
    required this.totalVat,
    required this.total,
    required this.discount,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerIdType,
    this.serialNumber = '',
    this.znr = '',
    this.uin = '',
    this.verificationCode = '',
    this.totalExclTax = 0,
    this.totalTax = 0,
    this.amountTendered = 0,
    this.cashChange = 0,
    required this.cashierId,
    required this.companyId,
    required this.items,
    required this.createdAt,
    this.shop,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) =>
      _$SaleModelFromJson(json);
  Map<String, dynamic> toJson() => _$SaleModelToJson(this);

  /// Laravel API response (snake_case keys, `items` relation).
  factory SaleModel.fromLaravelJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final itemsRaw = json['items'] as List<dynamic>? ?? [];
    final items = itemsRaw.map((e) {
      final m = e as Map<String, dynamic>;
      final qty = (m['quantity'] as num?)?.toInt() ?? 0;
      final unit = (m['unit_price'] as num?)?.toDouble() ?? 0.0;
      final name = m['product_name']?.toString() ?? '';
      final pid = m['product_id']?.toString() ?? '';
      return SaleItemModel(
        id: m['id']?.toString() ?? '',
        productId: pid,
        product: ProductRefModel(id: pid, name: name),
        quantity: qty,
        unitPrice: unit,
        subtotal: unit * qty,
      );
    }).toList();

    final createdRaw = json['created_at'] ?? json['createdAt'];
    final createdAt = createdRaw is String
        ? (DateTime.tryParse(createdRaw)?.toLocal() ?? DateTime.now())
        : DateTime.now();

    final serial = json['serial_number']?.toString() ?? '';

    ShopEntity? shopEntity;
    final shopRaw = json['shop'];
    if (shopRaw is Map<String, dynamic>) {
      shopEntity = ShopModel.fromApi(shopRaw);
    }

    return SaleModel(
      id: json['id']?.toString() ?? '',
      invoiceNo: serial.isNotEmpty ? serial : (json['id']?.toString() ?? ''),
      status: 'completed',
      taxType: '',
      vatType: '',
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      subtotal: toDouble(json['subtotal']),
      netAmount: toDouble(json['subtotal']),
      totalVat: toDouble(json['total_tax'] ?? json['tax']),
      total: toDouble(json['total']),
      discount: toDouble(json['discount']),
      customerId: json['shop_customer_id']?.toString() ??
          json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      customerAddress: json['customer_address']?.toString(),
      customerIdType: json['customer_id_type']?.toString(),
      serialNumber: serial,
      znr: json['znr']?.toString() ?? '',
      uin: json['uin']?.toString() ?? '',
      verificationCode: json['verification_code']?.toString() ?? '',
      totalExclTax: toDouble(json['total_excl_tax']),
      totalTax: toDouble(json['total_tax'] ?? json['tax']),
      amountTendered: toDouble(json['amount_tendered']),
      cashChange: toDouble(json['change'] ?? json['cash_change']),
      cashierId: json['cashier_id']?.toString() ?? '',
      companyId: json['shop_id']?.toString() ?? '',
      items: items,
      createdAt: createdAt,
      shop: shopEntity,
    );
  }

  SaleEntity toEntity() => SaleEntity(
        id: id,
        invoiceNo: invoiceNo,
        status: status,
        taxType: taxType,
        vatType: vatType,
        paymentMethod: paymentMethod,
        subtotal: subtotal,
        netAmount: netAmount,
        totalVat: totalVat,
        total: total,
        discount: discount,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        customerIdType: customerIdType,
        serialNumber: serialNumber,
        znr: znr,
        uin: uin,
        verificationCode: verificationCode,
        totalExclTax: totalExclTax,
        totalTax: totalTax,
        amountTendered: amountTendered,
        cashChange: cashChange,
        cashierId: cashierId,
        companyId: companyId,
        items: items.map((i) => i.toEntity()).toList(),
        createdAt: createdAt,
        shop: shop,
      );
}
