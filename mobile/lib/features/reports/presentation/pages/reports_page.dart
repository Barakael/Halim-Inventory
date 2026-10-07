import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/brand_palette.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../sales/domain/entities/sale_entity.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_event.dart';
import '../../../sales/presentation/bloc/sales_state.dart';
import '../utils/reports_pdf.dart';

/// Mobile Reports — period filter, revenue stats, charts, payment methods,
/// transaction history, and PDF export from sales API.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum _Period { daily, weekly, monthly }

class _R {
  static BrandPalette get _p => BrandTokens.current;
  static Color get bg => _p.bg;
  static Color get white => _p.white;
  static Color get primary => _p.primary;
  static Color get primaryLt => _p.primaryLt;
  static Color get accent => _p.accent;
  static Color get accentSoft => _p.accentSoft;
  static Color get danger => _p.danger;
  static Color get info => _p.info;
  static Color get ink => _p.ink;
  static Color get inkMid => _p.inkMid;
  static Color get border => _p.border;

  static LinearGradient get chartGradient => LinearGradient(
        colors: [primaryLt, accent],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );

  static List<BoxShadow> get cardShadow => _p.cardShadow;
}


class _ReportsPageState extends State<ReportsPage> {
  _Period _period = _Period.daily;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(const SalesFetchRequested());       
  }

  String _periodLabel(AppStrings t) {
    switch (_period) {
      case _Period.daily:
        return t.periodDaily;
      case _Period.weekly:
        return t.periodWeekly;
      case _Period.monthly:
        return t.periodMonthly;
    }
  }

  String _payLabel(AppStrings t, String raw) {
    final key = raw.toLowerCase().trim();
    if (key.isEmpty || key == 'other') return t.otherPayment;
    if (key == 'cash') return t.cash;
    if (key == 'card') return t.card;
    if (key.contains('mobile')) return t.mobileMoney;
    if (key == 'credit') return t.creditDebtBook;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<SaleEntity> _filter(List<SaleEntity> sales) {
    final now = DateTime.now();
    switch (_period) {
      case _Period.daily:
        return sales.where((s) => _sameDay(s.createdAt, now)).toList();
      case _Period.weekly:
        return sales
            .where((s) => now.difference(s.createdAt).inDays <= 7)
            .toList();
      case _Period.monthly:
        return sales
            .where((s) =>
                s.createdAt.month == now.month &&
                s.createdAt.year == now.year)
            .toList();
    }
  }

  List<_HourPoint> _hourly(List<SaleEntity> todaySales) {
    return List.generate(24, (hour) {
      final hourSales =
          todaySales.where((s) => s.createdAt.hour == hour).toList();
      return _HourPoint(
        label: '$hour:00',
        total: hourSales.fold(0.0, (a, s) => a + s.total),
        count: hourSales.length,
      );
    }).where((h) => h.total > 0 || h.count > 0).toList();
  }

  List<_DayPoint> _weeklyTrend(List<SaleEntity> sales) {
    return List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      final daySales = sales.where((s) => _sameDay(s.createdAt, d)).toList();
      return _DayPoint(
        label: DateFormat('MMM d').format(d),
        total: daySales.fold(0.0, (a, s) => a + s.total),
      );
    });
  }

  List<_PayPoint> _payments(List<SaleEntity> sales) {
    final map = <String, double>{};
    for (final s in sales) {
      final key = s.paymentMethod.isEmpty ? 'other' : s.paymentMethod;
      map[key] = (map[key] ?? 0) + s.total;
    }
    return map.entries
        .map((e) => _PayPoint(method: e.key, total: e.value))
        .toList();
  }

  Future<void> _downloadPdf() async {
    if (_exporting) return;
    final t = AppStrings.read(context);
    final state = context.read<SalesBloc>().state;
    final allSales = state is SalesLoaded ? state.sales : <SaleEntity>[];
    final current = _filter(allSales);
    final revenue = current.fold(0.0, (a, s) => a + s.total);
    final txCount = current.length;
    final avg = txCount > 0 ? revenue / txCount : 0.0;
    final payData = _payments(current);

    setState(() => _exporting = true);
    HapticFeedback.lightImpact();
    try {
      final bytes = await buildSalesReportPdf(
        t: t,
        periodLabel: _periodLabel(t),
        sales: current,
        revenue: revenue,
        txCount: txCount,
        avg: avg,
        payments: payData
            .map((p) => (method: p.method, total: p.total))
            .toList(),
      );
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final name =
          'POSApp_Report_${_period.name}_$stamp.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.pdfReady),
          backgroundColor: _R.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.pdfFailed}: $e'),
          backgroundColor: _R.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AppPageScaffold(
      title: t.reports,
      subtitle: t.reportsSubtitle,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          tooltip: t.shareReportPdf,
          onPressed: _exporting ? null : _downloadPdf,
          icon: _exporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
        ),
        const SizedBox(width: 4),
      ],
      body: RefreshIndicator(
        color: _R.primary,
        onRefresh: () async {
          context.read<SalesBloc>().add(const SalesFetchRequested());
        },
        child: BlocBuilder<SalesBloc, SalesState>(
          builder: (context, state) {
            // After POS, bloc is SaleCreated — refetch so reports aren't empty.
            final isTop = ModalRoute.of(context)?.isCurrent ?? true;
            if (state is SaleCreated ||
                (state is SaleDetailLoaded && isTop)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    (ModalRoute.of(context)?.isCurrent ?? false)) {
                  context
                      .read<SalesBloc>()
                      .add(const SalesFetchRequested());
                }
              });
              return Center(
                child: CircularProgressIndicator(
                  color: _R.primary,
                  strokeWidth: 2.5,
                ),
              );
            }

            if (state is SalesLoading || state is SalesInitial) {
              return Center(
                child: CircularProgressIndicator(
                  color: _R.primary,
                  strokeWidth: 2.5,
                ),
              );
            }
            if (state is SalesError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  Text(state.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _R.inkMid)),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton(
                      onPressed: () => context
                          .read<SalesBloc>()
                          .add(const SalesFetchRequested()),
                      style: FilledButton.styleFrom(
                        backgroundColor: _R.primary,
                      ),
                      child: Text(t.retry),
                    ),
                  ),
                ],
              );
            }

            final allSales =
                state is SalesLoaded ? state.sales : <SaleEntity>[];
            final current = _filter(allSales);
            final revenue = current.fold(0.0, (a, s) => a + s.total);
            final txCount = current.length;
            final avg = txCount > 0 ? revenue / txCount : 0.0;
            final today = allSales
                .where((s) => _sameDay(s.createdAt, DateTime.now()))
                .toList();
            final chartPoints = _period == _Period.daily
                ? _hourly(today)
                    .map((h) => _ChartPoint(h.label, h.total))
                    .toList()
                : _weeklyTrend(allSales)
                    .map((d) => _ChartPoint(d.label, d.total))
                    .toList();
            final payData = _payments(current);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _PeriodSelector(
                  period: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 14),
                _HeroStat(
                  label: t.totalRevenue,
                  value: CurrencyFormatter.format(revenue),
                  icon: Icons.payments_rounded,
                  color: _R.accent,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: t.transactions,
                        value: '$txCount',
                        icon: Icons.shopping_cart_rounded,
                        color: _R.info,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: t.avgTransaction,
                        value: CurrencyFormatter.format(avg),
                        icon: Icons.trending_up_rounded,
                        color: _R.primaryLt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _period == _Period.daily
                            ? t.hourlySales
                            : t.salesTrend,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _R.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
                        child: chartPoints.every((p) => p.value == 0)
                            ? Center(
                                child: Text(
                                  t.noSalesDataPeriod,
                                  style: TextStyle(
                                      fontSize: 13, color: _R.inkMid),
                                ),
                              )
                            : _BarChart(points: chartPoints),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.paymentMethods,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _R.ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (payData.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20),
                                    child: Center(
                                      child: Text(
                                        t.noPaymentData,
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            color: _R.inkMid),
                                      ),
                                    ),
                                  )
                                else
                                  ...() {
                                    final legendColors = [
                                      _R.primary,
                                      _R.accent,
                                      _R.info,
                                      _R.primaryLt,
                                    ];
                                    final max = payData
                                        .map((e) => e.total)
                                        .reduce((a, b) => a > b ? a : b);
                                    return List.generate(payData.length,
                                        (i) {
                                      final p = payData[i];
                                      final ratio =
                                          max > 0 ? p.total / max : 0.0;
                                      final color = legendColors[
                                          i % legendColors.length];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 11),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                    _payLabel(
                                                        t, p.method),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12.5,
                                                    )),
                                                Text(
                                                  CurrencyFormatter.format(
                                                      p.total),
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 12.5,
                                                    color: color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child:
                                                  LinearProgressIndicator(
                                                value: ratio,
                                                minHeight: 7,
                                                backgroundColor: color
                                                    .withValues(
                                                        alpha: 0.12),
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    });
                                  }(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      t.transactionHistory,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _R.ink,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      t.transactionsCount(current.length),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: _R.inkMid,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (current.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 28),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.receipt_long_outlined,
                                              size: 36, color: _R.inkMid),
                                          const SizedBox(height: 10),
                                          Text(
                                            t.noTransactionsPeriod,
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                color: _R.inkMid),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...current.map((sale) => _TxTile(
                                        sale: sale,
                                        itemsLabel: t.itemsCount(
                                            sale.items.length),
                                        methodLabel: _payLabel(
                                            t, sale.paymentMethod),
                                      )),
                              ],
                            ),
                          ),
                        ],
                      );
                  },
                ),
              ),
            );
  }
}

