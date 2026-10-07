import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/analytics_entity.dart';

part 'analytics_model.g.dart';

@JsonSerializable()
class AnalyticsModel {
  final int totalSales;
  final double totalRevenue;
  final int totalCustomers;
  final int totalProducts;
  final double averageOrderValue;
  final List<DailySalesModel> dailySales;

  /// Filled when mapping from `GET /api/dashboard` (not from generic JSON).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? todayTransactions;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final double? todayTotalRevenue;

  @JsonKey(includeFromJson: false, includeToJson: false)
  final int? lowStockCount;

  const AnalyticsModel({
    required this.totalSales,
    required this.totalRevenue,
    required this.totalCustomers,
    required this.totalProducts,
    required this.averageOrderValue,
    required this.dailySales,
    this.todayTransactions,
    this.todayTotalRevenue,
    this.lowStockCount,
  });

  factory AnalyticsModel.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsModelFromJson(json);

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  /// Laravel [DashboardController@index] payload.
  factory AnalyticsModel.fromDashboardJson(Map<String, dynamic> json) {
    final weeklyRaw = json['weekly_sales'];
    final weekly = weeklyRaw is List ? weeklyRaw : const <dynamic>[];
    final dailySales = <DailySalesModel>[];
    for (final e in weekly) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      dailySales.add(DailySalesModel(
        date: m['date']?.toString() ?? '',
        count: _num(m['transactions']).toInt(),
        revenue: _num(m['total']),
      ));
    }

    final todayTx = _num(json['today_transactions']).toInt();
    final todayTotal = _num(json['today_total']);
    final products = _num(json['total_products']).toInt();
    final lowStock = _num(json['low_stock_count']).toInt();

    return AnalyticsModel(
      totalSales: todayTx,
      totalRevenue: todayTotal,
      totalCustomers: 0,
      totalProducts: products,
      averageOrderValue: todayTx > 0 ? todayTotal / todayTx : 0.0,
      dailySales: dailySales,
      todayTransactions: todayTx,
      todayTotalRevenue: todayTotal,
      lowStockCount: lowStock,
    );
  }

  /// Build analytics from sales list when dashboard API is unavailable.
  factory AnalyticsModel.fromSales(
    List<({DateTime createdAt, double total})> sales, {
    int totalProducts = 0,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todaySales = sales
        .where((s) => !s.createdAt.isBefore(todayStart))
        .toList();
    final todayTx = todaySales.length;
    final todayTotal =
        todaySales.fold<double>(0, (sum, s) => sum + s.total);

    final days = <DailySalesModel>[];
    for (var i = 6; i >= 0; i--) {
      final day = todayStart.subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      final daySales = sales
          .where((s) =>
              !s.createdAt.isBefore(day) && s.createdAt.isBefore(next))
          .toList();
      days.add(DailySalesModel(
        date: day.toIso8601String().split('T').first,
        count: daySales.length,
        revenue: daySales.fold<double>(0, (sum, s) => sum + s.total),
      ));
    }

    return AnalyticsModel(
      totalSales: todayTx,
      totalRevenue: todayTotal,
      totalCustomers: 0,
      totalProducts: totalProducts,
      averageOrderValue: todayTx > 0 ? todayTotal / todayTx : 0.0,
      dailySales: days,
      todayTransactions: todayTx,
      todayTotalRevenue: todayTotal,
      lowStockCount: 0,
    );
  }

  Map<String, dynamic> toJson() => _$AnalyticsModelToJson(this);

  AnalyticsEntity toEntity() => AnalyticsEntity(
        totalSales: totalSales,
        totalRevenue: totalRevenue,
        totalCustomers: totalCustomers,
        totalProducts: totalProducts,
        averageOrderValue: averageOrderValue,
        dailySales: dailySales.map((d) => d.toEntity()).toList(),
        todaySales: todayTransactions,
        todayRevenue: todayTotalRevenue,
        lowStockCount: lowStockCount,
      );
}

@JsonSerializable()
class DailySalesModel {
  final String date;
  final int count;
  final double revenue;

  const DailySalesModel({
    required this.date,
    required this.count,
    required this.revenue,
  });

  factory DailySalesModel.fromJson(Map<String, dynamic> json) =>
      _$DailySalesModelFromJson(json);
  Map<String, dynamic> toJson() => _$DailySalesModelToJson(this);

  DailySalesEntity toEntity() =>
      DailySalesEntity(date: date, count: count, revenue: revenue);
}
