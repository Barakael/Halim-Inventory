import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/brand_palette.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_switcher.dart';
import '../../../../core/l10n/locale_cubit.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/customer_entity.dart';
import '../bloc/customers_bloc.dart';

class _T {
  static BrandPalette get _p => BrandTokens.current;
  static Color get bg => _p.bg;
  static Color get white => _p.white;
  static Color get primary => _p.primary;
  static Color get accent => _p.accent;
  static Color get accentSoft => _p.accentSoft;
  static Color get danger => _p.danger;
  static Color get warn => _p.warn;
  static Color get ink => _p.ink;
  static Color get inkMid => _p.inkMid;
  static Color get border => _p.border;

  static TextStyle ts(double size,
          {FontWeight weight = FontWeight.w400, Color? color}) =>
      _p.ts(size, weight: weight, color: color);

  static TextStyle get fieldStyle => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: ink,
      );

  static InputDecoration field({
    required String label,
    String? hint,
    String? helper,
    String? suffix,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      suffixText: suffix,
      prefixIcon: prefixIcon,
      labelStyle: ts(13, color: inkMid),
      floatingLabelStyle: ts(13, weight: FontWeight.w600, color: primary),
      hintStyle: ts(13, color: inkMid),
      helperStyle: ts(11, color: inkMid),
      suffixStyle: ts(13, color: inkMid),
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.8),
      ),
    );
  }
}


/// Owner hub: Customers · Debts · Loyalty discounts for active buyers.
class CustomersHubPage extends StatefulWidget {
  const CustomersHubPage({super.key});

  @override
  State<CustomersHubPage> createState() => _CustomersHubPageState();
}

