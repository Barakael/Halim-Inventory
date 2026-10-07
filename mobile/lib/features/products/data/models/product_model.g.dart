// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductModel _$ProductModelFromJson(Map<String, dynamic> json) => ProductModel(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  price: (json['price'] as num).toDouble(),
  cost: (json['cost'] as num?)?.toDouble(),
  sku: json['sku'] as String?,
  stock: (json['stock'] as num).toInt(),
  minStock: (json['minStock'] as num?)?.toInt(),
  taxRate: (json['taxRate'] as num).toDouble(),
  unit: json['unit'] as String?,
  category: json['category'] as String?,
  companyId: json['companyId'] as String,
  image: json['image'] as String?,
);

Map<String, dynamic> _$ProductModelToJson(ProductModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'cost': instance.cost,
      'sku': instance.sku,
      'stock': instance.stock,
      'minStock': instance.minStock,
      'taxRate': instance.taxRate,
      'unit': instance.unit,
      'category': instance.category,
      'companyId': instance.companyId,
      'image': instance.image,
    };
