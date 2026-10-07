import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/l10n/language_switcher.dart';
import '../../../../core/theme/brand_palette.dart';
import '../../../../core/theme/theme_switcher.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/app_page_scaffold.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../shops/domain/entities/shop_entity.dart';
import '../../../shops/domain/repositories/shop_repository.dart';

bool _isOwnerRole(String role) {
  final r = role.toLowerCase().trim();
  return r == 'owner' ||
      r == 'business owner' ||
      r == 'store owner' ||
      r == 'shop owner' ||
      r == 'school_manager' ||
      r == 'school manager' ||
      r.contains('owner');
}

bool _isPureOwner(String role) {
  final r = role.toLowerCase().trim();
  return r == 'owner' ||
      r == 'business owner' ||
      r == 'store owner' ||
      r == 'shop owner';
}

String _apiError(Object e) {
  return e
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('ServerException: ', '')
      .replaceFirst('NetworkException: ', '')
      .replaceFirst('UnauthorizedException: ', '')
      .replaceFirst(RegExp(r' \(status: \d+\)$'), '');
}

class _S {
  static BrandPalette get _p => BrandTokens.current;
  static Color get bg => _p.bg;
  static Color get white => _p.white;
  static Color get primary => _p.primary;
  static Color get primaryLt => _p.primaryLt;
  static Color get accent => _p.accent;
  static Color get accentSoft => _p.accentSoft;
  static Color get warn => _p.warn;
  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.dangerSoft;
  static Color get ink => _p.ink;
  static Color get inkMid => _p.inkMid;
  static Color get border => _p.border;

  static TextStyle ts(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      _p.ts(size, weight: weight, color: color, height: height);

  static List<BoxShadow> get cardShadow => _p.cardShadow;
}

class OwnerSettingsPage extends StatefulWidget {
  const OwnerSettingsPage({super.key});

  @override
  State<OwnerSettingsPage> createState() => _OwnerSettingsPageState();
}

class _OwnerSettingsPageState extends State<OwnerSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _branchesKey = GlobalKey<_BranchesTabState>();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    final ownerOnly =
        auth is AuthAuthenticated && _isPureOwner(auth.user.roleName);
    _tabs = TabController(length: ownerOnly ? 3 : 2, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _S.danger : _S.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return Scaffold(
        backgroundColor: _S.bg,
        body: Center(child: CircularProgressIndicator(color: _S.primary)),
      );
    }
    if (!_isOwnerRole(authState.user.roleName)) {
      return Scaffold(
        backgroundColor: _S.bg,
        appBar: AppBar(
          backgroundColor: _S.primary,
          foregroundColor: Colors.white,
          title: Text(t.settings),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              t.shopSettingsOwnerOnly,
              style: _S.ts(14, color: _S.inkMid),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final showSub = _isPureOwner(authState.user.roleName);
    final onBranches = _tabs.index == 1;

    return AppPageScaffold(
      title: t.settings,
      subtitle: t.shopSettings,
      actions: [
        if (onBranches)
          IconButton(
            tooltip: t.addBranch,
            onPressed: () => _branchesKey.currentState?.openEditor(),
            icon: const Icon(Icons.add_rounded),
          ),
      ],
      bottom: TabBar(
        controller: _tabs,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          Tab(text: t.shopTab),
          Tab(text: t.branchesLabel),
          if (showSub) Tab(text: t.planTab),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ShopInfoTab(onToast: _toast),
          _BranchesTab(key: _branchesKey, onToast: _toast),
          if (showSub) const _SubscriptionTab(),
        ],
      ),
    );
  }
}

class _ShopInfoTab extends StatefulWidget {
  final void Function(String message, {bool error}) onToast;
  const _ShopInfoTab({required this.onToast});

