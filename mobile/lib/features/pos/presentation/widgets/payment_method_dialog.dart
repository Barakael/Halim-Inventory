import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../../customers/domain/repositories/customers_repository.dart';

class PaymentSelection {
  const PaymentSelection({
    required this.method,
    required this.amountTendered,
    this.customerName,
    this.customerPhone,
    this.shopCustomerId,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.payableTotal,
    this.discountMode = 'loyalty',
  });

  final String method;
  final double amountTendered;
  final String? customerName;
  final String? customerPhone;
  final String? shopCustomerId;
  final int discountPercent;
  final double discountAmount;
  /// Cart total after discount (what the customer pays).
  final double? payableTotal;
  /// loyalty | percent | amount | none
  final String discountMode;
}

class _C {
  static BrandPalette get _p => BrandTokens.current;
  static Color get bg => _p.bg;
  static Color get white => _p.white;
  static Color get primary => _p.primary;
  static Color get accent => _p.accent;
  static Color get info => _p.info;
  static Color get warn => _p.warn;
  static Color get ink => _p.ink;
  static Color get inkMid => _p.inkMid;
  static Color get inkLight => const Color(0xFFCBD5E1);
  static Color get border => _p.border;

  static Color colorOp(Color c, double o) => c.withValues(alpha: o);
}

TextStyle _ts(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? _C.ink,
      letterSpacing: letterSpacing,
    );

/// Payment checkout sheet — pick purchaser to confirm loyalty discount.
class PaymentMethodDialog extends StatefulWidget {
  const PaymentMethodDialog({
    super.key,
    required this.total,
    required this.onConfirm,
  });

  final double total;
  final void Function(PaymentSelection selection) onConfirm;

