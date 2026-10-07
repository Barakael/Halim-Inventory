// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SaleItemModel _$SaleItemModelFromJson(Map<String, dynamic> json) =>
    SaleItemModel(
      id: json['id'] as String,
      productId: json['productId'] as String,
      product: json['product'] == null
          ? null
          : ProductRefModel.fromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
    );

Map<String, dynamic> _$SaleItemModelToJson(SaleItemModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'productId': instance.productId,
      'product': instance.product,
      'quantity': instance.quantity,
      'unitPrice': instance.unitPrice,
      'subtotal': instance.subtotal,
    };

ProductRefModel _$ProductRefModelFromJson(Map<String, dynamic> json) =>
    ProductRefModel(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$ProductRefModelToJson(ProductRefModel instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

SaleModel _$SaleModelFromJson(Map<String, dynamic> json) => SaleModel(
  id: json['id'] as String,
  invoiceNo: json['invoiceNo'] as String,
  status: json['status'] as String,
  taxType: json['taxType'] as String,
  vatType: json['vatType'] as String,
  paymentMethod: json['paymentMethod'] as String,
  subtotal: (json['subtotal'] as num).toDouble(),
  netAmount: (json['netAmount'] as num).toDouble(),
  totalVat: (json['totalVat'] as num).toDouble(),
  total: (json['total'] as num).toDouble(),
  discount: (json['discount'] as num).toDouble(),
  customerId: json['customerId'] as String?,
  customerName: json['customerName'] as String?,
  customerPhone: json['customerPhone'] as String?,
  cashierId: json['cashierId'] as String,
  companyId: json['companyId'] as String,
  items:
      (json['saleItems'] as List<dynamic>?)
          ?.map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$SaleModelToJson(SaleModel instance) => <String, dynamic>{
  'id': instance.id,
  'invoiceNo': instance.invoiceNo,
  'status': instance.status,
  'taxType': instance.taxType,
  'vatType': instance.vatType,
  'paymentMethod': instance.paymentMethod,
  'subtotal': instance.subtotal,
  'netAmount': instance.netAmount,
  'totalVat': instance.totalVat,
  'total': instance.total,
  'discount': instance.discount,
  'customerId': instance.customerId,
  'customerName': instance.customerName,
  'customerPhone': instance.customerPhone,
  'cashierId': instance.cashierId,
  'companyId': instance.companyId,
  'saleItems': instance.items,
  'createdAt': instance.createdAt.toIso8601String(),
};
