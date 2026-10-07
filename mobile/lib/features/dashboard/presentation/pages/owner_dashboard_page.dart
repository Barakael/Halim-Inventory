import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/stats_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../analytics/presentation/bloc/analytics_bloc.dart';
import '../../../products/presentation/bloc/products_bloc.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_event.dart';
import '../../../sales/presentation/bloc/sales_state.dart';
import '../widgets/recent_sales_widget.dart';
import '../widgets/low_stock_alert_widget.dart';
import '../widgets/sales_chart_widget.dart';

// ════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ══════════════════════════════════════════════════════════════════
class _D {
  static BrandPalette get _p => BrandTokens.current;
  static Color get bg => _p.bg;
  static Color get white => _p.white;
  static Color get primary => _p.primary;
  static Color get primaryLt => _p.primaryLt;
  static Color get accent => _p.accent;
  static Color get accentSoft => _p.accentSoft;
  static Color get warn => _p.warn;
  static Color get warnSoft => _p.warn.withValues(alpha: 0.1);
  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.dangerSoft;
  static Color get info => _p.info;
  static Color get infoSoft => _p.info.withValues(alpha: 0.1);
  static Color get ink => _p.ink;
  static Color get inkMid => _p.inkMid;
  static Color get inkLight => const Color(0xFFCBD5E1);
  static Color get border => _p.border;