class _HourPoint {
  final String label;
  final double total;
  final int count;
  const _HourPoint(
      {required this.label, required this.total, required this.count});
}

class _DayPoint {
  final String label;
  final double total;
  const _DayPoint({required this.label, required this.total});
}

class _PayPoint {
  final String method;
  final double total;
  const _PayPoint({required this.method, required this.total});
}

class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint(this.label, this.value);
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.period,
    required this.onChanged,
  });

  final _Period period;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _R.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _R.border),
        boxShadow: _R.cardShadow,
      ),
      child: Row(
        children: _Period.values.map((p) {
          final selected = period == p;
          final label = switch (p) {
            _Period.daily => t.periodDaily,
            _Period.weekly => t.periodWeekly,
            _Period.monthly => t.periodMonthly,
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _R.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _R.inkMid,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _R.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _R.border),
        boxShadow: _R.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: _R.inkMid)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _R.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _R.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _R.border),
        boxShadow: _R.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(label,
                  style: TextStyle(fontSize: 10.5, color: _R.inkMid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _R.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _R.border),
        boxShadow: _R.cardShadow,
      ),
      child: child,
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.points});
  final List<_ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxV =
        points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b);
    final peak = maxV > 0 ? maxV : 1.0;

    return LayoutBuilder(
      builder: (_, constraints) {
        final barW =
            (constraints.maxWidth - (points.length - 1) * 5) / points.length;
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((p) {
                  final h = (p.value / peak) * (constraints.maxHeight - 26);
                  return Padding(
                    padding:
                        EdgeInsets.only(right: p == points.last ? 0 : 5),
                    child: SizedBox(
                      width: barW.clamp(7, 44),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          height: h.clamp(2, constraints.maxHeight - 26),
                          decoration: BoxDecoration(
                            gradient: _R.chartGradient,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: points.map((p) {
                return Expanded(
                  child: Text(
                    p.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      color: _R.inkMid,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.sale,
    required this.itemsLabel,
    required this.methodLabel,
  });

  final SaleEntity sale;
  final String itemsLabel;
  final String methodLabel;

  @override
  Widget build(BuildContext context) {
    final id =
        sale.serialNumber.isNotEmpty ? sale.serialNumber : '#${sale.id}';
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: _R.bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: _R.inkMid,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMM yyyy · HH:mm').format(sale.createdAt),
                  style: TextStyle(fontSize: 11.5, color: _R.ink),
                ),
                Text(
                  itemsLabel,
                  style: TextStyle(fontSize: 10.5, color: _R.inkMid),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(sale.total),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _R.ink,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _R.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  methodLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: _R.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
