import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/validators.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';

// ════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ════════════════════════════════════════════════════════════════════════════
class _C {
  static const bg        = Color(0xFFF5F6FA);
  static const white     = Color(0xFFFFFFFF);
  static const primary   = Color(0xFF1E3A5F);
  static const primaryLt = Color(0xFF2B527A);
  static const accent    = Color(0xFF00C896);
  static const accentSoft= Color(0x1A00C896);
  static const info      = Color(0xFF3B82F6);
  static const infoSoft  = Color(0x1A3B82F6);
  static const warn      = Color(0xFFFFA726);
  static const warnSoft  = Color(0x1AFFA726);
  static const danger    = Color(0xFFFF4D4D);
  static const dangerSoft= Color(0x1AFF4D4D);
  static const ink       = Color(0xFF1A2332);
  static const inkMid    = Color(0xFF64748B);
  static const inkLight  = Color(0xFFCBD5E1);
  static const border    = Color(0xFFE8EDF5);

  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF1E3A5F).withValues(alpha: 0.06),
      blurRadius: 12, offset: const Offset(0, 4),
    ),
  ];
}

TextStyle _ts(double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _C.ink,
  double? letterSpacing,
}) => TextStyle(
  fontSize: size, fontWeight: weight,
  color: color, letterSpacing: letterSpacing,
);

// ════════════════════════════════════════════════════════════════════════════
// PAGE
// ════════════════════════════════════════════════════════════════════════════
class CreateSalePage extends StatefulWidget {
  const CreateSalePage({super.key});

  @override
  State<CreateSalePage> createState() => _CreateSalePageState();
}

class _CreateSalePageState extends State<CreateSalePage> {
  final _formKey              = GlobalKey<FormState>();
  final _customerNameCtrl     = TextEditingController();
  final _customerPhoneCtrl    = TextEditingController();

  String _paymentMethod = 'CASH';
  String _taxType       = 'STANDARD';
  String _vatType       = 'INCLUSIVE';

  final List<_SaleItemEntry> _items = [];

