import '../../../products/domain/entities/product_entity.dart';

enum SaleType { retail, wholesale }

class CartItem {
  final ProductEntity product;
  final int quantity;
  final SaleType saleType;
  final double unitPrice;

  CartItem({
    required this.product,
    required this.quantity,
    required this.saleType,
    required this.unitPrice,
  });

  String get lineKey => '${product.id}:${saleType.name}';
}
