import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../dashboard/presentation/widgets/stats_card.dart';
import '../bloc/analytics_bloc.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  void initState() {
    super.initState();
    context.read<AnalyticsBloc>().add(const AnalyticsFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<AnalyticsBloc>()
                .add(const AnalyticsFetchRequested()),
          ),
        ],
      ),
      body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
        builder: (context, state) {
          if (state is AnalyticsLoading) return const AppLoadingIndicator();
          if (state is AnalyticsError) {
            return ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<AnalyticsBloc>()
                  .add(const AnalyticsFetchRequested()),
            );
          }
          if (state is AnalyticsLoaded) {
            final a = state.analytics;
            return RefreshIndicator(
              onRefresh: () async => context
                  .read<AnalyticsBloc>()
                  .add(const AnalyticsFetchRequested()),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        StatsCard(
                          title: 'Total Sales',
                          value: '${a.totalSales}',
                          icon: Icons.receipt_outlined,
                          color: AppColors.primary,
                        ),
                        StatsCard(
                          title: 'Total Revenue',
                          value: CurrencyFormatter.formatCompact(
                              a.totalRevenue),
                          icon: Icons.attach_money,
                          color: AppColors.success,
                        ),
                        StatsCard(
                          title: 'Customers',
                          value: '${a.totalCustomers}',
                          icon: Icons.people_outlined,
                          color: AppColors.accent,
                        ),
                        StatsCard(
                          title: 'Avg. Order',
                          value: CurrencyFormatter.formatCompact(
                              a.averageOrderValue),
                          icon: Icons.trending_up,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (a.dailySales.isNotEmpty) ...[
                      Text(
                        'Revenue (Last 7 Days)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: const FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: a.dailySales
                                    .asMap()
                                    .entries
                                    .map((e) => FlSpot(
                                          e.key.toDouble(),
                                          e.value.revenue,
                                        ))
                                    .toList(),
                                isCurved: true,
                                color: AppColors.primary,
                                barWidth: 3,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppColors.primary.withAlpha(40),
                                ),
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
