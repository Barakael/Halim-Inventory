import '../entities/shop_entity.dart';

abstract class ShopRepository {
  Future<List<ShopEntity>> getShops();
  Future<ShopEntity> createShop({
    required String name,
    required String address,
    required String phone,
    required String email,
    double taxRate = 0.0,
    String currency = 'TZS',
    required String ownerName,
    required String ownerEmail,
    required String ownerPassword,
  });
  Future<ShopEntity> updateShop({
    required int id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? currency,
    String? status,
  });
  Future<void> deleteShop(int id);
  Future<ShopEntity> getShop(int id);
  /// Owner/cashier shop profile (`GET /settings`).
  Future<ShopEntity?> getCurrentShop();

  /// Owner updates own shop (`PUT /settings`).
  Future<ShopEntity> updateCurrentShop({
    String? name,
    String? address,
    String? phone,
    String? email,
    double? taxRate,
    String? currency,
    String? tin,
    String? vrn,
    String? mobile,
    String? location,
    String? taxOffice,
  });
}
