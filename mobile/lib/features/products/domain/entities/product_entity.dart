import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  final String id;
  final String name;
  final String? description;
  final double price;
  final double? cost;
  final String? sku;
  final int stock;
  final int? minStock;
  final double taxRate;
  final String? unit;
  final String? category;
  final String companyId;
  final bool isLowStock;
  final int? lowStockThreshold;
  final String? barcode;
  final String? image;

  const ProductEntity({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.cost,
    this.sku,
    required this.stock,
    this.minStock,
    required this.taxRate,
    this.unit,
    this.category,
    required this.companyId,
    this.isLowStock = false,
    this.lowStockThreshold,
    this.barcode,
    this.image,
  });

  @override
  List<Object?> get props => [id, name, image, stock, price, barcode, category];
}
