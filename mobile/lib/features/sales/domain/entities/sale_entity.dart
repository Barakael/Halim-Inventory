import 'package:equatable/equatable.dart';

import '../../../shops/domain/entities/shop_entity.dart';

class SaleItemEntity extends Equatable {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const SaleItemEntity({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  @override
  List<Object?> get props => [id];
}

class SaleEntity extends Equatable {
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
  final String? customerAddress;
  final String? customerIdType;
  final String serialNumber;
  final String znr;
  final String uin;
  final String verificationCode;
  final double totalExclTax;
  final double totalTax;
  final double amountTendered;
  final double cashChange;
  final String cashierId;
  final String companyId;
  final List<SaleItemEntity> items;
  final DateTime createdAt;
  final ShopEntity? shop;

  const SaleEntity({
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

  @override
  List<Object?> get props => [id, invoiceNo, serialNumber];
}
