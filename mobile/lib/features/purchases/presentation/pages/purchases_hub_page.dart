import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/purchases_api.dart';
import '../../../../core/api/suppliers_api.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../widgets/purchase_editor_sheet.dart';
import '../widgets/supplier_editor_sheet.dart';

class PurchasesHubPage extends StatefulWidget {
  const PurchasesHubPage({super.key});

  @override
  State<PurchasesHubPage> createState() => _PurchasesHubPageState();
}

class _PurchasesHubPageState extends State<PurchasesHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final PurchasesApi _purchasesApi;
  late final SuppliersApi _suppliersApi;

  List<PurchaseModel> _purchases = [];
  List<SupplierModel> _suppliers = [];
  bool _purchasesLoading = true;
  bool _suppliersLoading = true;
  String? _purchasesError;
  String? _suppliersError;

  String _purchaseSearch = '';
  String _statusFilter = 'all';
  String _supplierSearch = '';

  final _purchaseSearchCtrl = TextEditingController();
  final _supplierSearchCtrl = TextEditingController();

  BrandPalette get _p => BrandTokens.current;

  @override
  void initState() {
    super.initState();
    _purchasesApi = sl<PurchasesApi>();
    _suppliersApi = sl<SuppliersApi>();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPurchases();
      _loadSuppliers();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _purchaseSearchCtrl.dispose();
    _supplierSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPurchases() async {
    setState(() {
      _purchasesLoading = true;
      _purchasesError = null;
    });
    try {
      final list = await _purchasesApi.getAll();
      if (!mounted) return;
      setState(() {
        _purchases = list;
        _purchasesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchasesError = e.toString().replaceFirst('Exception: ', '');
        _purchasesLoading = false;
      });
    }
  }

  List<PurchaseModel> get _filteredPurchases {
    final q = _purchaseSearch.trim().toLowerCase();
    return _purchases.where((p) {
      final matchesStatus =
          _statusFilter == 'all' || p.status == _statusFilter;
      final matchesSearch = q.isEmpty ||
          (p.reference?.toLowerCase().contains(q) ?? false) ||
          (p.supplierName?.toLowerCase().contains(q) ?? false) ||
          (p.notes?.toLowerCase().contains(q) ?? false);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _suppliersLoading = true;
      _suppliersError = null;
    });
    try {
      final list = await _suppliersApi.getAll(
        search: _supplierSearch.isEmpty ? null : _supplierSearch,
      );
      if (!mounted) return;
      setState(() {
        _suppliers = list;
        _suppliersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _suppliersError = e.toString().replaceFirst('Exception: ', '');
        _suppliersLoading = false;
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _p.danger : _p.accent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  int get _draftCount =>
      _purchases.where((p) => p.isDraft).length;

  double get _receivedThisMonthSpend {
    final now = DateTime.now();
    return _purchases
        .where((p) =>
            p.isReceived &&
            p.receivedAt != null &&
            p.receivedAt!.year == now.year &&
            p.receivedAt!.month == now.month)
        .fold<double>(0, (sum, p) => sum + p.subtotal);
  }

  Future<void> _openNewPurchase({PurchaseModel? existing}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PurchaseEditorSheet(
        purchase: existing,
        suppliers: _suppliers,
      ),
    );
    if (!mounted) return;
    if (result == 'received') {
      _toast(context.t.purchaseReceived);
      await _loadPurchases();
    } else if (result == 'saved') {
      _toast(context.t.purchaseSaved);
      await _loadPurchases();
    }
  }

  Future<void> _openSupplierEditor({SupplierModel? supplier}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierEditorSheet(supplier: supplier),
    );
    if (!mounted) return;
    if (result == true) {
      _toast(context.t.supplierSaved);
      await _loadSuppliers();
    }
  }

  Future<void> _showPurchaseDetail(PurchaseModel purchase) async {
    final fresh = await _purchasesApi.getById(purchase.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseDetailSheet(
        purchase: fresh,
        onEdit: () {
          Navigator.pop(context);
          _openNewPurchase(existing: fresh);
        },
        onReceive: () async {
          Navigator.pop(context);
          final ok = await _confirmReceive();
          if (!ok || !mounted) return;
          try {
            await _purchasesApi.receive(fresh.id);
            _toast(context.t.purchaseReceived);
            await _loadPurchases();
          } catch (e) {
            _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
          }
        },
        onCancel: () async {
          Navigator.pop(context);
          final ok = await _confirmCancel();
          if (!ok || !mounted) return;
          try {
            await _purchasesApi.cancel(fresh.id);
            _toast(context.t.purchaseCancelled);
            await _loadPurchases();
          } catch (e) {
            _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
          }
        },
      ),
    );
  }

  Future<bool> _confirmReceive() async {
    final t = context.t;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.receiveConfirmTitle),
        content: Text(t.receiveConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.receiveGoods),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _confirmCancel() async {
    final t = context.t;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.cancelConfirmTitle),
        content: Text(t.cancelConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.close)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _p.danger),
            child: Text(t.cancelPurchase),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteSupplier(SupplierModel s) async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.deleteSupplierTitle),
        content: Text(t.deleteSupplierBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _p.danger),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _suppliersApi.delete(s.id);
      _toast(t.supplierDeleted);
      await _loadSuppliers();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final onPurchases = _tabs.index == 0;

    return AppPageScaffold(
      title: t.purchases,
      subtitle: t.purchasesSubtitle,
      actions: [
        IconButton(
          tooltip: t.refresh,
          onPressed: () {
            _loadPurchases();
            _loadSuppliers();
          },
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
        if (onPurchases)
          IconButton(
            tooltip: t.newPurchase,
            onPressed: () => _openNewPurchase(),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          )
        else
          IconButton(
            tooltip: t.addSupplier,
            onPressed: () => _openSupplierEditor(),
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: t.purchasesTab),
            Tab(text: t.suppliersTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildPurchasesTab(t),
          _buildSuppliersTab(t),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab(AppStrings t) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: t.draftsOpen,
                      value: '$_draftCount',
                      icon: Icons.edit_note_rounded,
                      color: _p.warn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: t.receivedThisMonth,
                      value: CurrencyFormatter.formatCompact(_receivedThisMonthSpend),
                      icon: Icons.inventory_rounded,
                      color: _p.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SearchField(
                controller: _purchaseSearchCtrl,
                hint: t.searchPurchasesHint,
                onChanged: (v) {
                  setState(() => _purchaseSearch = v);
                },
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusChip(
                      label: t.statusAll,
                      selected: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: t.statusDraft,
                      selected: _statusFilter == 'draft',
                      onTap: () => setState(() => _statusFilter = 'draft'),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: t.statusReceived,
                      selected: _statusFilter == 'received',
                      onTap: () => setState(() => _statusFilter = 'received'),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: t.statusCancelled,
                      selected: _statusFilter == 'cancelled',
                      onTap: () => setState(() => _statusFilter = 'cancelled'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildPurchasesList(t)),
      ],
    );
  }

  Widget _buildPurchasesList(AppStrings t) {
    if (_purchasesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_purchasesError != null) {
      return _ErrorState(message: _purchasesError!, onRetry: _loadPurchases);
    }
    final visible = _filteredPurchases;
    if (visible.isEmpty) {
      return _EmptyState(
        icon: Icons.local_shipping_outlined,
        title: t.noPurchasesYet,
        subtitle: t.addFirstPurchase,
        actionLabel: t.newPurchase,
        onAction: () => _openNewPurchase(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPurchases,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = visible[i];
          return _PurchaseCard(
            purchase: p,
            onTap: () => _showPurchaseDetail(p),
          );
        },
      ),
    );
  }

  Widget _buildSuppliersTab(AppStrings t) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _SearchField(
            controller: _supplierSearchCtrl,
            hint: t.searchSuppliersHint,
            onChanged: (v) {
              _supplierSearch = v;
              _loadSuppliers();
            },
          ),
        ),
        Expanded(child: _buildSuppliersList(t)),
      ],
    );
  }

  Widget _buildSuppliersList(AppStrings t) {
    if (_suppliersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_suppliersError != null) {
      return _ErrorState(message: _suppliersError!, onRetry: _loadSuppliers);
    }
    if (_suppliers.isEmpty) {
      return _EmptyState(
        icon: Icons.storefront_outlined,
        title: t.noSuppliersYet,
        subtitle: t.addFirstSupplier,
        actionLabel: t.addSupplier,
        onAction: () => _openSupplierEditor(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuppliers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _suppliers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final s = _suppliers[i];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openSupplierEditor(supplier: s),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _p.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _p.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_outlined,
                          color: _p.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _p.ink,
                            ),
                          ),
                          if ((s.phone ?? '').isNotEmpty)
                            Text(s.phone!,
                                style: TextStyle(fontSize: 12, color: _p.inkMid)),
                          if ((s.notes ?? '').isNotEmpty)
                            Text(
                              s.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: _p.inkMid),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t.delete,
                      onPressed: () => _deleteSupplier(s),
                      icon: Icon(Icons.delete_outline_rounded,
                          color: _p.danger, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
    final p = BrandTokens.current;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: p.inkMid)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: p.inkMid),
          prefixIcon: Icon(Icons.search_rounded, color: p.inkMid, size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? p.primary : p.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : p.inkMid,
          ),
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.purchase, required this.onTap});

  final PurchaseModel purchase;
  final VoidCallback onTap;

  Color _statusColor(BrandPalette p) {
    if (purchase.isDraft) return p.warn;
    if (purchase.isReceived) return p.accent;
    return p.inkMid;
  }

  String _statusLabel(AppStrings t) {
    if (purchase.isDraft) return t.statusDraft;
    if (purchase.isReceived) return t.statusReceived;
    return t.statusCancelled;
  }

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    final t = context.t;
    final date = purchase.purchasedAt ?? purchase.receivedAt;
    final dateStr = date == null
        ? '—'
        : DateFormat('dd MMM yyyy').format(date.toLocal());

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      purchase.supplierName?.isNotEmpty == true
                          ? purchase.supplierName!
                          : t.walkInSupplier,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: p.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(p).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(t),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(p),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(dateStr,
                      style: TextStyle(fontSize: 12, color: p.inkMid)),
                  if ((purchase.reference ?? '').isNotEmpty) ...[
                    Text(' · ', style: TextStyle(color: p.inkMid)),
                    Flexible(
                      child: Text(
                        purchase.reference!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.inkMid),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    t.itemsCount(purchase.items.length),
                    style: TextStyle(fontSize: 12, color: p.inkMid),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(purchase.subtotal),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: p.primary),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.inkMid)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.t.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseDetailSheet extends StatelessWidget {
  const _PurchaseDetailSheet({
    required this.purchase,
    required this.onEdit,
    required this.onReceive,
    required this.onCancel,
  });

  final PurchaseModel purchase;
  final VoidCallback onEdit;
  final VoidCallback onReceive;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    final t = context.t;
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.purchaseDetail,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _detailRow(t.selectSupplier,
                    purchase.supplierName ?? t.walkInSupplier, p),
                if ((purchase.reference ?? '').isNotEmpty)
                  _detailRow(t.purchaseReference, purchase.reference!, p),
                if (purchase.purchasedAt != null)
                  _detailRow(t.purchaseDate,
                      dateFmt.format(purchase.purchasedAt!.toLocal()), p),
                if (purchase.receivedAt != null)
                  _detailRow(t.receivedOn,
                      dateFmt.format(purchase.receivedAt!.toLocal()), p),
                if ((purchase.notes ?? '').isNotEmpty)
                  _detailRow(t.purchaseNotes, purchase.notes!, p),
                const SizedBox(height: 12),
                Text(t.lineItems,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: p.ink)),
                const SizedBox(height: 8),
                ...purchase.items.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: p.ink)),
                                Text(
                                  '${item.quantity} × ${CurrencyFormatter.format(item.unitCost)}',
                                  style: TextStyle(
                                      fontSize: 12, color: p.inkMid),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(item.lineTotal),
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: p.primary),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(t.purchaseSubtotal,
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: p.ink)),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(purchase.subtotal),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: p.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (purchase.isDraft)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onReceive,
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: Text(t.receiveGoods),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onEdit,
                            child: Text(t.edit),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.danger,
                            ),
                            child: Text(t.cancelPurchase),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, BrandPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: p.inkMid)),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
        ],
      ),
    );
  }
}
