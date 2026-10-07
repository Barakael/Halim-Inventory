import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/products_api.dart';
import '../../../../core/api/purchases_api.dart';
import '../../../../core/api/suppliers_api.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/currency_formatter.dart';

class _DraftLine {
  _DraftLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
  });

  final int productId;
  final String productName;
  int quantity;
  double unitCost;

  double get lineTotal => quantity * unitCost;
}

class PurchaseEditorSheet extends StatefulWidget {
  const PurchaseEditorSheet({
    super.key,
    this.purchase,
    required this.suppliers,
  });

  final PurchaseModel? purchase;
  final List<SupplierModel> suppliers;

  @override
  State<PurchaseEditorSheet> createState() => _PurchaseEditorSheetState();
}

class _PurchaseEditorSheetState extends State<PurchaseEditorSheet> {
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int? _supplierId;
  DateTime _purchasedAt = DateTime.now();
  final List<_DraftLine> _lines = [];
  bool _saving = false;
  List<Map<String, dynamic>> _products = [];
  bool _loadingProducts = true;

  BrandPalette get _p => BrandTokens.current;
  bool get _isEdit => widget.purchase != null;

  double get _subtotal =>
      _lines.fold<double>(0, (sum, l) => sum + l.lineTotal);

  @override
  void initState() {
    super.initState();
    final p = widget.purchase;
    if (p != null) {
      _supplierId = p.supplierId;
      _referenceCtrl.text = p.reference ?? '';
      _notesCtrl.text = p.notes ?? '';
      _purchasedAt = p.purchasedAt ?? DateTime.now();
      for (final item in p.items) {
        _lines.add(_DraftLine(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitCost: item.unitCost,
        ));
      }
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await sl<ProductsApi>().getProducts();
      if (!mounted) return;
      setState(() {
        _products = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchasedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _purchasedAt = picked);
    }
  }

  Future<void> _addProductLine() async {
    if (_loadingProducts) return;
    final t = context.t;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final filtered = _products.where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              final barcode = (p['barcode'] ?? '').toString().toLowerCase();
              final q = query.toLowerCase();
              return q.isEmpty || name.contains(q) || barcode.contains(q);
            }).toList();
            return SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: t.pickProduct,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) => setModal(() => query = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        final name = p['name']?.toString() ?? '';
                        final stock = p['stock'];
                        final cost = p['cost_price'];
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(
                            [
                              if (stock != null) 'Stock: $stock',
                              if (cost != null)
                                '${t.lastCost}: ${CurrencyFormatter.format(cost)}',
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.pop(ctx, p),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected == null || !mounted) return;
    final id = (selected['id'] as num).toInt();
    if (_lines.any((l) => l.productId == id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(selected['name']?.toString() ?? '')),
      );
      return;
    }
    final cost = (selected['cost_price'] as num?)?.toDouble() ?? 0;
    setState(() {
      _lines.add(_DraftLine(
        productId: id,
        productName: selected['name']?.toString() ?? '',
        quantity: 1,
        unitCost: cost,
      ));
    });
  }

  Future<void> _editLine(_DraftLine line) async {
    final t = context.t;
    final qtyCtrl = TextEditingController(text: '${line.quantity}');
    final costCtrl = TextEditingController(
      text: line.unitCost == 0 ? '' : line.unitCost.toStringAsFixed(0),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(line.productName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: t.quantityShort),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t.unitCost),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    final cost = double.tryParse(costCtrl.text.replaceAll(',', '')) ?? 0;
    if (qty < 1) return;
    setState(() {
      line.quantity = qty;
      line.unitCost = cost;
    });
  }

  Map<String, dynamic> _payload({required bool receiveNow}) {
    return {
      'supplier_id': _supplierId,
      'reference':
          _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'purchased_at': DateFormat('yyyy-MM-dd').format(_purchasedAt),
      'receive_now': receiveNow,
      'items': _lines
          .map((l) => {
                'product_id': l.productId,
                'quantity': l.quantity,
                'unit_cost': l.unitCost,
              })
          .toList(),
    };
  }

  Future<void> _submit({required bool receiveNow}) async {
    final t = context.t;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.atLeastOneItem)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = sl<PurchasesApi>();
      if (_isEdit) {
        await api.update(widget.purchase!.id, _payload(receiveNow: false));
        if (receiveNow) {
          await api.receive(widget.purchase!.id);
          if (!mounted) return;
          Navigator.pop(context, 'received');
          return;
        }
        if (!mounted) return;
        Navigator.pop(context, 'saved');
      } else {
        final created = await api.create(_payload(receiveNow: receiveNow));
        if (!mounted) return;
        Navigator.pop(context, created.isReceived ? 'received' : 'saved');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? t.editPurchase : t.newPurchase,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _p.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  InputDecorator(
                    decoration: InputDecoration(labelText: t.selectSupplier),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _supplierId,
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(t.noSupplierOptional),
                          ),
                          ...widget.suppliers.map(
                            (s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text(s.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _referenceCtrl,
                    decoration:
                        InputDecoration(labelText: t.purchaseReference),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.purchaseDate),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(_purchasedAt)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: _pickDate,
                  ),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: t.purchaseNotes),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        t.addLineItem,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _p.ink,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addProductLine,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(t.addLineItem),
                      ),
                    ],
                  ),
                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        t.atLeastOneItem,
                        style: TextStyle(color: _p.inkMid),
                      ),
                    ),
                  ..._lines.map((line) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _p.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _p.border),
                      ),
                      child: ListTile(
                        title: Text(line.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${line.quantity} × ${CurrencyFormatter.format(line.unitCost)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CurrencyFormatter.format(line.lineTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _p.primary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editLine(line),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: _p.danger),
                              onPressed: () =>
                                  setState(() => _lines.remove(line)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(t.purchaseSubtotal,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: _p.ink)),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(_subtotal),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _p.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving
                            ? null
                            : () => _submit(receiveNow: true),
                        child: Text(t.saveAndReceive),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _submit(receiveNow: false),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(t.saveDraft),
                      ),
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
}
