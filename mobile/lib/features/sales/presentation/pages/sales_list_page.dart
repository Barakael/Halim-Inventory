import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/sale_entity.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';

/// Sales history — same navy / teal tokens as Dashboard & Reports.
class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _S {
  static const bg = Color(0xFFF5F6FA);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1E3A5F);
  static const primaryLt = Color(0xFF2B527A);
  static const accent = Color(0xFF00C896);
  static const accentSoft = Color(0x1A00C896);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0x1A3B82F6);
  static const ink = Color(0xFF1A2332);
  static const inkMid = Color(0xFF64748B);
  static const inkLight = Color(0xFFCBD5E1);
  static const border = Color(0xFFE8EDF5);

  static TextStyle ts(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = ink,
  }) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
}

class _SalesListPageState extends State<SalesListPage> {
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      context.read<SalesBloc>().add(const SalesFetchRequested());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _S.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop(), onReload: _reload),
            Expanded(
              child: BlocBuilder<SalesBloc, SalesState>(
                builder: (context, state) {
                  // After POS, bloc is SaleCreated. After closing a detail page,
                  // bloc may still be SaleDetailLoaded — refetch list only when
                  // THIS route is on top (never while Invoice Details is open).
                  final isTop = ModalRoute.of(context)?.isCurrent ?? true;
                  if (state is SaleCreated ||
                      (state is SaleDetailLoaded && isTop)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          (ModalRoute.of(context)?.isCurrent ?? false)) {
                        _reload();
                      }
                    });
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _S.primary,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (state is SalesLoading || state is SalesInitial) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _S.primary,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (state is SalesError) {
                    return _ErrorBody(
                      message: state.message,
                      onRetry: _reload,
                    );
                  }

                  final sales =
                      state is SalesLoaded ? state.sales : const <SaleEntity>[];

                  if (sales.isEmpty) {
                    return RefreshIndicator(
                      color: _S.primary,
                      onRefresh: () async => _reload(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          _EmptyState(),
                        ],
                      ),
                    );
                  }

                  final totalRev =
                      sales.fold<double>(0, (a, s) => a + s.total);

                  return RefreshIndicator(
                    color: _S.primary,
                    onRefresh: () async => _reload(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _SummaryChip(
                                    label: context.t.transactions,
                                    value: '${sales.length}',
                                    icon: Icons.receipt_long_rounded,
                                    color: _S.info,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SummaryChip(
                                    label: context.t.totalRevenue,
                                    value: CurrencyFormatter.format(totalRev),
                                    icon: Icons.payments_rounded,
                                    color: _S.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                          sliver: SliverList.separated(
                            itemCount: sales.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final sale = sales[index];
                              return _SaleCard(
                                sale: sale,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  context.push(
                                    RouteNames.saleDetail(sale.id),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onReload});

  final VoidCallback onBack;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_S.primary, _S.primaryLt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t.salesHistory,
                    style: _S.ts(17, weight: FontWeight.w700, color: Colors.white)),
                Text(context.t.allCompletedTransactions,
                    style: _S.ts(11, color: Colors.white60)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onReload();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _S.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _S.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _S.ts(11, color: _S.inkMid)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _S.ts(14, weight: FontWeight.w800, color: _S.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.onTap});

  final SaleEntity sale;
  final VoidCallback onTap;

  Color get _payColor {
    switch (sale.paymentMethod.toLowerCase()) {
      case 'cash':
        return _S.accent;
      case 'card':
        return _S.info;
      case 'mobile':
      case 'mobile_money':
      case 'mpesa':
      case 'tigo':
      case 'airtel':
        return const Color(0xFF8B5CF6);
      default:
        return _S.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pay = sale.paymentMethod.isEmpty
        ? 'N/A'
        : sale.paymentMethod[0].toUpperCase() +
            sale.paymentMethod.substring(1).toLowerCase();
    final customer = sale.customerName?.trim();
    final showCustomer = customer != null &&
        customer.isNotEmpty &&
        customer.toLowerCase() != 'walk-in customer' &&
        customer.toLowerCase() != 'walk-in';

    return Material(
      color: _S.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _S.border),
            boxShadow: _S.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _S.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_rounded,
                    color: _S.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.invoiceNo.isNotEmpty
                          ? sale.invoiceNo
                          : '#${sale.id}',
                      style: _S.ts(14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    if (showCustomer)
                      Text(customer,
                          style: _S.ts(12, color: _S.inkMid)),
                    Text(
                      DateFormatter.formatDateTime(sale.createdAt),
                      style: _S.ts(11, color: _S.inkMid),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(sale.total),
                    style: _S.ts(14, weight: FontWeight.w800, color: _S.primary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _payColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pay,
                      style: _S.ts(10, weight: FontWeight.w600, color: _payColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: _S.inkLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _S.infoSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.receipt_outlined, color: _S.info, size: 30),
        ),
        const SizedBox(height: 14),
        Text(context.t.noSalesYet,
            style: _S.ts(15, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(context.t.completedPosWillAppear,
            style: _S.ts(13, color: _S.inkMid)),
      ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFFF4D4D), size: 40),
            const SizedBox(height: 12),
            Text(context.t.somethingWentWrong,
                style: _S.ts(15, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                style: _S.ts(13, color: _S.inkMid),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(context.t.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: _S.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
