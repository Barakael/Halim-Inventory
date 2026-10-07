import '../../features/shops/domain/entities/shop_entity.dart';
import '../../features/shops/domain/repositories/shop_repository.dart';

/// Resolves the authenticated user's shop profile for receipts.
class ShopProfileService {
  ShopProfileService({required ShopRepository shopRepository})
      : _shopRepository = shopRepository;

  final ShopRepository _shopRepository;
  ShopEntity? _cached;

  ShopEntity? get cached => _cached;

  bool _isComplete(ShopEntity shop) => shop.name.isNotEmpty;

  /// Prefer sale API shop, then auth user shop, then `GET /settings`.
  Future<ShopEntity?> resolveShop({
    ShopEntity? fromSale,
    ShopEntity? fromAuth,
  }) async {
    if (fromSale != null && _isComplete(fromSale)) {
      _cached = fromSale;
      return fromSale;
    }
    if (fromAuth != null && _isComplete(fromAuth)) {
      _cached = fromAuth;
      return fromAuth;
    }
    if (_cached != null && _isComplete(_cached!)) {
      return _cached;
    }

    try {
      final shop = await _shopRepository.getCurrentShop();
      if (shop != null) {
        _cached = shop;
        return shop;
      }
    } catch (_) {}

    return fromSale ?? fromAuth ?? _cached;
  }

  void clear() => _cached = null;
}