  static Future<PaymentSelection?> show(
    BuildContext context, {
    required double total,
  }) {
    return showModalBottomSheet<PaymentSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => PaymentMethodDialog(
        total: total,
        onConfirm: (selection) => Navigator.of(ctx).pop(selection),
      ),
    );
  }

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  String? _selected;
  late final TextEditingController _cashAmountCtrl;
  late final TextEditingController _customerNameCtrl;
  late final TextEditingController _customerPhoneCtrl;
  late final TextEditingController _searchCtrl;
  final _cashFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  List<CustomerEntity> _customers = [];
  List<CustomerEntity> _filtered = [];
  CustomerEntity? _selectedCustomer;
  bool _loadingCustomers = true;
  bool _showPicker = false;

  /// loyalty | percent | amount | none
  String _discountMode = 'none';
  late final TextEditingController _manualPercentCtrl;
  late final TextEditingController _manualAmountCtrl;

  int get _loyaltyPercent => _selectedCustomer?.discountPercent ?? 0;

  int get _discountPercent {
    if (_discountMode == 'percent') {
      return int.tryParse(_manualPercentCtrl.text.trim())?.clamp(0, 100) ?? 0;
    }
    if (_discountMode == 'loyalty') return _loyaltyPercent;
    return 0;
  }

  double get _discountAmount {
    if (_discountMode == 'none') return 0;
    if (_discountMode == 'amount') {
      final raw = double.tryParse(
            _manualAmountCtrl.text.replaceAll(',', '').trim(),
          ) ??
          0;
      return double.parse(
        raw.clamp(0, widget.total).toStringAsFixed(2),
      );
    }
    final p = _discountPercent;
    if (p <= 0) return 0;
    return double.parse((widget.total * p / 100).toStringAsFixed(2));
  }

  double get _payable =>
      double.parse((widget.total - _discountAmount).toStringAsFixed(2));

  String get _discountLabel {
    if (_discountAmount <= 0) return '';
    if (_discountMode == 'amount') return context.t.manualDiscount;
    if (_discountMode == 'percent') {
      return '${context.t.discountPercent} $_discountPercent%';
    }
    return '${context.t.loyaltyOff} $_discountPercent%';
  }

  void _syncCashToPayable() {
    _cashAmountCtrl.text = _payable.toStringAsFixed(0);
  }

  void _setDiscountMode(String mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _discountMode = mode;
      _syncCashToPayable();
    });
  }

  @override
  void initState() {
    super.initState();
    _cashAmountCtrl = TextEditingController(
      text: widget.total.toStringAsFixed(0),
    );
    _customerNameCtrl = TextEditingController();
    _customerPhoneCtrl = TextEditingController();
    _searchCtrl = TextEditingController();
    _manualPercentCtrl = TextEditingController();
    _manualAmountCtrl = TextEditingController();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await sl<CustomersRepository>().getCustomers();
      if (!mounted) return;
      setState(() {
        _customers = list;
        _filtered = list;
        _loadingCustomers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCustomers = false);
    }
  }

  void _filterCustomers(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _customers;
      } else {
        _filtered = _customers
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                (c.phone ?? '').toLowerCase().contains(query) ||
                (c.email ?? '').toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _pickCustomer(CustomerEntity c) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCustomer = c;
      _showPicker = false;
      _customerNameCtrl.text = c.name;
      _customerPhoneCtrl.text = c.phone ?? '';
      _searchCtrl.clear();
      _filtered = _customers;
      // Prefer loyalty when picking a customer who has a %.
      if (c.discountPercent > 0 &&
          (_discountMode == 'loyalty' || _discountMode == 'none')) {
        _discountMode = 'loyalty';
      }
      _syncCashToPayable();
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
      if (_discountMode == 'loyalty') {
        _discountMode = 'none';
      }
      _syncCashToPayable();
    });
  }

  @override
  void dispose() {
    _cashAmountCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _searchCtrl.dispose();
    _manualPercentCtrl.dispose();
    _manualAmountCtrl.dispose();
    _cashFocus.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _select(String method) {
    HapticFeedback.selectionClick();
    setState(() => _selected = method);
    if (method == 'cash') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cashFocus.requestFocus();
      });
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _confirm() {
    if (_selected == null) return;
    // Credit requires a named purchaser
    if (_selected == 'credit' &&
        _selectedCustomer == null &&
        _customerNameCtrl.text.trim().isEmpty &&
        _customerPhoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.creditNeedsCustomer),
        ),
      );
      return;
    }

    if (_discountMode == 'percent') {
      final p = int.tryParse(_manualPercentCtrl.text.trim());
      if (p == null || p < 0 || p > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.enterValidDiscountPercent)),
        );
        return;
      }
    }
    if (_discountMode == 'amount') {
      final raw = double.tryParse(
        _manualAmountCtrl.text.replaceAll(',', '').trim(),
      );
      if (raw == null || raw < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.enterValidDiscountAmount)),
        );
        return;
      }
    }

    HapticFeedback.mediumImpact();

    final due = _payable;
    double amount = due;
    if (_selected == 'cash') {
      final parsed =
          double.tryParse(_cashAmountCtrl.text.replaceAll(',', '').trim());
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount tendered')),
        );
        return;
      }
      if (parsed < due) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount must be at least ${CurrencyFormatter.format(due)}',
            ),
          ),
        );
        return;
      }
      amount = parsed;
    }

    FocusScope.of(context).unfocus();
    widget.onConfirm(PaymentSelection(
      method: _selected!,
      amountTendered: amount,
      shopCustomerId: _selectedCustomer?.id,
      customerName: _customerNameCtrl.text.trim().isEmpty
          ? null
          : _customerNameCtrl.text.trim(),
      customerPhone: _customerPhoneCtrl.text.trim().isEmpty
          ? null
          : _customerPhoneCtrl.text.trim(),
      discountPercent: _discountPercent,
      discountAmount: _discountAmount,
      payableTotal: due,
      discountMode: _discountMode,
    ));
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: _ts(13, color: _C.inkMid, weight: FontWeight.w500),
      floatingLabelStyle: _ts(13, color: _C.primary, weight: FontWeight.w600),
      hintStyle: _ts(14, color: _C.inkLight),
      filled: true,
      fillColor: _C.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _C.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: _C.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.inkLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Text(t.checkout,
                          style: _ts(18, weight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                // Amount due (updates when loyalty discount applies)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: _C.bg,
                    border: Border(bottom: BorderSide(color: _C.border)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.cartTotal,
                              style: _ts(13,
                                  color: _C.inkMid, weight: FontWeight.w600)),
                          Text(
                            CurrencyFormatter.format(widget.total),
                            style: _ts(15,
                                weight: FontWeight.w600, color: _C.inkMid),
                          ),
                        ],
                      ),
                      if (_discountAmount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                _discountLabel,
                                style: _ts(13,
                                    color: _C.accent, weight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '- ${CurrencyFormatter.format(_discountAmount)}',
                              style: _ts(14,
                                  weight: FontWeight.w700, color: _C.accent),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.amountDue,
                              style: _ts(13,
                                  color: _C.inkMid, weight: FontWeight.w600)),
                          Text(
                            CurrencyFormatter.format(_payable),
                            style: _ts(21,
                                weight: FontWeight.w800, color: _C.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.purchaser.toUpperCase(),
                            style: _ts(11,
                                color: _C.inkMid,
                                weight: FontWeight.w700,
                                letterSpacing: 0.4)),
                        const SizedBox(height: 6),
                        Text(
                          t.selectPurchaserHint,
                          style: _ts(12, color: _C.inkMid),
                        ),
                        const SizedBox(height: 10),

                        // Pick existing
                        OutlinedButton.icon(
                          onPressed: _loadingCustomers
                              ? null
                              : () => setState(() => _showPicker = !_showPicker),
                          icon: Icon(
                            _showPicker
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.person_search_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _loadingCustomers
                                ? t.loadingCustomers
                                : (_selectedCustomer != null
                                    ? t.changePurchaser
                                    : t.selectSavedPurchaser),
                            style: _ts(13, weight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.primary,
                            minimumSize: const Size(double.infinity, 44),
                            side: BorderSide(color: _C.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        if (_showPicker) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchCtrl,
                            style: _ts(14, color: _C.ink),
                            cursorColor: _C.primary,
                            onChanged: _filterCustomers,
                            decoration: _fieldDecoration(
                              'Search',
                              hint: 'Name or phone…',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _C.border),
                            ),
                            child: _filtered.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No purchasers found. Add them under Customers, or type a name below.',
                                      style: _ts(12, color: _C.inkMid),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: _filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final c = _filtered[i];
                                      final selected =
                                          _selectedCustomer?.id == c.id;
                                      return ListTile(
                                        dense: true,
                                        selected: selected,
                                        selectedTileColor:
                                            _C.colorOp(_C.accent, 0.12),
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              _C.colorOp(_C.primary, 0.1),
                                          child: Text(
                                            c.name.isNotEmpty
                                                ? c.name[0].toUpperCase()
                                                : '?',
                                            style: _ts(12,
                                                weight: FontWeight.w800,
                                                color: _C.primary),
                                          ),
                                        ),
                                        title: Text(c.name,
                                            style: _ts(13,
                                                weight: FontWeight.w700)),
                                        subtitle: Text(
                                          [
                                            if ((c.phone ?? '').isNotEmpty)
                                              c.phone,
                                            c.loyaltyTier.toUpperCase(),
                                            if (c.discountPercent > 0)
                                              '${c.discountPercent}% off',
                                          ].join(' · '),
                                          style: _ts(11, color: _C.inkMid),
                                        ),
                                        trailing: selected
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: _C.accent,
                                                size: 20,
                                              )
                                            : null,
                                        onTap: () => _pickCustomer(c),
                                      );
                                    },
                                  ),
                          ),
                        ],

                        if (_selectedCustomer != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _C.colorOp(_C.accent, 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _C.colorOp(_C.accent, 0.35)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_rounded,
                                    color: _C.accent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedCustomer!.name,
                                        style: _ts(14, weight: FontWeight.w800),
                                      ),
                                      Text(
                                        [
                                          _selectedCustomer!.loyaltyTier
                                              .toUpperCase(),
                                          if (_loyaltyPercent > 0)
                                            '$_loyaltyPercent% loyalty discount',
                                          if (_loyaltyPercent == 0)
                                            'No discount set',
                                        ].join(' · '),
                                        style: _ts(12, color: _C.inkMid),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _clearCustomer,
                                  icon: Icon(Icons.close_rounded,
                                      size: 18),
                                  color: _C.inkMid,
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        TextField(
                          controller: _customerNameCtrl,
                          focusNode: _nameFocus,
                          style:
                              _ts(14, color: _C.ink, weight: FontWeight.w500),
                          cursorColor: _C.primary,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            // Typing manually clears linked id (walk-in / new)
                            if (_selectedCustomer != null &&
                                _customerNameCtrl.text.trim() !=
                                    _selectedCustomer!.name) {
                              setState(() => _selectedCustomer = null);
                            }
                          },
                          onSubmitted: (_) => _phoneFocus.requestFocus(),
                          decoration: _fieldDecoration(t.walkInName),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customerPhoneCtrl,
                          focusNode: _phoneFocus,
                          style:
                              _ts(14, color: _C.ink, weight: FontWeight.w500),
                          cursorColor: _C.primary,
                          keyboardType: TextInputType.phone,
                          textInputAction: _selected == 'cash'
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onSubmitted: (_) {
                            if (_selected == 'cash') {
                              _cashFocus.requestFocus();
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          },
                          decoration: _fieldDecoration(t.phone),
                        ),
                        const SizedBox(height: 20),
                        Text(t.discountSection.toUpperCase(),
                            style: _ts(11,
                                color: _C.inkMid,
                                weight: FontWeight.w700,
                                letterSpacing: 0.4)),
                        const SizedBox(height: 6),
                        Text(
                          t.discountSectionHint,
                          style: _ts(12, color: _C.inkMid),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DiscountModeChip(
                              label: t.discountNone,
                              selected: _discountMode == 'none',
                              onTap: () => _setDiscountMode('none'),
                            ),
                            if (_loyaltyPercent > 0)
                              _DiscountModeChip(
                                label: '${t.loyaltyOff} $_loyaltyPercent%',
                                selected: _discountMode == 'loyalty',
                                onTap: () => _setDiscountMode('loyalty'),
                              ),
                            _DiscountModeChip(
                              label: t.discountByPercent,
                              selected: _discountMode == 'percent',
                              onTap: () => _setDiscountMode('percent'),
                            ),
                            _DiscountModeChip(
                              label: t.discountByAmount,
                              selected: _discountMode == 'amount',
                              onTap: () => _setDiscountMode('amount'),
                            ),
                          ],
                        ),
                        if (_discountMode == 'percent') ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _manualPercentCtrl,
                            style: _ts(14,
                                color: _C.ink, weight: FontWeight.w600),
                            cursorColor: _C.primary,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(_syncCashToPayable),
                            decoration: _fieldDecoration(
                              t.discountPercent,
                              hint: '0 – 100',
                            ),
                          ),
                        ],
                        if (_discountMode == 'amount') ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _manualAmountCtrl,
                            style: _ts(14,
                                color: _C.ink, weight: FontWeight.w600),
                            cursorColor: _C.primary,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.,]'),
                              ),
                            ],
                            onChanged: (_) => setState(_syncCashToPayable),
                            decoration: _fieldDecoration(
                              t.manualDiscountAmount,
                              hint: CurrencyFormatter.format(0),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(t.paymentMethod.toUpperCase(),
                            style: _ts(11,
                                color: _C.inkMid,
                                weight: FontWeight.w700,
                                letterSpacing: 0.4)),
                        const SizedBox(height: 10),
                        _PayOption(
                          icon: Icons.payments_rounded,
                          label: t.cash,
                          description: t.cashDesc,
                          color: _C.accent,
                          selected: _selected == 'cash',
                          onTap: () => _select('cash'),
                        ),
                        if (_selected == 'cash') ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _cashAmountCtrl,
                            focusNode: _cashFocus,
                            style:
                                _ts(14, color: _C.ink, weight: FontWeight.w600),
                            cursorColor: _C.primary,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.,]'),
                              ),
                            ],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _confirm(),
                            decoration: _fieldDecoration(
                              'Amount tendered',
                              hint: CurrencyFormatter.format(_payable),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _PayOption(
                          icon: Icons.credit_card_rounded,
                          label: t.card,
                          description: t.cardDesc,
                          color: _C.info,
                          selected: _selected == 'card',
                          onTap: () => _select('card'),
                        ),
                        const SizedBox(height: 10),
                        _PayOption(
                          icon: Icons.smartphone_rounded,
                          label: t.mobileMoney,
                          description: t.mobileDesc,
                          color: _C.warn,
                          selected: _selected == 'mobile',
                          onTap: () => _select('mobile'),
                        ),
                        const SizedBox(height: 10),
                        _PayOption(
                          icon: Icons.menu_book_rounded,
                          label: t.creditDebtBook,
                          description: t.creditDesc,
                          color: _C.primary,
                          selected: _selected == 'credit',
                          onTap: () => _select('credit'),
                        ),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _C.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: _C.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(t.cancel,
                                style: _ts(14,
                                    weight: FontWeight.w600,
                                    color: _C.inkMid)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _selected == null ? null : _confirm,
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _selected == null
                                  ? t.selectMethod
                                  : (_discountAmount > 0
                                      ? '${t.confirmWithAmount} · ${CurrencyFormatter.format(_payable)}'
                                      : t.confirmPayment),
                              style: _ts(13,
                                  weight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: _selected == null
                                  ? _C.inkLight
                                  : _C.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _C.inkLight,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscountModeChip extends StatelessWidget {
  const _DiscountModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _C.primary : _C.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _C.primary : _C.border),
        ),
        child: Text(
          label,
          style: _ts(
            12,
            weight: FontWeight.w700,
            color: selected ? Colors.white : _C.inkMid,
          ),
        ),
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _C.colorOp(color, 0.1) : _C.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : _C.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _C.colorOp(color, 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _ts(14, weight: FontWeight.w700)),
                    Text(description, style: _ts(12, color: _C.inkMid)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? color : _C.inkLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