  // Running totals
  double get _subtotal => _items.fold(0.0, (sum, i) {
    final qty   = double.tryParse(i.quantityController.text) ?? 0;
    final price = double.tryParse(i.priceController.text) ?? 0;
    return sum + qty * price;
  });
  double get _tax   => _subtotal * 0.18;
  double get _total => _subtotal + _tax;

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    HapticFeedback.selectionClick();
    setState(() => _items.add(_SaleItemEntry()));
  }

  void _removeItem(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: isError ? _C.danger : _C.accent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(msg,
                style: _ts(13,
                    weight: FontWeight.w500, color: Colors.white)),
          ),
        ]),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      _toast('Add at least one item', isError: true);
      return;
    }

    final saleData = {
      'paymentMethod': _paymentMethod,
      'taxType':       _taxType,
      'vatType':       _vatType,
      if (_customerNameCtrl.text.isNotEmpty)
        'customerName': _customerNameCtrl.text,
      if (_customerPhoneCtrl.text.isNotEmpty)
        'customerPhone': _customerPhoneCtrl.text,
      'items': _items.map((item) => {
        'productId': item.productIdController.text,
        'quantity':  int.tryParse(item.quantityController.text) ?? 1,
        'unitPrice': double.tryParse(item.priceController.text) ?? 0.0,
      }).toList(),
    };

    context.read<SalesBloc>().add(SaleCreateRequested(saleData));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesBloc, SalesState>(
      listener: (context, state) {
        if (state is SaleCreated) {
          _toast('Sale created successfully!');
          context.go(RouteNames.sales);
        } else if (state is SalesError) {
          _toast(state.message, isError: true);
        }
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Column(children: [
            // ── Top bar
            _TopBar(),

            // ── Scrollable form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    _SectionCard(
                      icon:  Icons.person_outline_rounded,
                      color: _C.info,
                      title: 'Customer Info',
                      badge: 'Optional',
                      child: Column(children: [
                        _Field(
                          controller:   _customerNameCtrl,
                          label:        'Customer Name',
                          icon:         Icons.badge_outlined,
                          inputAction:  TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller:  _customerPhoneCtrl,
                          label:       'Phone Number',
                          icon:        Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      icon:  Icons.tune_rounded,
                      color: _C.warn,
                      title: 'Tax & Payment',
                      child: Column(children: [
                        _DropField(
                          label:     'Tax Type',
                          value:     _taxType,
                          icon:      Icons.receipt_long_rounded,
                          items:     const [
                            'STANDARD', 'ZERO_RATED',
                            'SPECIAL_RELIEF', 'EXEMPT'
                          ],
                          onChanged: (v) => setState(() => _taxType = v!),
                        ),
                        const SizedBox(height: 12),
                        _DropField(
                          label:     'VAT Type',
                          value:     _vatType,
                          icon:      Icons.percent_rounded,
                          items:     const ['INCLUSIVE', 'EXCLUSIVE'],
                          onChanged: (v) => setState(() => _vatType = v!),
                        ),
                        const SizedBox(height: 12),
                        _DropField(
                          label:     'Payment Method',
                          value:     _paymentMethod,
                          icon:      Icons.payments_rounded,
                          items:     const [
                            'CASH', 'E_MONEY',
                            'BANK_TRANSFER', 'CREDIT_CARD', 'CHEQUE'
                          ],
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Items section
                    _ItemsSection(
                      items:     _items,
                      onAdd:     _addItem,
                      onRemove:  _removeItem,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Order summary
                    if (_items.isNotEmpty)
                      _OrderSummary(
                        subtotal: _subtotal,
                        tax:      _tax,
                        total:    _total,
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ),

        // ── Sticky bottom submit
        bottomNavigationBar: _BottomBar(
          itemCount: _items.length,
          total:     _total,
          onSubmit:  _submit,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: BoxDecoration(
        color: _C.primary,
        boxShadow: [
          BoxShadow(
            color: _C.primary.withValues(alpha: 0.3),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _C.accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.receipt_long_rounded,
              color: _C.accent, size: 18),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New Sale',
              style: _ts(15, weight: FontWeight.w700, color: Colors.white)),
          Text('Fill in the details below',
              style: _ts(11, color: Colors.white60)),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
    this.badge,
  }) : trailing = null;
  final IconData   icon;
  final Color      color;
  final String     title;
  final Widget     child;
  final String?    badge;
  final Widget?    trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _C.card,
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: _ts(14, weight: FontWeight.w700)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.inkLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!,
                    style: _ts(10,
                        weight: FontWeight.w600, color: _C.inkMid)),
              ),
            ],
            const Spacer(),
            if (trailing != null) trailing!,
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ITEMS SECTION
// ════════════════════════════════════════════════════════════════════════════
class _ItemsSection extends StatelessWidget {
  const _ItemsSection({
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });
  final List<_SaleItemEntry> items;
  final VoidCallback         onAdd, onChanged;
  final void Function(int)   onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _C.card,
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: _C.accentSoft,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _C.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  color: _C.accent, size: 17),
            ),
            const SizedBox(width: 10),
            Text('Sale Items',
                style: _ts(14, weight: FontWeight.w700)),
            if (items.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${items.length}',
                    style: _ts(10,
                        weight: FontWeight.w700, color: Colors.white)),
              ),
            ],
            const Spacer(),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _C.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded,
                      color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Text('Add Item',
                      style: _ts(12,
                          weight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),

        // Empty state
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _C.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_shopping_cart_rounded,
                    color: _C.accent, size: 24),
              ),
              const SizedBox(height: 12),
              Text('No items added yet',
                  style: _ts(14,
                      weight: FontWeight.w600, color: _C.inkMid)),
              const SizedBox(height: 4),
              Text('Tap "Add Item" to get started',
                  style: _ts(12, color: _C.inkLight)),
            ]),
          )
        else
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: items.asMap().entries.map((e) =>
                _SaleItemRow(
                  item:      e.value,
                  index:     e.key,
                  onRemove:  () => onRemove(e.key),
                  onChanged: onChanged,
                ),
              ).toList(),
            ),
          ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SALE ITEM ROW
