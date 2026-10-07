import '../entities/shop_entity.dart';

abstract class OwnerSettingsRepository {
  Future<ShopEntity?> getCurrentShop();
  Future<List<BranchEntity>> getBranches();
  Future<BranchEntity> createBranch({
    required String name,
    required String address,
    String? phone,
  });
  Future<void> deleteBranch(int id);
  Future<SubscriptionEntity> getSubscription();
}

class BranchEntity {
  final int id;
  final String name;
  final String address;
  final String? phone;

  BranchEntity({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
  });
}

class SubscriptionEntity {
  final String planName;
  final double price;
  final String status;
  final String nextDueDate;
  final List<PaymentHistoryItem> paymentHistory;

  SubscriptionEntity({
    required this.planName,
    required this.price,
    required this.status,
    required this.nextDueDate,
    required this.paymentHistory,
  });
}

class PaymentHistoryItem {
  final String date;
  final double amount;
  final String status;

  PaymentHistoryItem({
    required this.date,
    required this.amount,
    required this.status,
  });
}
