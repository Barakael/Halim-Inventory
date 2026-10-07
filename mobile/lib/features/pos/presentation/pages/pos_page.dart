import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/brand_palette.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/services/pos_device_service.dart';
import '../../../../core/services/pos_scanner_service.dart';
import '../../../../core/services/shop_profile_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../products/presentation/bloc/products_bloc.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';
import '../../../sales/presentation/bloc/sales_event.dart';
import '../../../sales/presentation/bloc/sales_state.dart';

import '../../../shops/domain/entities/shop_entity.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/hardware_barcode_listener.dart';
import '../widgets/payment_method_dialog.dart';
import '../widgets/receipt_dialog.dart';
import '../../domain/models/cart_item.dart';
import '../../../../shared/widgets/product_photo.dart';

// ════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ════════════════════════════════════════════════════════════════════════════
class _T {
  static BrandPalette get _p => BrandTokens.current;
  static Color get bg => _p.bg;
  static Color get white => _p.white;
  static Color get primary => _p.primary;
  static Color get primaryLt => _p.primaryLt;
  static Color get accent => _p.accent;
  static Color get accentSoft => _p.accentSoft;
  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.dangerSoft;
  static Color get warn => _p.warn;
  static Color get warnSoft => _p.warn.withValues(alpha: 0.1);
  static Color get ink => _p.ink;
  static Color get inkMid => _p.inkMid;
  /// Readable secondary text. Never the hairline border colour.
  static Color get inkLight => Color.lerp(_p.ink, _p.inkMid, 0.45)!;
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
  static List<BoxShadow> get floatShadow => _p.floatShadow;
  static Color primaryOpacity(double o) => _p.primaryOpacity(o);
}

/// POS-friendly quantity editor (numpad — avoids soft-keyboard / barcode conflicts).
Future<int?> showQuantityDialog(
  BuildContext context, {
  required String productName,
  required int maxStock,
  int initial = 1,
  String? title,
}) {
  final t = AppStrings.read(context);
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuantityPadSheet(
      productName: productName,
      maxStock: maxStock,
      initial: initial,
      title: title ?? t.enterQuantity,
    ),
  );
}

class _QuantityPadSheet extends StatefulWidget {
  const _QuantityPadSheet({
    required this.productName,
    required this.maxStock,
    required this.initial,
    required this.title,
  });

  final String productName;
  final int maxStock;
  final int initial;
  final String title;

  @override
  State<_QuantityPadSheet> createState() => _QuantityPadSheetState();
}

class _QuantityPadSheetState extends State<_QuantityPadSheet> {
  late String _digits;

  @override
  void initState() {
    super.initState();
    _digits = widget.initial > 0 ? '${widget.initial}' : '';
  }

  int get _value => int.tryParse(_digits) ?? 0;

