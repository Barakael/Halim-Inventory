// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnalyticsModel _$AnalyticsModelFromJson(Map<String, dynamic> json) =>
    AnalyticsModel(
      totalSales: (json['totalSales'] as num).toInt(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      totalCustomers: (json['totalCustomers'] as num).toInt(),
      totalProducts: (json['totalProducts'] as num).toInt(),
      averageOrderValue: (json['averageOrderValue'] as num).toDouble(),
      dailySales: (json['dailySales'] as List<dynamic>)
          .map((e) => DailySalesModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$AnalyticsModelToJson(AnalyticsModel instance) =>
    <String, dynamic>{
      'totalSales': instance.totalSales,
      'totalRevenue': instance.totalRevenue,
      'totalCustomers': instance.totalCustomers,
      'totalProducts': instance.totalProducts,
      'averageOrderValue': instance.averageOrderValue,
      'dailySales': instance.dailySales,
    };

DailySalesModel _$DailySalesModelFromJson(Map<String, dynamic> json) =>
    DailySalesModel(
      date: json['date'] as String,
      count: (json['count'] as num).toInt(),
      revenue: (json['revenue'] as num).toDouble(),
    );

Map<String, dynamic> _$DailySalesModelToJson(DailySalesModel instance) =>
    <String, dynamic>{
      'date': instance.date,
      'count': instance.count,
      'revenue': instance.revenue,
    };
