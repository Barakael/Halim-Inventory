import 'package:equatable/equatable.dart';

class DailySalesEntity extends Equatable {
  final String date;
  final int count;
  final double revenue;

  const DailySalesEntity({
    required this.date,
    required this.count,
    required this.revenue,
  });

  @override
  List<Object?> get props => [date];
}

class AnalyticsEntity extends Equatable {
  final int totalSales;
  final double totalRevenue;
  final int totalCustomers;
  final int totalProducts;
  final double averageOrderValue;
  final List<DailySalesEntity> dailySales;
  final int? todaySales;
  final double? todayRevenue;
  final int? lowStockCount;

  const AnalyticsEntity({
    required this.totalSales,
    required this.totalRevenue,
    required this.totalCustomers,
    required this.totalProducts,
    required this.averageOrderValue,
    required this.dailySales,
    this.todaySales,
    this.todayRevenue,
    this.lowStockCount,
  });

  @override
  List<Object?> get props => [totalSales, totalRevenue];
}