  void _tap(String d) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_digits == '0') {
        _digits = d;
      } else if (_digits.length < 6) {
        _digits = '$_digits$d';
      }
    });
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_digits.isEmpty) return;
      _digits = _digits.substring(0, _digits.length - 1);
    });
  }

  void _clear() {
    HapticFeedback.selectionClick();
    setState(() => _digits = '');
  }

  void _confirm() {
    final t = AppStrings.read(context);
    final n = _value;
    if (n <= 0) return;
    if (n > widget.maxStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.insufficientStock} (max ${widget.maxStock})'),
          backgroundColor: _T.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final over = _value > widget.maxStock;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: _T.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottom > 0 ? bottom : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _T.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: _T.ts(16,
                                weight: FontWeight.w800, color: _T.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _T.ts(13, color: _T.inkMid),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: _T.inkMid, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _T.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: over ? _T.danger : _T.border,
                      width: over ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _digits.isEmpty ? '0' : _digits,
                          style: _T.ts(32,
                              weight: FontWeight.w900,
                              color: over ? _T.danger : _T.primary),
                        ),
                      ),
                      Text(
                        '${t.stockQuantity}: ${widget.maxStock}',
                        style: _T.ts(12, color: _T.inkMid),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _padRow(['1', '2', '3']),
                const SizedBox(height: 8),
                _padRow(['4', '5', '6']),
                const SizedBox(height: 8),
                _padRow(['7', '8', '9']),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _padKey('C', onTap: _clear, muted: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _padKey('0', onTap: () => _tap('0'))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _padKey(
                        '',
                        icon: Icons.backspace_outlined,
                        onTap: _backspace,
                        muted: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: _T.inkMid,
                          side: BorderSide(color: _T.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(t.cancel,
                            style: _T.ts(14,
                                weight: FontWeight.w600, color: _T.inkMid)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _value > 0 ? _confirm : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: _T.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _T.primary.withValues(alpha: 0.35),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(t.save,
                            style: _T.ts(15,
                                weight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _padRow(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _padKey(keys[i], onTap: () => _tap(keys[i]))),
        ],
      ],
    );
  }

  Widget _padKey(
    String label, {
    required VoidCallback onTap,
    IconData? icon,
    bool muted = false,
  }) {
    return Material(
      color: muted ? _T.bg : _T.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _T.border),
          ),
          child: icon != null
              ? Icon(icon, size: 22, color: _T.inkMid)
              : Text(
                  label,
                  style: _T.ts(20,
                      weight: FontWeight.w700,
                      color: muted ? _T.inkMid : _T.ink),
                ),
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
// MAIN POS PAGE
// ════════════════════════════════════════════════════════════════════════════
class POSPage extends StatefulWidget {
  const POSPage({super.key});

  @override
  State<POSPage> createState() => _POSPageState();
}

class _POSPageState extends State<POSPage> with TickerProviderStateMixin {
  final List<CartItem> _cart = [];
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showScanner = false;
  bool _processingPayment = false;
  late final bool _isH10Device;
  bool get _hardwareScanEnabled => _isH10Device || Platform.isAndroid;

  late final AnimationController _cartBadgeCtrl;
  late final Animation<double> _cartBadgeAnim;
  StreamSubscription<String>? _scannerSub;

  @override
  void initState() {
    super.initState();
    _isH10Device = PosDeviceService.instance.isH10Series;
    context.read<ProductsBloc>().add(const ProductsFetchRequested());
    _prefetchShopProfile();

    if (Platform.isAndroid) {
      _scannerSub = PosScannerService.instance.listen(_handleBarcodeScan);
    }

    _cartBadgeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cartBadgeAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _cartBadgeCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _scannerSub?.cancel();
    _searchCtrl.dispose();
    _cartBadgeCtrl.dispose();
    super.dispose();
  }

  /// Sum of line totals (selling prices).
  double get _subtotal =>
      _cart.fold(0.0, (s, i) => s + i.product.price * i.quantity);
  double get _total => _subtotal;
  int get _itemCount => _cart.fold(0, (s, i) => s + i.quantity);

  void _prefetchShopProfile() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      sl<ShopProfileService>().resolveShop(fromAuth: auth.user.shop);
    }
  }

  ProductEntity? _findByBarcode(String code, List<ProductEntity> products) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final p in products) {
      final bc = p.barcode?.trim().toLowerCase();
      if (bc != null && bc.isNotEmpty && bc == normalized) return p;
    }
    return null;
  }

  void _handleBarcodeScan(String barcode) {
    final code = barcode.trim();
    if (code.isEmpty) return;
    final s = context.read<ProductsBloc>().state;
    if (s is ProductsLoaded) {
      final match = _findByBarcode(code, s.products);
      if (match != null) {
        _addToCart(match);
        _searchCtrl.clear();
        setState(() => _searchQuery = '');
      } else {
        _toast('${AppStrings.read(context).barcodeNotFound}: $code',
            isError: true);
      }
    } else {
      _toast(AppStrings.read(context).productsStillLoading, isError: true);
    }
  }

  void _addToCart(ProductEntity product) {
    HapticFeedback.lightImpact();
    // Defer setState to next frame to avoid gesture event conflicts
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        final idx = _cart.indexWhere((i) => i.product.id == product.id);
        if (idx != -1) {
          if (_cart[idx].quantity < product.stock) {
            _cart[idx] =
                CartItem(product: product, quantity: _cart[idx].quantity + 1);
            _cartBadgeCtrl.forward(from: 0);
          } else {
            _toast(
                '${AppStrings.read(context).maxStockReached} ${product.name}',
                isError: true);
          }
        } else {
          if (product.stock > 0) {
            _cart.add(CartItem(product: product, quantity: 1));
            _cartBadgeCtrl.forward(from: 0);
          } else {
            _toast(
                '${product.name} — ${AppStrings.read(context).outOfStockLower}',
                isError: true);
          }
        }
      });
    });
  }

  Future<void> _promptQuantity(ProductEntity product, {int? currentQty}) async {
    if (product.stock <= 0) {
      _toast(
          '${product.name} — ${AppStrings.read(context).outOfStockLower}',
          isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    final qty = await showQuantityDialog(
      context,
      productName: product.name,
      maxStock: product.stock,
      initial: currentQty ?? 1,
      title: currentQty != null
          ? AppStrings.read(context).setQuantity
          : AppStrings.read(context).addQuantity,
    );
    if (!mounted || qty == null) return;
    _setCartQty(product, qty);
  }

  void _setCartQty(ProductEntity product, int qty) {
    setState(() {
      final idx = _cart.indexWhere((i) => i.product.id == product.id);
      if (qty <= 0) {
        if (idx != -1) _cart.removeAt(idx);
        return;
      }
      if (qty > product.stock) {
        _toast(AppStrings.read(context).insufficientStock, isError: true);
        return;
      }
      if (idx == -1) {
        _cart.add(CartItem(product: product, quantity: qty));
      } else {
        _cart[idx] = CartItem(product: product, quantity: qty);
      }
      _cartBadgeCtrl.forward(from: 0);
    });
  }

  void _updateQty(String id, int qty) {
    setState(() {
      final idx = _cart.indexWhere((i) => i.product.id == id);
      if (idx == -1) return;
      if (qty <= 0) {
        _cart.removeAt(idx);
      } else if (qty <= _cart[idx].product.stock) {
        _cart[idx] = CartItem(product: _cart[idx].product, quantity: qty);
      } else {
        _toast(AppStrings.read(context).insufficientStock, isError: true);
      }
    });
  }

  void _removeFromCart(String id) =>
      setState(() => _cart.removeWhere((i) => i.product.id == id));

  void _clearCart() => setState(() => _cart.clear());

  Future<void> _showPaymentDialog() async {
    if (_cart.isEmpty) {
      _toast(AppStrings.read(context).addItemsFirst, isError: true);
      return;
    }

    // Pause hardware scanner while checkout fields need the keyboard.
    final payment = await PaymentMethodDialog.show(context, total: _total);
    if (!mounted || payment == null) return;

    _processSale(payment);
  }

  void _processSale(PaymentSelection payment) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      _toast(AppStrings.read(context).authErrorLogin, isError: true);
      return;
    }
    if (_processingPayment) return;

    setState(() => _processingPayment = true);

    context.read<SalesBloc>().add(SaleCreateRequested({
      'items': _cart
          .map((i) => {
                'product_id': i.product.id,
                'quantity': i.quantity,
                'price': i.product.price,
              })
          .toList(),
      'subtotal': _subtotal,
      'tax': 0,
      'discount': payment.discountAmount,
      'total': payment.payableTotal ?? _total,
      'payment_method': payment.method,
      'amount_tendered': payment.amountTendered,
      'cashier_id': authState.user.id,
      if (payment.shopCustomerId != null)
        'shop_customer_id': int.tryParse(payment.shopCustomerId!) ??
            payment.shopCustomerId,
      'customer_name': payment.customerName ?? '',
      'customer_phone': payment.customerPhone ?? '',
      'customer_address': '',
      'customer_id_type': '',
      'customer_id': '',
      'discount_mode': payment.discountMode,
      'manual_discount_percent': payment.discountMode == 'percent'
          ? payment.discountPercent
          : null,
      'manual_discount_amount': payment.discountMode == 'amount'
          ? payment.discountAmount
          : null,
      'apply_loyalty_discount':
          payment.discountMode == 'loyalty' && payment.discountPercent > 0,
    }));
  }

  Future<void> _handleSaleCreated(BuildContext ctx, SaleCreated state) async {
    setState(() => _processingPayment = false);

    ShopEntity? shop;
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      shop = await sl<ShopProfileService>().resolveShop(
        fromSale: state.sale.shop,
        fromAuth: auth.user.shop,
      );
    } else {
      shop = state.sale.shop;
    }

    if (!ctx.mounted) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => ReceiptDialog(
        sale: state.sale,
        shop: shop,
        onClose: () {
          context.pop();
          _clearCart();
        },
      ),
    );
  }

  void _openCart() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        cart: List.unmodifiable(_cart),
        subtotal: _subtotal,
        tax: 0,
        total: _total,
        onUpdateQty: _updateQty,
        onRemove: _removeFromCart,
        onClear: _clearCart,
        onCheckout: _showPaymentDialog,
      ),
    );
  }

  void _openAddPopup() {
    final state = context.read<ProductsBloc>().state;
    if (state is! ProductsLoaded) {
      _toast(AppStrings.read(context).productsStillLoading, isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _AddProductDialog(
        products: state.products,
        cartIds: _cart.map((i) => i.product.id).toSet(),
        onAdd: _addToCart,
      ),
    );
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        backgroundColor: isError ? _T.danger : _T.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(msg,
                style:
                    _T.ts(13, weight: FontWeight.w500, color: Colors.white)),
          ),
        ]),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SalesBloc, SalesState>(
      listener: (ctx, state) {
        if (state is SaleCreated) {
          _handleSaleCreated(ctx, state);
        } else if (state is SalesError) {
          setState(() => _processingPayment = false);
          _toast(state.message, isError: true);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _T.bg,
          body: SafeArea(
            child: HardwareBarcodeListener(
              enabled: _hardwareScanEnabled,
              onBarcode: _handleBarcodeScan,
              child: Stack(
                children: [
                  Column(
                    children: [
                      _TopBar(
                        itemCount: _itemCount,
                        isH10Device: _isH10Device,
                        onHistoryTap: () => context.push(RouteNames.sales),
                        onScanTap: () => setState(() => _showScanner = true),
                        onAddTap: _openAddPopup,
                      ),
                      _SearchRow(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                        hardwareScanEnabled: _hardwareScanEnabled,
                        onBarcodeScan: _handleBarcodeScan,
                      ),
                      Expanded(
                        child: _ProductsBody(
                          searchQuery: _searchQuery,
                          onAddToCart: _addToCart,
                          onSetQuantity: _promptQuantity,
                          cart: _cart,
                        ),
                      ),
                    ],
                  ),
                  if (_showScanner)
                    BarcodeScannerWidget(
                      onBarcodeDetected: (barcode) {
                        setState(() => _showScanner = false);
                        _handleBarcodeScan(barcode);
                      },
                      onClose: () => setState(() => _showScanner = false),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _CartFAB(
            itemCount: _itemCount,
            total: _total,
            badgeAnim: _cartBadgeAnim,
            onTap: _openCart,
            isLoading: _processingPayment,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.itemCount,
    required this.isH10Device,
    required this.onHistoryTap,
    required this.onScanTap,
    required this.onAddTap,
  });

  final int itemCount;
  final bool isH10Device;
  final VoidCallback onHistoryTap, onScanTap, onAddTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: _T.primary,
        boxShadow: [
          BoxShadow(
            color: _T.primaryOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _T.accent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.point_of_sale_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.pointOfSale,
                  style: _T.ts(16,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  isH10Device ? t.h10ScannerActive : t.tapProductToCart,
                  style: _T.ts(12, color: Colors.white.withValues(alpha: 0.92)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TopAction(
            icon: Icons.history_rounded,
            tooltip: t.salesHistory,
            onTap: onHistoryTap,
          ),
          const SizedBox(width: 6),
          _TopAction(
            icon: isH10Device
                ? Icons.barcode_reader
                : Icons.qr_code_scanner_rounded,
            tooltip: isH10Device ? t.hardwareScanner : t.scanBarcode,
            onTap: onScanTap,
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: t.add,
            child: GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _T.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopAction extends StatelessWidget {    
  const _TopAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SEARCH ROW
// ════════════════════════════════════════════════════════════════════════════
class _SearchRow extends StatefulWidget {
  const _SearchRow({
    required this.controller,
    required this.onChanged,
    this.hardwareScanEnabled = false,
    this.onBarcodeScan,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool hardwareScanEnabled;
  final ValueChanged<String>? onBarcodeScan;

  @override
  State<_SearchRow> createState() => _SearchRowState();
}

class _SearchRowState extends State<_SearchRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _T.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        onSubmitted: widget.hardwareScanEnabled
            ? (value) {
                final code = value.trim();
                if (code.length >= 4) {
                  widget.onBarcodeScan?.call(code);
                  widget.controller.clear();
                  widget.onChanged('');
                }
              }
            : null,
        style: _T.ts(15, weight: FontWeight.w600, color: _T.ink),
        decoration: InputDecoration(
          hintText: context.t.searchProductsHint,
          hintStyle: _T.ts(14, weight: FontWeight.w500, color: _T.inkLight),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.search_rounded,
                color: _T.ink, size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: widget.controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF475569),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 14),
                  ),
                )
              : null,
          filled: true,
          fillColor: _T.bg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _T.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: _T.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRODUCTS BODY
// ════════════════════════════════════════════════════════════════════════════
class _ProductsBody extends StatelessWidget {
  const _ProductsBody({
    required this.searchQuery,
    required this.onAddToCart,
    required this.onSetQuantity,
    required this.cart,
  });

  final String searchQuery;
  final void Function(ProductEntity) onAddToCart;
  final Future<void> Function(ProductEntity product, {int? currentQty})
      onSetQuantity;
  final List<CartItem> cart;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        if (state is ProductsLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                    color: _T.primary, strokeWidth: 2),
                const SizedBox(height: 14),
                Text(t.loadingProducts,
                    style: _T.ts(13, color: _T.inkMid)),
              ],
            ),
          );
        }

        if (state is ProductsError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: _T.dangerSoft, shape: BoxShape.circle),
                    child: Icon(Icons.wifi_off_rounded,
                        color: _T.danger, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(t.failedLoadProducts,
                      style: _T.ts(15,
                          weight: FontWeight.w700, color: _T.ink)),
                  const SizedBox(height: 6),
                  Text(t.checkConnection,
                      style: _T.ts(13, color: _T.inkMid),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => context
                        .read<ProductsBloc>()
                        .add(const ProductsFetchRequested()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 11),
                      decoration: BoxDecoration(
                        color: _T.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(t.retry,
                          style: _T.ts(13,
                              weight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is ProductsLoaded) {
          final products = state.products.where((p) {
            if (searchQuery.isEmpty) return true;
            return p.name.toLowerCase().contains(searchQuery) ||
                (p.barcode?.toLowerCase().contains(searchQuery) ?? false);
          }).toList();

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      color: _T.inkLight, size: 52),
                  const SizedBox(height: 10),
                  Text(t.noProductsFound,
                      style: _T.ts(15,
                          weight: FontWeight.w600, color: _T.inkMid)),
                  const SizedBox(height: 4),
                  Text(t.tryDifferentName,
                      style: _T.ts(12, color: _T.inkLight)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded,
                        size: 15, color: _T.inkLight),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.qtyTapHint,
                        style: _T.ts(12,
                            weight: FontWeight.w500, color: _T.inkLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 110),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final p = products[i];
                    final cartQty = cart
                            .where((c) => c.product.id == p.id)
                            .firstOrNull
                            ?.quantity ??
                        0;
                    return _ProductListItem(
                      product: p,
                      cartQty: cartQty,
                      onTap: p.stock == 0 ? null : () => onAddToCart(p),
                      onLongPress: p.stock == 0
                          ? null
                          : () => onSetQuantity(p,
                              currentQty: cartQty > 0 ? cartQty : null),
                      onEditQty: cartQty > 0
                          ? () => onSetQuantity(p, currentQty: cartQty)
                          : null,
                      isLast: i == products.length - 1,
                    );
                  },
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRODUCT LIST ITEM
// ════════════════════════════════════════════════════════════════════════════
class _ProductListItem extends StatelessWidget {
  const _ProductListItem({
    required this.product,
    required this.cartQty,
    required this.onTap,
    this.onLongPress,
    this.onEditQty,
    required this.isLast,
  });

  final ProductEntity product;
  final int cartQty;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEditQty;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stock == 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: outOfStock ? _T.bg : _T.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: cartQty > 0 ? _T.accent : _T.border,
            width: cartQty > 0 ? 1.5 : 1,
          ),
          boxShadow: outOfStock ? null : _T.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ProductPhoto(
                url: product.image,
                size: 52,
                radius: 12,
                iconSize: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: _T.ts(14,
                          weight: FontWeight.w600,
                          color: outOfStock ? _T.inkMid : _T.ink,
                          height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.price),
                          style: _T.ts(14,
                              weight: FontWeight.w800,
                              color: outOfStock
                                  ? _T.inkMid
                                  : _T.primary),
                        ),
                        _StockBadge(stock: product.stock),
                      ],
                    ),
                    if (product.barcode != null &&
                        product.barcode!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _T.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _T.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_rounded,
                                size: 14, color: _T.ink),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                product.barcode!.trim(),
                                style: _T.ts(13,
                                    weight: FontWeight.w700,
                                    color: _T.ink,
                                    letterSpacing: 0.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (cartQty > 0) ...[
                    GestureDetector(
                      onTap: onEditQty,
                      child: Tooltip(
                        message: context.t.setQuantity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: _T.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_rounded,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('$cartQty',
                                  style: _T.ts(11,
                                      weight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (outOfStock)
                    Tooltip(
                      message: context.t.outOfStock,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _T.dangerSoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.block_rounded,
                            color: _T.danger, size: 18),
                      ),
                    )
                  else
                    Tooltip(
                      message: context.t.add,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cartQty > 0
                              ? _T.accentSoft
                              : _T.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.add_rounded,
                            color: cartQty > 0
                                ? _T.accent
                                : Colors.white,
                            size: 20),
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

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final low = stock > 0 && stock <= 5;
    final out = stock == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: out
            ? _T.dangerSoft
            : low
                ? _T.warnSoft
                : _T.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        out ? context.t.outOfStockLower : context.t.inStock(stock),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _T.ts(10,
            weight: FontWeight.w600,
            color: out
                ? _T.danger
                : low
                    ? _T.warn
                    : _T.accent),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CART FAB
// ════════════════════════════════════════════════════════════════════════════
class _CartFAB extends StatelessWidget {
  const _CartFAB({
    required this.itemCount,
    required this.total,
    required this.badgeAnim,
    required this.onTap,
    required this.isLoading,
  });

  final int itemCount;
  final double total;
  final Animation<double> badgeAnim;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_T.primary, _T.primaryLt],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _T.floatShadow,
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              ScaleTransition(
                scale: badgeAnim,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart_rounded,
                        color: Colors.white, size: 24),
                    if (itemCount > 0)
                      Positioned(
                        top: -7,
                        right: -9,
                        child: Container(
                          width: 19,
                          height: 19,
                          decoration: BoxDecoration(
                              color: _T.accent, shape: BoxShape.circle),
                          child: Center(
                            child: Text('$itemCount',
                                style: _T.ts(10,
                                    weight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: isLoading
                  ? Text(context.t.processingPayment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _T.ts(13,
                          weight: FontWeight.w600, color: Colors.white))
                  : itemCount == 0
                      ? Text(context.t.cartEmpty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _T.ts(13, color: Colors.white60))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.t.itemsInCart(itemCount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _T.ts(13,
                                  weight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            Text(
                              context.t.tapReviewCheckout,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _T.ts(11, color: Colors.white54),
                            ),
                          ],
                        ),
            ),
            if (itemCount > 0 && !isLoading) ...[
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.format(total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _T.ts(15,
                          weight: FontWeight.w800, color: _T.accent),
                    ),
                    Text(context.t.inclVat,
                        style: _T.ts(10, color: Colors.white38)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white38, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CART BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════════════
class _CartSheet extends StatefulWidget {
  const _CartSheet({
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.onUpdateQty,
    required this.onRemove,
    required this.onClear,
    required this.onCheckout,
  });

  final List<CartItem> cart;
  final double subtotal, tax, total;
  final void Function(String, int) onUpdateQty;
  final void Function(String) onRemove;
  final VoidCallback onClear, onCheckout;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late List<CartItem> _localCart;

  @override
  void initState() {
    super.initState();
    _localCart = List.from(widget.cart);
  }

  void _localUpdateQty(String id, int qty) {
    widget.onUpdateQty(id, qty);
    setState(() {
      final idx = _localCart.indexWhere((i) => i.product.id == id);
      if (idx == -1) return;
      if (qty <= 0) {
        _localCart.removeAt(idx);
      } else {
        _localCart[idx] =
            CartItem(product: _localCart[idx].product, quantity: qty);
      }
    });
  }

  void _localRemove(String id) {
    widget.onRemove(id);
    setState(() => _localCart.removeWhere((i) => i.product.id == id));
  }

  double get _sub => _localCart.fold(0.0, (s, i) => s + i.product.price * i.quantity);
  double get _total => _sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _T.inkLight,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _T.primaryOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shopping_cart_rounded,
                      color: _T.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(context.t.cart,
                      style: _T.ts(18, weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (_localCart.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _T.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_localCart.length}',
                        style: _T.ts(11,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  IconButton(
                    tooltip: context.t.clearAll,
                    onPressed: () {
                      widget.onClear();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.delete_sweep_rounded,
                        size: 20, color: _T.danger),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: _T.border),
          if (_localCart.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _T.primaryOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shopping_cart_outlined,
                        color: _T.inkLight, size: 36),
                  ),
                  const SizedBox(height: 14),
                  Text('Your cart is empty',
                      style: _T.ts(15,
                          weight: FontWeight.w600, color: _T.inkMid)),
                  const SizedBox(height: 4),
                  Text('Add products from the list',
                      style: _T.ts(12, color: _T.inkLight)),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _localCart.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: _T.border),
                itemBuilder: (_, i) {
                  final item = _localCart[i];
                  return _CartRow(
                    item: item,
                    onIncrease: () => _localUpdateQty(
                        item.product.id, item.quantity + 1),
                    onDecrease: () => _localUpdateQty(
                        item.product.id, item.quantity - 1),
                    onEditQty: () async {
                      final qty = await showQuantityDialog(
                        context,
                        productName: item.product.name,
                        maxStock: item.product.stock,
                        initial: item.quantity,
                        title: context.t.setQuantity,
                      );
                      if (qty != null) {
                        _localUpdateQty(item.product.id, qty);
                      }
                    },
                    onRemove: () => _localRemove(item.product.id),
                  );
                },
              ),
            ),
          if (_localCart.isNotEmpty) ...[
            Divider(height: 1, color: _T.border), 
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
              color: _T.white,
              child: Column(
                children: [
                  _SummRow('Subtotal', _sub),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _T.primaryOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _T.primaryOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Amount due',
                                  style: _T.ts(11, color: _T.inkMid)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            CurrencyFormatter.format(_total),
                            style: _T.ts(20,
                                weight: FontWeight.w900, color: _T.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  BlocBuilder<SalesBloc, SalesState>(
                    builder: (_, state) {
                      final loading = state is SalesLoading;
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: loading
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  widget.onCheckout();
                                },
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(Icons.payment_rounded, size: 20),
                          label: Text(
                            loading ? 'Processing…' : 'Proceed to Checkout',
                            style: _T.ts(15,
                                weight: FontWeight.w700, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _T.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onEditQty,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrease, onDecrease, onRemove;
  final VoidCallback onEditQty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ProductPhoto(
            url: item.product.image,
            size: 46,
            radius: 10,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: _T.ts(13, weight: FontWeight.w600, color: _T.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  CurrencyFormatter.format(item.product.price),
                  style: _T.ts(12, color: _T.inkMid),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: _T.bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _T.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyBtn(icon: Icons.remove_rounded, onTap: onDecrease),
                GestureDetector(
                  onTap: onEditQty,
                  child: Tooltip(
                    message: context.t.enterQuantity,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      child: Text(
                        '${item.quantity}',
                        style: _T.ts(14,
                            weight: FontWeight.w800, color: _T.primary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                _QtyBtn(icon: Icons.add_rounded, onTap: onIncrease),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 88, minWidth: 56),
            child: Text(
              CurrencyFormatter.format(item.product.price * item.quantity),
              style: _T.ts(13, weight: FontWeight.w700, color: _T.primary),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _T.dangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close_rounded,
                  color: _T.danger, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 16, color: _T.primary),
      ),
    );
  }
}

class _SummRow extends StatelessWidget {
  const _SummRow(this.label, this.amount);

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _T.ts(13, color: _T.inkMid)),
        Text(
          CurrencyFormatter.format(amount),
          style: _T.ts(13, weight: FontWeight.w600, color: _T.ink),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ADD PRODUCT DIALOG
// ════════════════════════════════════════════════════════════════════════════
class _AddProductDialog extends StatefulWidget {
  const _AddProductDialog({
    required this.products,
    required this.cartIds,
    required this.onAdd,
  });

  final List<ProductEntity> products;
  final Set<String> cartIds;
  final void Function(ProductEntity) onAdd;

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  ProductEntity? _selected;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductEntity> get _filtered {
    if (_q.isEmpty) return widget.products;
    return widget.products.where((p) {
      return p.name.toLowerCase().contains(_q) ||
          (p.barcode?.toLowerCase().contains(_q) ?? false);
    }).toList();
  }

  void _submit() {
    if (_selected == null) return;
    widget.onAdd(_selected!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      child: Container(
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _T.floatShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                color: _T.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Product',
                            style: _T.ts(16,
                                weight: FontWeight.w800,
                                color: Colors.white)),
                        Text('Select a product to add to cart',
                            style: _T.ts(11, color: Colors.white54)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _q = v.toLowerCase()),
                style: _T.ts(15, weight: FontWeight.w600, color: _T.ink),
                decoration: InputDecoration(
                  hintText: context.t.searchProductsHint,
                  hintStyle: _T.ts(14, weight: FontWeight.w500, color: _T.inkLight),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: _T.ink, size: 18),
                  filled: true,
                  fillColor: _T.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(color: _T.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(color: _T.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(color: _T.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              color: _T.inkLight, size: 36),
                          const SizedBox(height: 10),
                          Text('No products found',
                              style: _T.ts(13, color: _T.inkMid)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: _T.border),
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final isSelected = _selected?.id == p.id;
                        final inCart = widget.cartIds.contains(p.id);
                        final oos = p.stock == 0;
                        return GestureDetector(
                          onTap: oos
                              ? null
                              : () => setState(() => _selected = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _T.primaryOpacity(0.07)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? _T.primary
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? _T.primary
                                          : oos
                                              ? _T.inkLight
                                              : _T.inkMid,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          size: 12, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                ProductPhoto(
                                  url: p.image,
                                  size: 40,
                                  radius: 9,
                                  iconSize: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: _T.ts(13,
                                            weight: FontWeight.w600,
                                            color: oos ? _T.inkMid : _T.ink),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.format(p.price),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _T.ts(12,
                                            weight: FontWeight.w700,
                                            color: oos
                                                ? _T.inkMid
                                                : _T.primary),
                                      ),
                                      if (p.barcode != null &&
                                          p.barcode!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          p.barcode!.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _T.ts(12,
                                              weight: FontWeight.w600,
                                              color: _T.ink),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _StockBadge(stock: p.stock),
                                      if (inCart) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _T.accentSoft,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text('In cart',
                                              style: _T.ts(9,
                                                  weight: FontWeight.w600,
                                                  color: _T.accent)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_selected != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _T.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _T.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: _T.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selected!.name,
                        style: _T.ts(13,
                            weight: FontWeight.w600, color: _T.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        CurrencyFormatter.format(_selected!.price),
                        style: _T.ts(13,
                            weight: FontWeight.w700, color: _T.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: _T.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                      child: Text('Cancel',
                          style: _T.ts(14,
                              weight: FontWeight.w600, color: _T.inkMid)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selected == null ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                        backgroundColor: _T.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                      child: Text(
                        _selected == null ? 'Select a product' : 'Add to Cart',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _T.ts(14,
                            weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}