// ════════════════════════════════════════════════════════════════════════════
class _SaleItemRow extends StatelessWidget {
  const _SaleItemRow({
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });
  final _SaleItemEntry item;
  final int            index;
  final VoidCallback   onRemove, onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row header
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: _ts(11,
                      weight: FontWeight.w700, color: _C.primary)),
            ),
          ),
          const SizedBox(width: 8),
          Text('Item ${index + 1}',
              style: _ts(13, weight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _C.dangerSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.delete_outline_rounded,
                    color: _C.danger, size: 13),
                const SizedBox(width: 4),
                Text('Remove',
                    style: _ts(11,
                        weight: FontWeight.w600, color: _C.danger)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // Product ID
        _Field(
          controller:  item.productIdController,
          label:       'Product ID',
          icon:        Icons.inventory_2_outlined,
          validator:   (v) => Validators.required(v, 'Product'),
          onChanged:   (_) => onChanged(),
        ),
        const SizedBox(height: 10),

        // Qty + Price side by side
        Row(children: [
          Expanded(
            child: _Field(
              controller:   item.quantityController,
              label:        'Quantity',
              icon:         Icons.numbers_rounded,
              keyboardType: TextInputType.number,
              validator:    (v) => Validators.positiveNumber(v, 'Qty'),
              onChanged:    (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _Field(
              controller:   item.priceController,
              label:        'Unit Price',
              icon:         Icons.sell_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator:    (v) => Validators.positiveNumber(v, 'Price'),
              onChanged:    (_) => onChanged(),
              prefix:       'TZS',
            ),
          ),
        ]),

        // Line total
        if (item.quantityController.text.isNotEmpty &&
            item.priceController.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Line Total',
                    style: _ts(12, color: _C.inkMid)),
                Text(
                  _lineTotal(item),
                  style: _ts(13,
                      weight: FontWeight.w700, color: _C.primary),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  String _lineTotal(_SaleItemEntry item) {
    final qty   = double.tryParse(item.quantityController.text) ?? 0;
    final price = double.tryParse(item.priceController.text) ?? 0;
    final total = qty * price;
    return 'TZS ${total.toStringAsFixed(2)}';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ORDER SUMMARY
// ════════════════════════════════════════════════════════════════════════════
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.subtotal,
    required this.tax,
    required this.total,
  });
  final double subtotal, tax, total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _C.card,
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: _C.primary.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: _C.border)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _C.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calculate_outlined,
                  color: _C.primary, size: 17),
            ),
            const SizedBox(width: 10),
            Text('Order Summary',
                style: _ts(14, weight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _SummRow('Subtotal',  'TZS ${subtotal.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _SummRow('VAT (18%)', 'TZS ${tax.toStringAsFixed(2)}'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: _C.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: _ts(16, weight: FontWeight.w700)),
                Text('TZS ${total.toStringAsFixed(2)}',
                    style: _ts(18,
                        weight: FontWeight.w800, color: _C.primary)),
              ],
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SummRow extends StatelessWidget {
  const _SummRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _ts(13, color: _C.inkMid)),
        Text(value,
            style: _ts(13, weight: FontWeight.w600, color: _C.ink)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOTTOM SUBMIT BAR
// ════════════════════════════════════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.itemCount,
    required this.total,
    required this.onSubmit,
  });
  final int          itemCount;
  final double       total;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: _C.white,
        boxShadow: [
          BoxShadow(
            color: _C.primary.withValues(alpha: 0.1),
            blurRadius: 16, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BlocBuilder<SalesBloc, SalesState>(
        builder: (_, state) {
          final loading = state is SalesLoading;
          return Row(children: [
            // Summary pill
            if (itemCount > 0) ...[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$itemCount item${itemCount > 1 ? 's' : ''}',
                        style: _ts(11, color: _C.inkMid)),
                    Text(
                      'TZS ${total.toStringAsFixed(2)}',
                      style: _ts(16,
                          weight: FontWeight.w800, color: _C.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: itemCount > 0 ? 2 : 1,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : onSubmit,
                  icon: loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded,
                          size: 20),
                  label: Text(
                    loading ? 'Creating Sale…' : 'Create Sale',
                    style: _ts(15,
                        weight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// REUSABLE FIELD
// ════════════════════════════════════════════════════════════════════════════
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputAction,
    this.validator,
    this.onChanged,
    this.prefix,
  });
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final TextInputType?        keyboardType;
  final TextInputAction?      inputAction;
  final String? Function(String?)? validator;
  final void Function(String)?     onChanged;
  final String?               prefix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      textInputAction: inputAction,
      onChanged:       onChanged,
      validator:       validator,
      style:           _ts(14, color: _C.ink),
      decoration: InputDecoration(
        labelText:   label,
        labelStyle:  _ts(13, color: _C.inkMid),
        prefixIcon:  Icon(icon, size: 18, color: _C.inkMid),
        prefixText:  prefix != null ? '$prefix  ' : null,
        prefixStyle: _ts(13, weight: FontWeight.w600, color: _C.inkMid),
        filled:      true,
        fillColor:   _C.bg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: _C.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: _C.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: _C.danger, width: 1.5),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// REUSABLE DROPDOWN FIELD
// ════════════════════════════════════════════════════════════════════════════
class _DropField extends StatelessWidget {
  const _DropField({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });
  final String              label, value;
  final IconData            icon;
  final List<String>        items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue:       value,
      onChanged:   onChanged,
      style:       _ts(14, color: _C.ink),
      dropdownColor: _C.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: _C.inkMid),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: _ts(13, color: _C.inkMid),
        prefixIcon: Icon(icon, size: 18, color: _C.inkMid),
        filled:     true,
        fillColor:  _C.bg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: _C.primary, width: 1.5),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      items: items.map((i) => DropdownMenuItem(
        value: i,
        child: Text(
          i.replaceAll('_', ' '),
          style: _ts(13, weight: FontWeight.w500),
        ),
      )).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SALE ITEM DATA MODEL
// ════════════════════════════════════════════════════════════════════════════
class _SaleItemEntry {
  final productIdController = TextEditingController();
  final quantityController  = TextEditingController(text: '1');
  final priceController     = TextEditingController();

  String get productId => productIdController.text;

  void dispose() {
    productIdController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}