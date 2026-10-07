import 'package:equatable/equatable.dart';

class CustomerEntity extends Equatable {
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
  final List<CustomerDebtEntity> debts;

  const CustomerEntity({
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

  bool get isTopCustomer =>
      purchaseCount >= 5 || totalSpent >= 300000 || discountPercent > 0;

  @override
  List<Object?> get props => [id, name, discountPercent, openDebtBalance];
}

class CustomerDebtEntity extends Equatable {
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

  const CustomerDebtEntity({
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

  @override
  List<Object?> get props => [id, status, balance];
}

class DebtSummaryEntity {
  final int openCount;
  final double openBalance;
  final List<CustomerEntity> topDebtors;

  const DebtSummaryEntity({
    required this.openCount,
    required this.openBalance,
    this.topDebtors = const [],
  });
}