class _CustomersHubPageState extends State<CustomersHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final CustomersBloc _bloc;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) setState(() {});
      });
    _bloc = sl<CustomersBloc>()
      ..add(const CustomersFetchRequested())
      ..add(const DebtsFetchRequested())
      ..add(const DebtSummaryFetchRequested());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: _T.bg,
        appBar: AppBar(
          backgroundColor: _T.primary,
          foregroundColor: Colors.white,
          title: Text(context.t.customersAndCredit),
          actions: [
            const LanguageHeaderToggle(),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: _T.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: context.t.purchasers),
              Tab(text: context.t.debts),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (_tabs.index == 0) {
              _showCustomerEditor();
            } else {
              _showDebtEditor();
            }
          },
          backgroundColor: _T.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(_tabs.index == 0
              ? context.t.addPurchaser
              : context.t.recordDebt),
        ),
        body: BlocConsumer<CustomersBloc, CustomersState>(
          listener: (context, state) {
            if (state is CustomerActionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _T.accent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is CustomersError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _T.danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          buildWhen: (prev, next) =>
              next is CustomersLoading ||
              next is CustomersLoaded ||
              next is CustomersInitial,
          builder: (context, state) {
            if (state is CustomersLoading) {
              return Center(
                child: CircularProgressIndicator(color: _T.primary),
              );
            }
            final loaded = state is CustomersLoaded
                ? state
                : const CustomersLoaded(customers: []);

            return TabBarView(
              controller: _tabs,
              children: [
                _CustomersTab(
                  customers: loaded.customers,
                  search: _search,
                  onSearch: (q) =>
                      _bloc.add(CustomersFetchRequested(search: q)),
                  onEdit: _showCustomerEditor,
                  onDelete: (c) =>
                      _bloc.add(CustomerDeleteRequested(c.id)),
                  onRefreshLoyalty: (c) =>
                      _bloc.add(CustomerLoyaltyRefreshRequested(c.id)),
                  onSetDiscount: _showDiscountEditor,
                ),
                _DebtsTab(
                  debts: loaded.debts,
                  summary: loaded.summary,
                  onPay: _showPaymentEditor,
                  onRefresh: () {
                    _bloc.add(const DebtsFetchRequested());
                    _bloc.add(const DebtSummaryFetchRequested());
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCustomerEditor([CustomerEntity? customer]) async {
    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final email = TextEditingController(text: customer?.email ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final discount =
        TextEditingController(text: '${customer?.discountPercent ?? 0}');
    var tier = customer?.loyaltyTier ?? 'standard';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _T.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return BlocBuilder<LocaleCubit, Locale>(
          builder: (ctx, locale) {
            final t = AppStrings.fromLocale(locale);
            return Theme(
              data: Theme.of(ctx).copyWith(
                brightness: Brightness.light,
                colorScheme: ColorScheme.light(
                  primary: _T.primary,
                  onPrimary: Colors.white,
                  surface: _T.white,
                  onSurface: _T.ink,
                ),
                textTheme: Theme.of(ctx).textTheme.apply(
                      bodyColor: _T.ink,
                      displayColor: _T.ink,
                    ),
              ),
              child: StatefulBuilder(
                builder: (ctx, setModal) {
                  final inset = MediaQuery.viewInsetsOf(ctx).bottom;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            customer == null ? t.newCustomer : t.editCustomer,
                            style: _T.ts(17, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: name,
                            style: _T.fieldStyle,
                            cursorColor: _T.primary,
                            decoration: _T.field(label: t.nameRequired),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: phone,
                            style: _T.fieldStyle,
                            cursorColor: _T.primary,
                            keyboardType: TextInputType.phone,
                            decoration: _T.field(label: t.phone),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: email,
                            style: _T.fieldStyle,
                            cursorColor: _T.primary,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _T.field(label: t.email),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: address,
                            style: _T.fieldStyle,
                            cursorColor: _T.primary,
                            decoration: _T.field(label: t.address),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: discount,
                            style: _T.fieldStyle,
                            cursorColor: _T.primary,
                            keyboardType: TextInputType.number,
                            decoration: _T.field(
                              label: t.discountPercent,
                              helper: t.discountHelper,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: tier,
                            style: _T.fieldStyle,
                            dropdownColor: _T.white,
                            iconEnabledColor: _T.inkMid,
                            decoration: _T.field(label: t.loyaltyTier),
                            items: [
                              DropdownMenuItem(
                                  value: 'standard',
                                  child: Text(t.tierStandard)),
                              DropdownMenuItem(
                                  value: 'bronze', child: Text(t.tierBronze)),
                              DropdownMenuItem(
                                  value: 'silver', child: Text(t.tierSilver)),
                              DropdownMenuItem(
                                  value: 'gold', child: Text(t.tierGold)),
                            ],
                            onChanged: (v) =>
                                setModal(() => tier = v ?? 'standard'),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              if (name.text.trim().isEmpty) return;
                              Navigator.pop(ctx, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _T.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child:
                                Text(customer == null ? t.create : t.save),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;
    final data = {
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'email': email.text.trim(),
      'address': address.text.trim(),
      'discount_percent': int.tryParse(discount.text.trim()) ?? 0,
      'loyalty_tier': tier,
    };
    if (customer == null) {
      _bloc.add(CustomerCreateRequested(data));
    } else {
      _bloc.add(CustomerUpdateRequested(customer.id, data));
    }
  }

  Future<void> _showDiscountEditor(CustomerEntity customer) async {
    final ctrl =
        TextEditingController(text: '${customer.discountPercent}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => BlocBuilder<LocaleCubit, Locale>(
        builder: (ctx, locale) {
          final t = AppStrings.fromLocale(locale);
          return AlertDialog(
            backgroundColor: _T.white,
            title: Text('${t.discountPercent} · ${customer.name}',
                style: _T.ts(16, weight: FontWeight.w800)),
            content: TextField(
              controller: ctrl,
              style: _T.fieldStyle,
              cursorColor: _T.primary,
              keyboardType: TextInputType.number,
              decoration: _T.field(
                label: t.discountPercent,
                suffix: '%',
                helper: t.discountHelper,
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.save),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    _bloc.add(CustomerUpdateRequested(customer.id, {
      'discount_percent': int.tryParse(ctrl.text.trim()) ?? 0,
    }));
  }

  Future<void> _showDebtEditor() async {
    final customers = _bloc.state is CustomersLoaded
        ? (_bloc.state as CustomersLoaded).customers
        : <CustomerEntity>[];

    String? customerId = customers.isNotEmpty ? customers.first.id : null;
    final name = TextEditingController();
    final phone = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    var useExisting = customers.isNotEmpty;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _T.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return BlocBuilder<LocaleCubit, Locale>(
          builder: (ctx, locale) {
            final t = AppStrings.fromLocale(locale);
            return Theme(
              data: Theme.of(ctx).copyWith(
                brightness: Brightness.light,
                colorScheme: ColorScheme.light(
                  primary: _T.primary,
                  onPrimary: Colors.white,
                  surface: _T.white,
                  onSurface: _T.ink,
                ),
                textTheme: Theme.of(ctx).textTheme.apply(
                      bodyColor: _T.ink,
                      displayColor: _T.ink,
                    ),
              ),
              child: StatefulBuilder(
                builder: (ctx, setModal) {
                  final inset = MediaQuery.viewInsetsOf(ctx).bottom;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(t.recordDebtTitle,
                              style: _T.ts(17, weight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            t.recordDebtHint,
                            style: _T.ts(12, color: _T.inkMid),
                          ),
                          const SizedBox(height: 14),
                          if (customers.isNotEmpty)
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(
                                    value: true,
                                    label: Text(t.existingBuyer)),
                                ButtonSegment(
                                    value: false, label: Text(t.newName)),
                              ],
                              selected: {useExisting},
                              onSelectionChanged: (s) =>
                                  setModal(() => useExisting = s.first),
                            ),
                          const SizedBox(height: 12),
                          if (useExisting && customers.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: customerId,
                              style: _T.fieldStyle,
                              dropdownColor: _T.white,
                              iconEnabledColor: _T.inkMid,
                              decoration: _T.field(label: t.whoOwes),
                              items: customers
                                  .map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name,
                                            style: _T.fieldStyle),
                                      ))
                                  .toList(),
                              onChanged: (v) => setModal(
                                  () => customerId = v ?? customerId),
                            )
                          else ...[
                            TextField(
                              controller: name,
                              style: _T.fieldStyle,
                              cursorColor: _T.primary,
                              decoration: _T.field(
                                label: t.customerNameRequired,
                                hint: t.customerNameHint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: phone,
                              style: _T.fieldStyle,
                              cursorColor: _T.primary,
                              keyboardType: TextInputType.phone,
                              decoration: _T.field(label: t.phone),
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextField(
                            controller: amount,
                            style: _T.fieldStyle,
                            cursorColor: _T.primary,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            decoration:
                                _T.field(label: t.amountOwedRequired),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: note,
                            style: _T.fieldStyle,
                            cursorColor: _T.primary,
                            decoration: _T.field(
                              label: t.whatFor,
                              hint: t.whatForHint,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              if ((double.tryParse(amount.text.trim()) ??
                                      0) <=
                                  0) {
                                return;
                              }
                              if (!useExisting &&
                                  name.text.trim().isEmpty) {
                                return;
                              }
                              Navigator.pop(ctx, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _T.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(t.saveCreditBook),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;
    final payload = <String, dynamic>{
      'amount': double.tryParse(amount.text.trim()) ?? 0,
      'note': note.text.trim(),
    };
    if (useExisting && customerId != null) {
      payload['customer_id'] = int.tryParse(customerId!) ?? customerId;
    } else {
      payload['customer_name'] = name.text.trim();
      payload['customer_phone'] = phone.text.trim();
    }
    _bloc.add(DebtCreateRequested(payload));
  }

  Future<void> _showPaymentEditor(CustomerDebtEntity debt) async {
    final amount = TextEditingController(text: debt.balance.toStringAsFixed(0));
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => BlocBuilder<LocaleCubit, Locale>(
        builder: (ctx, locale) {
          final t = AppStrings.fromLocale(locale);
          return AlertDialog(
            backgroundColor: _T.white,
            title: Text(
                '${t.collectFrom} ${debt.customerName ?? t.customers}',
                style: _T.ts(16, weight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${t.balance}: ${CurrencyFormatter.format(debt.balance)}',
                    style: _T.ts(13, color: _T.inkMid)),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  style: _T.fieldStyle,
                  cursorColor: _T.primary,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _T.field(label: t.amountPaid),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  style: _T.fieldStyle,
                  cursorColor: _T.primary,
                  decoration: _T.field(label: t.note),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.cancel)),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.record),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (value <= 0) return;
    _bloc.add(DebtPaymentRequested(
      debtId: debt.id,
      amount: value,
      note: note.text.trim(),
    ));
  }
}

class _CustomersTab extends StatelessWidget {
  const _CustomersTab({
    required this.customers,
    required this.search,
    required this.onSearch,
    required this.onEdit,
    required this.onDelete,
    required this.onRefreshLoyalty,
    required this.onSetDiscount,
  });

  final List<CustomerEntity> customers;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final void Function([CustomerEntity?]) onEdit;
  final ValueChanged<CustomerEntity> onDelete;
  final ValueChanged<CustomerEntity> onRefreshLoyalty;
  final ValueChanged<CustomerEntity> onSetDiscount;

  @override
  Widget build(BuildContext context) {
    final top = customers.where((c) => c.isTopCustomer).toList();

    return RefreshIndicator(
      color: _T.primary,
      onRefresh: () async {
        context.read<CustomersBloc>().add(const CustomersFetchRequested());
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          TextField(
            controller: search,
            onChanged: onSearch,
            style: _T.fieldStyle,
            cursorColor: _T.primary,
            decoration: _T.field(
              label: context.t.search,
              hint: context.t.searchCustomersHint,
              prefixIcon: Icon(Icons.search_rounded, color: _T.inkMid),
            ).copyWith(
              fillColor: _T.white,
            ),
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(context.t.mostActiveLoyalty,
                style: _T.ts(14, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...top.take(5).map((c) => _CustomerCard(
                  customer: c,
                  highlight: true,
                  onEdit: () => onEdit(c),
                  onDelete: () => onDelete(c),
                  onRefreshLoyalty: () => onRefreshLoyalty(c),
                  onSetDiscount: () => onSetDiscount(c),
                )),
          ],
          const SizedBox(height: 18),
          Text('${customers.length} ${context.t.customersCount}',
              style: _T.ts(13, color: _T.inkMid)),
          const SizedBox(height: 8),
          if (customers.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _T.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _T.border),
              ),
              child: Text(
                context.t.noPurchasersYet,
                style: _T.ts(13, color: _T.inkMid),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...customers.map((c) => _CustomerCard(
                  customer: c,
                  onEdit: () => onEdit(c),
                  onDelete: () => onDelete(c),
                  onRefreshLoyalty: () => onRefreshLoyalty(c),
                  onSetDiscount: () => onSetDiscount(c),
                )),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onRefreshLoyalty,
    required this.onSetDiscount,
    this.highlight = false,
  });

  final CustomerEntity customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefreshLoyalty;
  final VoidCallback onSetDiscount;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? _T.accent.withValues(alpha: 0.4) : _T.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _T.accentSoft,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: _T.ts(16, weight: FontWeight.w800, color: _T.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name,
                        style: _T.ts(15, weight: FontWeight.w700)),
                    Text(
                      [
                        if ((customer.phone ?? '').isNotEmpty) customer.phone,
                        customer.loyaltyTier.toUpperCase(),
                        if (customer.discountPercent > 0)
                          '${customer.discountPercent}% ${context.t.off}',
                      ].join(' · '),
                      style: _T.ts(12, color: _T.inkMid),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                    case 'discount':
                      onSetDiscount();
                    case 'loyalty':
                      onRefreshLoyalty();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (ctx) {
                  final t = ctx.t;
                  return [
                    PopupMenuItem(value: 'edit', child: Text(t.edit)),
                    PopupMenuItem(
                        value: 'discount', child: Text(t.setDiscount)),
                    PopupMenuItem(
                        value: 'loyalty', child: Text(t.autoLoyalty)),
                    PopupMenuItem(value: 'delete', child: Text(t.delete)),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(
                label: '${customer.purchaseCount} ${context.t.purchasesWord}',
                color: _T.primary,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: CurrencyFormatter.format(customer.totalSpent),
                color: _T.accent,
              ),
              if (customer.openDebtBalance > 0) ...[
                const SizedBox(width: 8),
                _StatChip(
                  label:
                      '${context.t.debtLabel} ${CurrencyFormatter.format(customer.openDebtBalance)}',
                  color: _T.danger,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: _T.ts(11, weight: FontWeight.w700, color: color)),
    );
  }
}

class _DebtsTab extends StatelessWidget {
  const _DebtsTab({
    required this.debts,
    required this.summary,
    required this.onPay,
    required this.onRefresh,
  });

  final List<CustomerDebtEntity> debts;
  final DebtSummaryEntity? summary;
  final ValueChanged<CustomerDebtEntity> onPay;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final listedBalance =
        debts.fold<double>(0, (s, d) => s + d.balance);
    final openCount = (summary?.openCount ?? 0) > 0
        ? summary!.openCount
        : debts.length;
    // Prefer API summary, but never show 0 when open debts are listed.
    final toCollect = (summary?.openBalance ?? 0) > 0
        ? summary!.openBalance
        : listedBalance;

    return RefreshIndicator(
      color: _T.primary,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _T.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t.openDebts,
                          style: _T.ts(12, color: _T.inkMid)),
                      Text('$openCount',
                          style: _T.ts(22, weight: FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t.toCollect,
                          style: _T.ts(12, color: _T.inkMid)),
                      Text(
                        CurrencyFormatter.format(toCollect),
                        style: _T.ts(18, weight: FontWeight.w800, color: _T.warn),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (debts.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _T.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _T.border),
              ),
              child: Text(
                context.t.creditBookEmpty,
                style: _T.ts(13, color: _T.inkMid),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...debts.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _T.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _T.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.customerName ?? 'Customer #${d.customerId}',
                                style: _T.ts(15, weight: FontWeight.w700)),
                            Text(
                              '${d.status.toUpperCase()} · ${context.t.balance} ${CurrencyFormatter.format(d.balance)}',
                              style: _T.ts(12, color: _T.inkMid),
                            ),
                            if ((d.note ?? '').isNotEmpty)
                              Text(d.note!,
                                  style: _T.ts(12, color: _T.inkMid)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: d.balance > 0 ? () => onPay(d) : null,
                        child: Text(context.t.collect),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
