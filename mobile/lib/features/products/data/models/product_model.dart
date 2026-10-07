import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/product_entity.dart';

part 'product_model.g.dart';

@JsonSerializable()
class ProductModel {
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
  final String? image;

  const ProductModel({
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
    this.image,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) =>
      _$ProductModelFromJson(json);
  Map<String, dynamic> toJson() => _$ProductModelToJson(this);

  /// Laravel API (`products` table) uses snake_case and `shop_id`.
  factory ProductModel.fromLaravelJson(Map<String, dynamic> json) {
    final threshold = (json['low_stock_threshold'] as num?)?.toInt();
    final stockVal = (json['stock'] as num?)?.toInt() ?? 0;
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      cost: (json['cost_price'] as num?)?.toDouble() ??
          (json['cost'] as num?)?.toDouble(),
      sku: json['barcode'] == null || json['barcode'].toString().isEmpty
          ? null
          : json['barcode'].toString(),
      stock: stockVal,
      minStock: threshold,
      taxRate: 0,
      unit: null,
      category: json['category']?.toString(),
      companyId: json['shop_id']?.toString() ?? '',
      image: _imageFromJson(json),
    );
  }

  ProductEntity toEntity() => ProductEntity(
        id: id,
        name: name,
        description: description,
        price: price,
        cost: cost,
        sku: sku,
        stock: stock,
        minStock: minStock,
        taxRate: taxRate,
        unit: unit,
        category: category,
        companyId: companyId,
        isLowStock: minStock != null && stock <= minStock!,
        lowStockThreshold: minStock,
        barcode: sku,
        image: image,
      );

  static String? _imageFromJson(Map<String, dynamic> json) {
    final v = (json['image_url'] ?? json['image'])?.toString().trim();
    if (v == null || v.isEmpty || v == 'null') return null;
    return v;
  }
}
