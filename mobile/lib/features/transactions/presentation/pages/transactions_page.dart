import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/transaction_entity.dart';
import '../bloc/transactions_bloc.dart';
import '../bloc/transactions_event.dart';
import '../bloc/transactions_state.dart';

/// Transactions — navy / teal tokens matching Dashboard, Reports, Sales.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _T {
  static const bg = Color(0xFFF5F6FA);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1E3A5F);
  static const primaryLt = Color(0xFF2B527A);
  static const accent = Color(0xFF00C896);
  static const accentSoft = Color(0x1A00C896);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0x1A3B82F6);
  static const warn = Color(0xFFFFA726);
  static const warnSoft = Color(0x1AFFA726);
  static const danger = Color(0xFFFF4D4D);
  static const dangerSoft = Color(0x1AFF4D4D);
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

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    context.read<TransactionsBloc>().add(
          TransactionsFetchRequested(
            date: _selectedDate != null
                ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                : null,
          ),
        );
  }

  List<TransactionEntity> _filter(List<TransactionEntity> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((t) {
      return t.id.toLowerCase().contains(q) ||
          t.displayRef.toLowerCase().contains(q) ||
          t.cashierName.toLowerCase().contains(q) ||
          t.paymentMethod.toLowerCase().contains(q) ||
          (t.customerName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _T.primary,
              onPrimary: Colors.white,
              surface: _T.white,
              onSurface: _T.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return;
    setState(() => _selectedDate = date);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _T.bg,
      ),
      child: Scaffold(
        backgroundColor: _T.bg,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
                onReload: () {
                  HapticFeedback.lightImpact();
                  _reload();
                },
              ),
              Expanded(
                child: BlocConsumer<TransactionsBloc, TransactionsState>(
                  listener: (context, state) {
                    if (state is TransactionsError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: _T.danger,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    final all = state is TransactionsLoaded
                        ? state.transactions
                        : const <TransactionEntity>[];
                    final filtered = _filter(all);
                    final totalRev =
                        filtered.fold<double>(0, (a, t) => a + t.total);

                    return RefreshIndicator(
                      color: _T.primary,
                      onRefresh: () async => _reload(),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 14, 14, 0),
                              child: Column(
                                children: [
                                  _SearchField(
                                    controller: _searchController,
                                    onChanged: (v) =>
                                        setState(() => _searchQuery = v),
                                  ),
                                  const SizedBox(height: 10),
                                  _DateFilterChip(
                                    selected: _selectedDate,
                                    onTap: _pickDate,
                                    onClear: () {
                                      setState(() => _selectedDate = null);
                                      _reload();
                                    },
                                  ),
                                  if (state is TransactionsLoaded &&
                                      filtered.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SummaryChip(
                                            label: 'Shown',
                                            value: '${filtered.length}',
                                            icon: Icons.receipt_long_rounded,
                                            color: _T.info,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _SummaryChip(
                                            label: 'Revenue',
                                            value: CurrencyFormatter.format(
                                                totalRev),
                                            icon: Icons.payments_rounded,
                                            color: _T.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (state is TransactionsLoading ||
                              state is TransactionsInitial)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: _T.primary,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          else if (state is TransactionsError)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(
                                message: state.message,
                                onRetry: _reload,
                              ),
                            )
                          else if (filtered.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(
                                message: _searchQuery.isNotEmpty ||
                                        _selectedDate != null
                                    ? 'No transactions match your filters'
                                    : 'No transactions yet',
                                onRetry: _reload,
                              ),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 14, 90),
                              sliver: SliverList.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final tx = filtered[index];
                                  return _TransactionCard(
                                    transaction: tx,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      if (tx.id.isNotEmpty) {
                                        context.push(
                                          RouteNames.saleDetail(tx.id),
                                        );
                                      }
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
          colors: [_T.primary, _T.primaryLt],
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
                Text(context.t.transactions,
                    style: _T.ts(17,
                        weight: FontWeight.w700, color: Colors.white)),
                Text(context.t.transactionsSubtitle,
                    style: _T.ts(11, color: Colors.white60)),
              ],
            ),
          ),
          IconButton(
            onPressed: onReload,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border),
        boxShadow: _T.cardShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: _T.ts(14),
        decoration: InputDecoration(
          hintText: 'Search invoice, cashier, payment…',
          hintStyle: _T.ts(13, color: _T.inkMid),
          prefixIcon:
              const Icon(Icons.search_rounded, color: _T.inkMid, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.selected,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? selected;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _T.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: _T.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected != null
                      ? DateFormat('EEE, MMM d, yyyy').format(selected!)
                      : 'Filter by date',
                  style: _T.ts(
                    13,
                    weight: FontWeight.w600,
                    color: selected != null ? _T.ink : _T.inkMid,
                  ),
                ),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded,
                      color: _T.inkMid, size: 18),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: _T.inkLight, size: 20),
            ],
          ),
        ),
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
        color: _T.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _T.cardShadow,
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
                Text(label, style: _T.ts(11, color: _T.inkMid)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _T.ts(13, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final VoidCallback onTap;

  Color get _payColor {
    switch (transaction.paymentMethod.toLowerCase()) {
      case 'cash':
        return _T.accent;
      case 'card':
        return _T.info;
      case 'mobile':
      case 'mobile_money':
      case 'mpesa':
        return const Color(0xFF8B5CF6);
      default:
        return _T.primary;
    }
  }

  (Color, Color) get _statusColors {
    switch (transaction.status.toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'success':
        return (_T.accent, _T.accentSoft);
      case 'pending':
        return (_T.warn, _T.warnSoft);
      case 'failed':
      case 'cancelled':
      case 'canceled':
        return (_T.danger, _T.dangerSoft);
      default:
        return (_T.accent, _T.accentSoft);
    }
  }

  bool get _showCustomer {
    final c = transaction.customerName?.trim();
    if (c == null || c.isEmpty) return false;
    final lower = c.toLowerCase();
    return lower != 'walk-in customer' && lower != 'walk-in';
  }

  @override
  Widget build(BuildContext context) {
    final pay = transaction.paymentMethod.isEmpty
        ? 'N/A'
        : transaction.paymentMethod[0].toUpperCase() +
            transaction.paymentMethod.substring(1).toLowerCase();
    final status = transaction.status.isEmpty
        ? 'Completed'
        : transaction.status[0].toUpperCase() +
            transaction.status.substring(1);
    final (statusFg, statusBg) = _statusColors;

    return Material(
      color: _T.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _T.border),
            boxShadow: _T.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _T.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_rounded,
                        color: _T.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.displayRef,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _T.ts(14, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy · HH:mm')
                              .format(transaction.createdAt.toLocal()),
                          style: _T.ts(11, color: _T.inkMid),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: _T.ts(10,
                          weight: FontWeight.w700, color: statusFg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Meta(
                      label: 'Cashier',
                      value: transaction.cashierName,
                    ),
                  ),
                  Expanded(
                    child: _Meta(
                      label: 'Payment',
                      value: pay,
                      valueColor: _payColor,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(transaction.total),
                        style: _T.ts(14,
                            weight: FontWeight.w800, color: _T.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${transaction.items.length} item${transaction.items.length == 1 ? '' : 's'}',
                        style: _T.ts(10, color: _T.inkMid),
                      ),
                    ],
                  ),
                ],
              ),
              if (_showCustomer) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: _T.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 15, color: _T.inkMid),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        transaction.customerName!,
                        style: _T.ts(12, color: _T.inkMid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: _T.inkLight, size: 18),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _T.ts(10, color: _T.inkMid)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _T.ts(12,
              weight: FontWeight.w600, color: valueColor ?? _T.ink),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _T.infoSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: _T.info, size: 30),
            ),
            const SizedBox(height: 14),
            Text(message,
                style: _T.ts(14, weight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Pull to refresh or clear filters',
              style: _T.ts(12, color: _T.inkMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(context.t.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.primary,
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