  static TextStyle ts(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      _p.ts(size,
          weight: weight,
          color: color,
          height: height,
          letterSpacing: letterSpacing);

  static List<BoxShadow> get cardShadow => _p.cardShadow;
}

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // FIX: must return Future<void> for RefreshIndicator.onRefresh
  Future<void> _loadData() async {
    context.read<AnalyticsBloc>().add(const AnalyticsFetchRequested());
    context.read<ProductsBloc>().add(const ProductsFetchRequested());
    // FIX: removed const — SalesFetchRequested has non-const params
    context.read<SalesBloc>().add(const SalesFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.bg,
      body: SafeArea(
        child: Column(
          children: [
            _DashHeader(
              firstName: state is AuthAuthenticated ? state.user.firstName : 'Owner',
              subtitle: 'Owner Dashboard',
              actions: [
                _HeaderAction(
                  icon: Icons.settings_outlined,
                  onTap: () => context.push(RouteNames.settings),
                ),
                _HeaderAction(
                  icon: Icons.logout_rounded,
                  onTap: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                ),
              ],
            ),
            Container(
              color: _D.white,
              child: TabBar(
                controller: _tabController,
                labelColor: _D.primary,
                unselectedLabelColor: _D.inkMid,
                indicatorColor: _D.primary,
                indicatorWeight: 3,
                labelStyle: _D.ts(13, weight: FontWeight.w700),
                unselectedLabelStyle: _D.ts(13, weight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined, size: 18)),
                  Tab(text: 'Analytics', icon: Icon(Icons.bar_chart_rounded, size: 18)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _PrimaryFAB(
        icon: Icons.add_rounded,
        label: 'New Sale',
        onTap: () => context.push(RouteNames.createSale),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildSalesChart(),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: LowStockAlertWidget(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Sales', style: _D.ts(15, weight: FontWeight.w700)),
                GestureDetector(
                  onTap: () => context.push(RouteNames.sales),
                  child: Text('See all', style: _D.ts(13, weight: FontWeight.w600, color: _D.primary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            BlocBuilder<SalesBloc, SalesState>(
              builder: (context, salesState) {
                final sales = salesState is SalesLoaded ? salesState.sales : <dynamic>[];
                if (sales.isEmpty) {
                  return _EmptyState(icon: Icons.receipt_outlined, message: 'No sales recorded yet')
                
                } else
                  ...sales.take(5).map((s) => _SaleRow(
                        sale: s,
                        onTap: () => context.push('${RouteNames.sales}/${s.id}'),
                      ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        if (state is AnalyticsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is AnalyticsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading analytics',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // FIX: use label instead of text, remove variant param
                AppButton(
                  label: 'Retry',
                  onPressed: _loadData,
                ),
              ],
            ),
          );
        } else if (state is AnalyticsLoaded) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildRevenueChart(state.analytics),
                const SizedBox(height: 24),
                _buildCategorySalesChart(state.analytics),
                const SizedBox(height: 24),
                _buildTopProductsSection(state.analytics),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (Icons.point_of_sale_rounded, 'New Sale', RouteNames.createSale, _D.primary),
      (Icons.inventory_2_outlined, 'Inventory', RouteNames.inventory, _D.accent),
      (Icons.receipt_long_outlined, 'Sales History', RouteNames.sales, _D.warn),
      (Icons.assessment_outlined, 'Reports', RouteNames.reports, _D.info),
      (Icons.badge_outlined, 'Staff', RouteNames.staff, _D.success),
      (Icons.store_outlined, 'Store Settings', RouteNames.settings, _D.inkMid),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: _D.ts(15, weight: FontWeight.w700)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: actions
              .map((action) => _QuickActionCard(
                    icon: action.$1,
                    label: action.$2,
                    color: action.$4,
                    onTap: () => context.push(action.$3),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return BlocBuilder<SalesBloc, SalesState>( 
      builder: (context, salesState) {
        final sales = salesState is SalesLoaded ? salesState.sales : <dynamic>[];
        final now = DateTime.now();
        final today = sales.where((s) {
          try {
            return _isSameDay(DateTime.parse(s.createdAt), now);
          } catch (_) {
            return false;
          }
        }).toList();

        final totalRev = sales.fold(0.0, (s, i) => s + (i.total as num));
        final todayRev = today.fold(0.0, (s, i) => s + (i.total as num));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Overview', style: _D.ts(15, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                StatsCard(
                  title: "Today's Sales",
                  value: today.length.toString(),
                  subtitle: CurrencyFormatter.format(todayRev),
                  icon: Icons.today_rounded,
                  color: _D.primary,
                ),
                StatsCard(
                  title: "Today's Revenue",
                  value: CurrencyFormatter.format(todayRev),
                  icon: Icons.payments_rounded,
                  color: _D.accent,
                ),
                StatsCard(
                  title: 'Total Sales',
                  value: sales.length.toString(),
                  icon: Icons.receipt_long_rounded,
                  color: _D.info,
                ),
                StatsCard(
                  title: 'Total Revenue',
                  value: CurrencyFormatter.format(totalRev),
                  icon: Icons.account_balance_wallet_rounded,
                  color: _D.warn,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Sales',
              style: _D.ts(16, weight: FontWeight.bold, color: _D.primary),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: SalesChartWidget()),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(dynamic analytics) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend',
              style: _D.ts(16, weight: FontWeight.bold, color: _D.primary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getRevenueSpots(analytics),
                      isCurved: true,
                      color: _D.primary,
                      barWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySalesChart(dynamic analytics) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales by Category',
              style: _D.ts(16, weight: FontWeight.bold, color: _D.primary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(sections: _getCategorySections(analytics)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsSection(dynamic analytics) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Products',
              style: _D.ts(16, weight: FontWeight.bold, color: _D.primary),
            ),
            const SizedBox(height: 16),
            const Text('Top products will be displayed here'),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getRevenueSpots(dynamic analytics) {
    return [
      const FlSpot(0, 1000),
      const FlSpot(1, 1500),
      const FlSpot(2, 1200),
      const FlSpot(3, 1800),
      const FlSpot(4, 2000),
      const FlSpot(5, 1700),
      const FlSpot(6, 2200),
    ];
  }

  List<PieChartSectionData> _getCategorySections(dynamic analytics) {
    return [
      PieChartSectionData(value: 30, color: _D.primary, title: '30%'),
      PieChartSectionData(value: 25, color: _D.accent, title: '25%'),
      PieChartSectionData(value: 20, color: _D.success, title: '20%'),
      PieChartSectionData(value: 15, color: _D.warn, title: '15%'),
      PieChartSectionData(value: 10, color: _D.info, title: '10%'),
    ];
  }
}

// ════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ══════════════════════════════════════════════════════════════

class _DashHeader extends StatelessWidget {
  const _DashHeader({
    required this.firstName,
    required this.subtitle,
    required this.actions,
  });

  final String firstName;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: _D.white,
        boxShadow: _D.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName,
                  style: _D.ts(20, weight: FontWeight.w700, color: _D.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: _D.ts(13, weight: FontWeight.w500, color: _D.inkMid),
                ),
              ],
            ),
          ),
          Row(
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _D.primary.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _D.primary, size: 20),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _D.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 40, color: _D.primary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: _D.ts(16, weight: FontWeight.w500, color: _D.inkMid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.onTap});
  
  final dynamic sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${sale.id}',
                      style: _D.ts(12, weight: FontWeight.w600, color: _D.inkMid),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sale.customerName ?? 'Guest',
                      style: _D.ts(14, weight: FontWeight.w500, color: _D.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(sale.total),
                    style: _D.ts(16, weight: FontWeight.w700, color: _D.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(sale.createdAt),
                    style: _D.ts(12, color: _D.inkMid),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}

class _PrimaryFAB extends StatelessWidget {
  const _PrimaryFAB({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: _D.primary,
      foregroundColor: _D.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(icon, size: 20),
      label: Text(label, style: _D.ts(14, weight: FontWeight.w600, color: _D.white)),
    );
  }
}