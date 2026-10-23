import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/brand_palette.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_switcher.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/bloc/products_bloc.dart';
import '../../../sales/domain/entities/sale_entity.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_event.dart';
import '../../../sales/presentation/bloc/sales_state.dart';

// ════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS — keep numerically identical to ReportsPage's `_R` tokens.
// ════════════════════════════════════════════════════════════════════════════
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
  /// Dashboard body copy uses black for readability (icons/CTAs keep brand).
  static const Color ink = Color(0xFF000000);
  static const Color inkMid = Color(0xFF1A1A1A);
  static const Color inkLight = Color(0xFF4A4A4A);
  static Color get border => _p.border;

  static TextStyle ts(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        height: height,
        letterSpacing: letterSpacing,
      );

  static List<BoxShadow> get cardShadow => _p.cardShadow;
  static Color primaryOpacity(double o) => _p.primaryOpacity(o);
}


/// True when [state] represents a transient bloc state after a POS sale or
/// after viewing a sale's detail — the trigger to silently refetch the list.
bool _shouldRefetchOn(SalesState state, bool isTopRoute) {
  return state is SaleCreated || (state is SaleDetailLoaded && isTopRoute);
}

// ════════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE
// ════════════════════════════════════════════════════════════════════════════
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    Future.microtask(() {
      context.read<SalesBloc>().add(const SalesFetchRequested());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() => context.read<SalesBloc>().add(const SalesFetchRequested());

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return const _LoginRequiredScreen();
        }

        final user = authState.user;
        final role = user.roleName.toLowerCase().trim();

        if (role == 'owner' || role == 'business owner' || role == 'super_admin') {
          return _OwnerDashboardView(
            user: user,
            tabController: _tabController,
            onReload: _reload,
          );
        } else if (role == 'cashier') {
          return _CashierDashboardView(user: user);
        } else {
          return _DefaultDashboardView(user: user);
        }
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ROLE-BASED DASHBOARDS
// ════════════════════════════════════════════════════════════════════════════

class _OwnerDashboardView extends StatelessWidget {
  const _OwnerDashboardView({
    required this.user,
    required this.tabController,
    required this.onReload,
  });

  final dynamic user;
  final TabController tabController;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final role = user.roleName.toLowerCase().trim();
    final isOwner = role == 'owner' || role == 'business owner';

    return Scaffold(
      backgroundColor: _D.bg,
      body: SafeArea(
        child: Column(
          children: [
            _DashHeader(
              firstName: user.firstName ?? context.t.userFallback,
              subtitle: context.t.ownerDashboard,
              actions: [
                const LanguageHeaderToggle(),
                if (isOwner)
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
              decoration: BoxDecoration(
                color: _D.white,
                border: Border(bottom: BorderSide(color: _D.border)),
              ),
              child: TabBar(
                controller: tabController,
                labelColor: _D.primary,
                unselectedLabelColor: _D.inkMid,
                indicatorColor: _D.primary,
                indicatorWeight: 2.5,
                dividerColor: _D.border,
                labelStyle: _D.ts(13, weight: FontWeight.w700),
                unselectedLabelStyle: _D.ts(13, weight: FontWeight.w500),
                tabs: [
                  Tab(text: context.t.overview),
                  Tab(text: context.t.analytics),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _OverviewTab(onReload: onReload),
                  _AnalyticsTab(onReload: onReload),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cashier store overview — mirrors frontend Dashboard.tsx (non-admin).
class _CashierDashboardView extends StatefulWidget {
  const _CashierDashboardView({required this.user});

  final dynamic user;

  @override
  State<_CashierDashboardView> createState() => _CashierDashboardViewState();
}

class _CashierDashboardViewState extends State<_CashierDashboardView> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    context.read<SalesBloc>().add(const SalesFetchRequested());
    context.read<ProductsBloc>().add(const ProductsFetchRequested());
  }

  bool _sameDay(DateTime a, DateTime b) => _isSameDay(a, b);

  bool _isCreditPaymentMethod(String raw) {
    final key = raw.toLowerCase().trim();
    return key == 'credit' || key.contains('deni');
  }

  bool _isCashLikePaymentMethod(String raw) {
    final key = raw.toLowerCase().trim();
    if (_isCreditPaymentMethod(key)) return false;
    return key == 'cash' ||
        key == 'card' ||
        key.contains('mobile') ||
        key == 'bank';
  }

  String _greeting(BuildContext context) {
    final name = (widget.user.firstName as String?)?.trim();
    return context.t.goodGreeting(
      (name == null || name.isEmpty) ? context.t.cashierFallback : name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _D.primary,
          onRefresh: () async => _load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _DashHeader(
                  firstName: widget.user.firstName ?? context.t.userFallback,
                  subtitle: context.t.storeOverviewToday,
                  actions: [
                    const LanguageHeaderToggle(),
                    _HeaderAction(
                      icon: Icons.logout_rounded,
                      onTap: () => context
                          .read<AuthBloc>()
                          .add(const AuthLogoutRequested()),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 88),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _GreetingBanner(
                      headline: _greeting(context),
                      subtitle: context.t.storeOverviewToday,
                    ),
                    const SizedBox(height: 14),
                    // BlocConsumer: `listener` fires once per state
                    // transition and is the correct place to trigger a
                    // refetch after a POS sale or a sale-detail view —
                    // dispatching from inside `builder` risks firing on
                    // every rebuild instead of once per state change.
                    BlocConsumer<SalesBloc, SalesState>(
                      listener: (context, salesState) {
                        final isTop =
                            ModalRoute.of(context)?.isCurrent ?? true;
                        if (_shouldRefetchOn(salesState, isTop)) {
                          _load();
                        }
                      },
                      builder: (context, salesState) {
                        return BlocBuilder<ProductsBloc, ProductsState>(
                          builder: (context, productsState) {
                            final allSales = salesState is SalesLoaded
                                ? salesState.sales
                                : <SaleEntity>[];
                            // Cashiers only see their own sales on the dashboard
                            // (same scoping as Reports).
                            final uid = widget.user.id?.toString() ?? '';
                            final sales = uid.isEmpty
                                ? allSales
                                : allSales
                                    .where((s) =>
                                        s.cashierId.toString() == uid)
                                    .toList();
                            final products = productsState is ProductsLoaded
                                ? productsState.products
                                : <ProductEntity>[];

                            final isTransient = salesState is SalesLoading ||
                                salesState is SalesInitial ||
                                salesState is SaleCreated ||
                                salesState is SaleDetailLoaded;

                            if (isTransient && sales.isEmpty) {
                              return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _D.primary,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              );
                            }

                            final now = DateTime.now();
                            final todaySales = sales
                                .where((s) => _sameDay(s.createdAt, now))
                                .toList();
                            final todayTotal = todaySales.fold<double>(
                                0, (a, s) => a + s.total);
                            final todayCash = todaySales
                                .where((s) =>
                                    _isCashLikePaymentMethod(s.paymentMethod))
                                .fold<double>(0, (a, s) => a + s.total);
                            final todayCredit = todaySales
                                .where((s) =>
                                    _isCreditPaymentMethod(s.paymentMethod))
                                .fold<double>(0, (a, s) => a + s.total);
                            final lowStock = products.where((p) {
                              final threshold =
                                  p.lowStockThreshold ?? p.minStock ?? 10;
                              return p.stock <= threshold;
                            }).toList();
                            final t = context.t;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Stats
                                GridView.count(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1.5,
                                  children: [
                                    _CashierStat(
                                      title: t.todaysSales,
                                      value: CurrencyFormatter.format(
                                          todayTotal),
                                      icon: Icons.attach_money_rounded,
                                      color: _D.accent,
                                    ),
                                    _CashierStat(
                                      title: t.cashSales,
                                      value: CurrencyFormatter.format(
                                          todayCash),
                                      icon: Icons.payments_rounded,
                                      color: _D.info,
                                    ),
                                    _CashierStat(
                                      title: t.creditsMadeni,
                                      value: CurrencyFormatter.format(
                                          todayCredit),
                                      icon: Icons.menu_book_rounded,
                                      color: _D.primary,
                                    ),
                                    _CashierStat(
                                      title: t.lowStock,
                                      value: '${lowStock.length}',
                                      subtitle: lowStock.isEmpty
                                          ? t.allGood
                                          : t.needsAttention,
                                      icon: Icons.warning_amber_rounded,
                                      color: _D.danger,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Recent sales (max 4) — end of dashboard scroll
                                _SectionCard(
                                  title: t.recentTransactions,
                                  icon: Icons.trending_up_rounded,
                                  iconColor: _D.primary,
                                  child: sales.isEmpty
                                      ? _InlineEmptyRow(
                                          icon: Icons.receipt_outlined,
                                          message: t.noSalesYetToday,
                                        )
                                      : Column(
                                          children: sales
                                              .take(4)
                                              .map((sale) => Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            bottom: 6),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            10),
                                                    decoration: BoxDecoration(
                                                      color: _D.bg,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(9),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                t.itemsCount(sale.items.length),
                                                                style: _D.ts(
                                                                    13,
                                                                    weight:
                                                                        FontWeight
                                                                            .w600),
                                                              ),
                                                              Text(
                                                                DateFormatHelper
                                                                    .time(
                                                                        sale
                                                                            .createdAt),
                                                                style: _D.ts(
                                                                    11,
                                                                    color: _D
                                                                        .inkMid),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          children: [
                                                            Text(
                                                              CurrencyFormatter
                                                                  .format(sale
                                                                      .total),
                                                              style: _D.ts(13,
                                                                  weight:
                                                                      FontWeight
                                                                          .w800),
                                                            ),
                                                            Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      top: 4),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal:
                                                                    8,
                                                                vertical: 2,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: _D
                                                                    .accentSoft,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                              ),
                                                              child: Text(
                                                                sale.paymentMethod
                                                                        .isEmpty
                                                                    ? '—'
                                                                    : sale.paymentMethod[0]
                                                                            .toUpperCase() +
                                                                        sale
                                                                            .paymentMethod
                                                                            .substring(1),
                                                                style: _D.ts(
                                                                    10,
                                                                    weight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: _D
                                                                        .accent),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _PrimaryFAB(
        icon: Icons.point_of_sale_rounded,
        label: context.t.openPos,
        onTap: () => context.push(RouteNames.pos),
      ),
    );
  }
}

class DateFormatHelper {
  static String time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _CashierStat extends StatelessWidget {
  const _CashierStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.border),
        boxShadow: _D.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const Spacer(),
          Text(value,
              style: _D.ts(15.5, weight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(subtitle ?? title,
              style: _D.ts(10.5, color: _D.inkMid),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.border),
        boxShadow: _D.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: (iconColor ?? _D.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 13, color: iconColor ?? _D.primary),
                ),
                const SizedBox(width: 7),
              ],
              Text(title, style: _D.ts(13, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _InlineEmptyRow extends StatelessWidget {
  const _InlineEmptyRow({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: _D.inkLight),
        const SizedBox(width: 7),
        Expanded(
          child: Text(message, style: _D.ts(12.5, color: _D.inkMid)),
        ),
      ],
    );
  }
}

class _DefaultDashboardView extends StatelessWidget {
  const _DefaultDashboardView({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.bg,
      body: SafeArea(
        child: Column(
          children: [
            _DashHeader(
              firstName: user.firstName ?? context.t.userFallback,
              subtitle: context.t.dashboard,
              actions: [
                const LanguageHeaderToggle(),
                _HeaderAction(
                  icon: Icons.logout_rounded,
                  onTap: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _D.infoSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.dashboard_rounded,
                            color: _D.info, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(context.t.welcomeUser(user.firstName ?? context.t.userFallback),
                          style: _D.ts(19, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(context.t.contactAdminForRole,
                          style: _D.ts(13.5, color: _D.inkMid),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOGIN REQUIRED SCREEN
// ════════════════════════════════════════════════════════════════════════════
class _LoginRequiredScreen extends StatelessWidget {
  const _LoginRequiredScreen();

  Future<void> _goToLogin(BuildContext context) async {
    final secureStorage = SecureStorage();
    await secureStorage.deleteToken();
    await secureStorage.deleteUser();
    if (context.mounted) {
      GoRouter.of(context).go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _D.infoSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded,
                    color: _D.info, size: 32),
              ),
              const SizedBox(height: 18),
              Text(context.t.authRequired,
                  style: _D.ts(19, weight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(context.t.pleaseLogInDashboard,
                  style: _D.ts(13.5, color: _D.inkMid),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _goToLogin(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _D.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.t.goToLogin,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_D.primary, _D.primaryLt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _D.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _D.accent.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              style: _D.ts(15, weight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t.hiName(firstName),
                    style: _D.ts(14.5, weight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: _D.ts(11, color: Colors.white.withValues(alpha: 0.65))),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _GreetingBanner extends StatelessWidget {
  const _GreetingBanner({
    this.headline,
    required this.subtitle,
    this.salesCount,
    this.todayCount,
  });

  final String? headline;
  final String subtitle;
  final int? salesCount;
  final int? todayCount;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final title = headline ?? t.businessOverview;
    final sub = headline != null
        ? subtitle
        : t.salesTodayTotal(todayCount ?? 0, salesCount ?? 0);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_D.primary, _D.primaryLt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _D.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: _D.ts(15.5, weight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 3),
                Text(sub,
                    style: _D.ts(11.5, color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _D.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: _D.ts(15, weight: FontWeight.w800, color: _D.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(title,
                  style: _D.ts(10.5, color: _D.inkMid),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _D.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: _D.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(height: 5),
              Text(label,
                  style: _D.ts(10.5, weight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
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
    final created = sale.createdAt;
    final local = created is DateTime
        ? created.toLocal()
        : DateTime.tryParse(created.toString())?.toLocal();
    final dateStr = local == null
        ? ''
        : '${local.year.toString().padLeft(4, '0')}-'
            '${local.month.toString().padLeft(2, '0')}-'
            '${local.day.toString().padLeft(2, '0')}  '
            '${local.hour.toString().padLeft(2, '0')}:'
            '${local.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _D.white,
            borderRadius: BorderRadius.circular(11),
            boxShadow: _D.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _D.accentSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.receipt_rounded,
                    color: _D.accent, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t.saleNumber('${sale.id}'),
                        style: _D.ts(12.5, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(dateStr, style: _D.ts(10.5, color: _D.inkMid)),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format((sale.total as num).toDouble()),
                style: _D.ts(13.5, weight: FontWeight.w800, color: _D.ink),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: _D.inkLight, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({required this.sales});

  final List<dynamic> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return const SizedBox.shrink();

    final values = sales.map<double>((s) => (s.total as num).toDouble()).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _D.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(values.length, (i) {
          final ratio = maxVal > 0 ? values[i] / maxVal : 0.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CurrencyFormatter.format(values[i]),
                style: _D.ts(8, color: _D.inkMid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: Duration(milliseconds: 350 + i * 70),
                width: 24,
                height: (70 * ratio).clamp(4.0, 70.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_D.primaryLt, _D.accent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              const SizedBox(height: 5),
              Text('#${sales[i].id}', style: _D.ts(9, color: _D.inkMid)),
            ],
          );
        }),
      ),
    );
  }
}

class _PaymentBreakdown extends StatelessWidget {
  const _PaymentBreakdown({required this.sales});

  final List<dynamic> sales;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> breakdown = {};
    for (final s in sales) {
      final method = (s.paymentMethod as String? ?? 'unknown').toLowerCase();
      breakdown[method] = (breakdown[method] ?? 0) + (s.total as num);
    }

    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    // Orange/gold intentionally excluded from this palette.
    final colors = [_D.primary, _D.accent, _D.info, _D.primaryLt, _D.danger];
    final entries = breakdown.entries.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _D.cardShadow,
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final pct = total > 0 ? entries[i].value / total : 0.0;
          final color = colors[i % colors.length];
          final key = entries[i].key;
          final t = context.t;
          final label = switch (key) {
            'cash' => t.cash,
            'card' => t.card,
            'mobile' || 'mobile_money' || 'mpesa' => t.mobileMoney,
            'credit' => t.creditDebtBook,
            _ => key.isEmpty
                ? '—'
                : key[0].toUpperCase() + key.substring(1),
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          label,
                          style: _D.ts(12.5, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}%',
                      style: _D.ts(12.5, weight: FontWeight.w700, color: _D.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _D.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _D.cardShadow,
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _D.ts(15, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: _D.ts(12, color: _D.inkMid)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 15),
            ],
          ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _D.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _D.inkLight, size: 28),
            ),
            const SizedBox(height: 12),
            Text(message,
                style: _D.ts(13.5, color: _D.inkMid, weight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _D.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: _D.danger, size: 24),
            ),
            const SizedBox(height: 10),
            Text(context.t.somethingWentWrong,
                style: _D.ts(14.5, weight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(message,
                style: _D.ts(12.5, color: _D.inkMid),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, size: 17),
              label: Text(context.t.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: _D.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
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
      foregroundColor: Colors.white,
      elevation: 4,
      icon: Icon(icon, size: 19),
      label: Text(label,
          style: _D.ts(13.5, weight: FontWeight.w700, color: Colors.white)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TABS
// ════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onReload(),
      color: _D.primary,
      child: BlocConsumer<SalesBloc, SalesState>(
        listener: (context, state) {
          final isTop = ModalRoute.of(context)?.isCurrent ?? true;
          if (_shouldRefetchOn(state, isTop)) {
            onReload();
          }
        },
        builder: (context, state) {
          final isTransient = state is SalesLoading ||
              state is SalesInitial ||
              state is SaleCreated ||
              state is SaleDetailLoaded;

          if (isTransient && state is! SalesLoaded) {
            return Center(
              child: CircularProgressIndicator(color: _D.primary, strokeWidth: 2),
            );
          }

          if (state is SalesError) {
            return _ErrorBody(message: state.message, onRetry: onReload);
          }

          final sales =
              state is SalesLoaded ? state.sales : const <SaleEntity>[];
          final now = DateTime.now();
          final today =
              sales.where((s) => _isSameDay(s.createdAt, now)).toList();

          final t = context.t;
          final totalRev = sales.fold<double>(0, (sum, s) => sum + s.total);
          final todayRev = today.fold<double>(0, (sum, s) => sum + s.total);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    title: t.todaysSales,
                    value: today.length.toString(),
                    icon: Icons.today_rounded,
                    color: _D.primary,
                  ),
                  _StatCard(
                    title: t.todaysRevenue,
                    value: CurrencyFormatter.format(todayRev),
                    icon: Icons.payments_rounded,
                    color: _D.accent,
                  ),
                  _StatCard(
                    title: t.totalSales,
                    value: sales.length.toString(),
                    icon: Icons.receipt_long_rounded,
                    color: _D.info,
                  ),
                  _StatCard(
                    title: t.totalRevenue,
                    value: CurrencyFormatter.format(totalRev),
                    icon: Icons.account_balance_wallet_rounded,
                    color: _D.primaryLt,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(t.quickActions, style: _D.ts(14.5, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _QuickAction(
                          icon: Icons.point_of_sale_rounded,
                          label: t.pos,
                          color: _D.primary,
                          onTap: () => context.push(RouteNames.pos))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _QuickAction(
                          icon: Icons.history_rounded,
                          label: t.sales,
                          color: _D.accent,
                          onTap: () => context.push(RouteNames.sales))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _QuickAction(
                          icon: Icons.inventory_2_outlined,
                          label: t.inventory,
                          color: _D.info,
                          onTap: () => context.push(RouteNames.inventory))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _QuickAction(
                          icon: Icons.badge_outlined,
                          label: t.staff,
                          color: _D.primaryLt,
                          onTap: () => context.push(RouteNames.staff))),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.recentSales, style: _D.ts(14.5, weight: FontWeight.w700)),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => context.push(RouteNames.sales),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(t.seeAll,
                            style: _D.ts(12.5, weight: FontWeight.w600, color: _D.primary)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (sales.isEmpty)
                _EmptyState(
                    icon: Icons.receipt_outlined, message: t.noSalesRecordedYet)
              else
                ...sales.take(4).map((s) => _SaleRow(
                      sale: s,
                      onTap: () => context.push('${RouteNames.sales}/${s.id}'),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onReload(),
      color: _D.primary,
      child: BlocConsumer<SalesBloc, SalesState>(
        listener: (context, state) {
          final isTop = ModalRoute.of(context)?.isCurrent ?? true;
          if (_shouldRefetchOn(state, isTop)) {
            onReload();
          }
        },
        builder: (context, state) {
          final isTransient = state is SalesLoading ||
              state is SalesInitial ||
              state is SaleCreated ||
              state is SaleDetailLoaded;

          if (isTransient && state is! SalesLoaded) {
            return Center(
              child: CircularProgressIndicator(color: _D.primary, strokeWidth: 2),
            );
          }
          if (state is SalesError) {
            return _ErrorBody(message: state.message, onRetry: onReload);
          }

          final t = context.t;
          final sales =
              state is SalesLoaded ? state.sales : const <SaleEntity>[];
          if (sales.isEmpty) {
            return _EmptyState(
                icon: Icons.bar_chart_rounded, message: t.noAnalyticsDataYet);
          }

          final totalRev = sales.fold<double>(0, (sum, s) => sum + s.total);
          final avgOrder = totalRev / sales.length;
          final maxSale =
              sales.map((s) => s.total).reduce((a, b) => a > b ? a : b);
          final lastN = sales.length > 7 ? 7 : sales.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                      title: t.totalRevenue,
                      value: CurrencyFormatter.format(totalRev),
                      icon: Icons.attach_money_rounded,
                      color: _D.accent),
                  _StatCard(
                      title: t.totalTransactions,
                      value: sales.length.toString(),
                      icon: Icons.receipt_rounded,
                      color: _D.primary),
                  _StatCard(
                      title: t.avgOrderValue,
                      value: CurrencyFormatter.format(avgOrder),
                      icon: Icons.trending_up_rounded,
                      color: _D.info),
                  _StatCard(
                      title: t.largestSale,
                      value: CurrencyFormatter.format(maxSale),
                      icon: Icons.star_outline_rounded,
                      color: _D.primaryLt),
                ],
              ),
              const SizedBox(height: 18),
              Text(t.revenueLastNSales(lastN),
                  style: _D.ts(14.5, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              _MiniBarChart(sales: sales.take(7).toList().reversed.toList()),
              const SizedBox(height: 18),
              Text(t.paymentMethods, style: _D.ts(14.5, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              _PaymentBreakdown(sales: sales),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPER
// ════════════════════════════════════════════════════════════════════════════
bool _isSameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}