  @override
  State<_ShopInfoTab> createState() => _ShopInfoTabState();
}

class _ShopInfoTabState extends State<_ShopInfoTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _addressCtrl,
      _phoneCtrl,
      _emailCtrl,
      _currencyCtrl,
      _mobileCtrl,
      _locationCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(ShopEntity shop) {
    _nameCtrl.text = shop.name;
    _addressCtrl.text = shop.address;
    _phoneCtrl.text = shop.phone;
    _emailCtrl.text = shop.email;
    _currencyCtrl.text = shop.currency.isEmpty ? 'TZS' : shop.currency;
    _mobileCtrl.text = shop.mobile;
    _locationCtrl.text = shop.location;
    _dirty = false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var shop = await sl<ShopRepository>().getCurrentShop();
      if (!mounted) return;
      if (shop == null || (shop.id == 0 && shop.name.isEmpty)) {
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated) shop = auth.user.shop;
      }
      if (shop == null) {
        setState(() {
          _loading = false;
          _error = context.t.noShopProfile;
        });
        return;
      }
      _fill(shop);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated && auth.user.shop != null) {
        _fill(auth.user.shop!);
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = _apiError(e);
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final updated = await sl<ShopRepository>().updateCurrentShop(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        currency: _currencyCtrl.text.trim().isEmpty
            ? 'TZS'
            : _currencyCtrl.text.trim(),
      );
      if (!mounted) return;
      _fill(updated);
      setState(() {});
      widget.onToast(context.t.shopSaved);
    } catch (e) {
      if (!mounted) return;
      widget.onToast(_apiError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: _S.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: _S.ts(13, color: _S.inkMid),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: _S.primary),
                child: Text(t.retry),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _S.primary,
      onRefresh: _load,
      child: Form(
        key: _formKey,
        onChanged: _markDirty,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          children: [
            _card(
              title: t.appearance,
              child: const Column(
                children: [
                  LanguageSwitcherTile(dense: true),
                  Divider(height: 1),
                  ThemeSwitcherTile(dense: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              title: t.shopInfo,
              child: Column(
                children: [
                  _field(t.shopNameLabel, _nameCtrl, required: true),
                  _field(t.phone, _phoneCtrl, keyboard: TextInputType.phone),
                  _field(t.email, _emailCtrl,
                      keyboard: TextInputType.emailAddress),
                  _field(t.address, _addressCtrl),
                  _field(t.currencyLabel, _currencyCtrl, last: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_saving || !_dirty) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? t.savingEllipsis : t.saveChanges),
                style: FilledButton.styleFrom(
                  backgroundColor: _S.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _S.primary.withValues(alpha: 0.4),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: Icon(Icons.logout_rounded, size: 17, color: _S.danger),
                label: Text(t.logout,
                    style: _S.ts(14, weight: FontWeight.w600, color: _S.danger)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _S.danger.withValues(alpha: 0.35)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    final t = context.t;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.logout, style: _S.ts(17, weight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(t.signOutConfirm, style: _S.ts(13, color: _S.inkMid)),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _S.danger,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
                child: Text(t.logout),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: _S.border),
                ),
                child: Text(t.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: _S.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _S.border),
        boxShadow: _S.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _S.ts(14, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    bool required = false,
    bool last = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 10 : 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        style: _S.ts(14, color: _S.ink),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? context.t.requiredField : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: _S.ts(13, color: _S.inkMid),
          filled: true,
          fillColor: _S.bg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _S.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _S.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _S.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _Branch {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final int cashierCount;

  _Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.cashierCount = 0,
  });

  factory _Branch.fromJson(Map<String, dynamic> j) => _Branch(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        address: j['address']?.toString(),
        phone: j['phone']?.toString(),
        cashierCount: (j['cashier_count'] as num?)?.toInt() ?? 0,
      );
}

class _BranchEditorSheet extends StatefulWidget {
  const _BranchEditorSheet({this.branch});

  final _Branch? branch;

  static Future<bool?> show(BuildContext context, {_Branch? branch}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchEditorSheet(branch: branch),
    );
  }

  @override
  State<_BranchEditorSheet> createState() => _BranchEditorSheetState();
}

class _BranchEditorSheetState extends State<_BranchEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;

  bool get _isEditing => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _addressCtrl = TextEditingController(text: b?.address ?? '');
    _phoneCtrl = TextEditingController(text: b?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (_isEditing) {
        await sl<ApiClient>().put(
          endpoint: ApiEndpoints.branchById('${widget.branch!.id}'),
          data: body,
          parser: (j) => j,
        );
      } else {
        await sl<ApiClient>().post(
          endpoint: ApiEndpoints.branches,
          data: body,
          parser: (j) => j,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_apiError(e)),
          backgroundColor: _S.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: _S.ts(13, color: _S.inkMid),
        filled: true,
        fillColor: _S.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _S.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _S.primary, width: 1.6),
        ),
      );

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _S.ts(13, weight: FontWeight.w600, color: _S.primary)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: _S.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_S.primary, _S.primaryLt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _isEditing
                              ? Icons.edit_rounded
                              : Icons.add_business_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? t.editBranch : t.addBranch,
                              style: _S.ts(16,
                                  weight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(t.branchFormHint,
                                style: _S.ts(11, color: Colors.white70)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _labeled(
                        t.branchNameLabel,
                        TextFormField(
                          controller: _nameCtrl,
                          style: _S.ts(14, weight: FontWeight.w500),
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? t.requiredField
                              : null,
                          decoration: _deco(t.branchNameLabel,
                              hint: 'Main Branch'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _labeled(
                        t.address,
                        TextFormField(
                          controller: _addressCtrl,
                          style: _S.ts(14, weight: FontWeight.w500),
                          textInputAction: TextInputAction.next,
                          decoration:
                              _deco(t.address, hint: 'Street, City'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _labeled(
                        t.phone,
                        TextFormField(
                          controller: _phoneCtrl,
                          style: _S.ts(14, weight: FontWeight.w500),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration:
                              _deco(t.phone, hint: '+255 7XX XXX XXX'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: Icon(
                          _isEditing
                              ? Icons.save_rounded
                              : Icons.add_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _saving
                              ? t.savingEllipsis
                              : _isEditing
                                  ? t.updateBranch
                                  : t.addBranch,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _S.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _S.inkMid,
                          side: BorderSide(color: _S.border),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(t.cancel),
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

class _BranchesTab extends StatefulWidget {
  final void Function(String message, {bool error}) onToast;
  const _BranchesTab({super.key, required this.onToast});

  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab> {
  bool _loading = true;
  String? _error;
  List<_Branch> _branches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await sl<ApiClient>().get<dynamic>(
        endpoint: ApiEndpoints.branches,
        parser: (json) => json,
      );
      List list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else {
        list = const [];
      }
      final branches = list
          .whereType<Map>()
          .map((e) => _Branch.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _apiError(e);
      });
    }
  }

  Future<void> openEditor({_Branch? branch}) async {
    final saved = await _BranchEditorSheet.show(context, branch: branch);
    if (!mounted || saved != true) return;
    widget.onToast(
      branch == null ? context.t.branchAdded : context.t.branchUpdated,
    );
    await _load();
  }

  Future<void> _delete(_Branch b) async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.deleteBranch, style: _S.ts(17, weight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(t.deleteBranchConfirm(b.name),
                  style: _S.ts(13, color: _S.inkMid, height: 1.45)),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _S.danger,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.delete),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: _S.border),
                ),
                child: Text(t.cancel),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await sl<ApiClient>().delete(
        endpoint: ApiEndpoints.branchById('${b.id}'),
      );
      if (!mounted) return;
      widget.onToast(context.t.branchDeleted);
      await _load();
    } catch (e) {
      if (!mounted) return;
      widget.onToast(_apiError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: _S.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: _S.ts(13, color: _S.inkMid),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: _S.primary),
                child: Text(t.retry),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _S.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: [
          Text(
            t.branchCountLabel(_branches.length),
            style: _S.ts(13, color: _S.inkMid, weight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (_branches.isEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              decoration: BoxDecoration(
                color: _S.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _S.border),
                boxShadow: _S.cardShadow,
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _S.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.storefront_outlined,
                        color: _S.primary, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(t.noBranchesYet,
                      style: _S.ts(16, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(t.noBranchesHint,
                      style: _S.ts(13, color: _S.inkMid, height: 1.4),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => openEditor(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(t.addBranch),
                    style: FilledButton.styleFrom(
                      backgroundColor: _S.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._branches.map((b) {
              final details = [
                if ((b.address ?? '').isNotEmpty) b.address,
                if ((b.phone ?? '').isNotEmpty) b.phone,
              ].whereType<String>().join(' · ');
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                decoration: BoxDecoration(
                  color: _S.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _S.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _S.accentSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.storefront_rounded,
                          color: _S.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name,
                              style: _S.ts(14, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            details.isEmpty
                                ? t.cashiersAtBranch(b.cashierCount)
                                : '$details · ${t.cashiersAtBranch(b.cashierCount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _S.ts(12, color: _S.inkMid),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          color: _S.inkMid, size: 20),
                      onSelected: (v) {
                        if (v == 'edit') openEditor(branch: b);
                        if (v == 'delete') _delete(b);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(t.edit)),
                        PopupMenuItem(value: 'delete', child: Text(t.delete)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SubscriptionTab extends StatefulWidget {
  const _SubscriptionTab();

  @override
  State<_SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<_SubscriptionTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _sub;
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subRaw = await sl<ApiClient>().get<dynamic>(
        endpoint: ApiEndpoints.subscriptions,
        parser: (json) => json,
      );
      Map<String, dynamic>? sub;
      if (subRaw is Map && subRaw['id'] != null) {
        sub = Map<String, dynamic>.from(subRaw);
      } else if (subRaw is List && subRaw.isNotEmpty && subRaw.first is Map) {
        sub = Map<String, dynamic>.from(subRaw.first as Map);
      }

      final payRaw = await sl<ApiClient>().get<dynamic>(
        endpoint: ApiEndpoints.subscriptionPayments,
        parser: (json) => json,
      );
      List payList;
      if (payRaw is List) {
        payList = payRaw;
      } else if (payRaw is Map && payRaw['data'] is List) {
        payList = payRaw['data'] as List;
      } else {
        payList = const [];
      }

      if (!mounted) return;
      setState(() {
        _sub = sub;
        _payments = payList
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _apiError(e);
      });
    }
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return '—';
    return DateFormat('dd MMM yyyy').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: _S.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: _S.ts(13, color: _S.inkMid)),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: _S.primary),
              child: Text(t.retry),
            ),
          ],
        ),
      );
    }

    final sub = _sub;
    final price = (sub?['plan_price'] as num?)?.toDouble() ?? 0;
    final status = sub?['status']?.toString() ?? '';
    final days = (sub?['days_until_due'] as num?)?.toInt();

    return RefreshIndicator(
      color: _S.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        children: [
          if (sub == null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _S.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _S.border),
              ),
              child: Text(
                t.noActiveSubscription,
                style: _S.ts(13, color: _S.inkMid),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_S.primary, _S.primaryLt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.currentPlan,
                      style: _S.ts(12, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(sub['plan_name']?.toString() ?? 'Plan',
                      style: _S.ts(22, weight: FontWeight.w800, color: Colors.white)),
                  Text(
                    '\$${price.toStringAsFixed(2)} / month',
                    style: _S.ts(13, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.isEmpty ? 'unknown' : status,
                      style: _S.ts(11, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _S.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _S.border),
                boxShadow: _S.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.nextPaymentDue, style: _S.ts(12, color: _S.inkMid)),
                  const SizedBox(height: 4),
                  Text(_fmtDate(sub['next_due_at']),
                      style: _S.ts(16, weight: FontWeight.w800)),
                  if (days != null)
                    Text(
                      days < 0
                          ? '${days.abs()} days overdue'
                          : days == 0
                              ? 'Due today'
                              : '$days days left',
                      style: _S.ts(12,
                          color: days < 0
                              ? _S.danger
                              : days <= 7
                                  ? _S.warn
                                  : _S.inkMid),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(t.paymentHistory, style: _S.ts(14, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _S.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _S.border),
              ),
              child: Text(t.noPaymentHistory,
                  style: _S.ts(13, color: _S.inkMid),
                  textAlign: TextAlign.center),
            )
          else
            ..._payments.map((p) {
              final st = p['status']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _S.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _S.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['plan_name']?.toString() ?? 'Plan',
                              style: _S.ts(13, weight: FontWeight.w700)),
                          Text(
                            'Due ${_fmtDate(p['due_date'])}'
                            '${p['paid_at'] != null ? ' · Paid ${_fmtDate(p['paid_at'])}' : ''}',
                            style: _S.ts(11, color: _S.inkMid),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${((p['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                          style: _S.ts(13, weight: FontWeight.w800),
                        ),
                        Text(st,
                            style: _S.ts(11,
                                weight: FontWeight.w600,
                                color: st == 'paid'
                                    ? _S.accent
                                    : st == 'pending'
                                        ? _S.warn
                                        : _S.danger)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
