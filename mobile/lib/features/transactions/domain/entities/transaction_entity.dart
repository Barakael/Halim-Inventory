import 'package:equatable/equatable.dart';

class TransactionEntity extends Equatable {
  final String id;
  final String? serialNumber;
  final String cashierName;
  final String paymentMethod;
  final double total;
  final String status;
  final DateTime createdAt;
  final String? customerName;
  final List<TransactionItemEntity> items;

  const TransactionEntity({
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

  String get displayRef {
    final serial = serialNumber?.trim();
    if (serial != null && serial.isNotEmpty) return serial;
    return '#$id';
  }

  @override
  List<Object?> get props => [
        id,
        serialNumber,
        cashierName,
        paymentMethod,
        total,
        status,
        createdAt,
        customerName,
        items,
      ];
}

class TransactionItemEntity extends Equatable {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const TransactionItemEntity({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  @override
  List<Object?> get props => [productName, quantity, unitPrice, totalPrice];
}
