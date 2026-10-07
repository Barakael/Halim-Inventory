import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/pos_device_service.dart';
import '../../../../core/services/shop_profile_service.dart';
import '../../../sales/domain/entities/sale_entity.dart';
import '../../../shops/domain/entities/shop_entity.dart';
import 'receipt_content.dart';
import 'receipt_paper.dart';
import 'receipt_ticket.dart';
import 'tra_receipt_formatter.dart';

class _C {
  static const white = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF8FAFC);
  static const primary = Color(0xFF1E3A5F);
  static const primaryLt = Color(0xFF2B527A);
  static const accent = Color(0xFF00C896);
  static const ink = Color(0xFF1A2332);
  static const inkMid = Color(0xFF64748B);
  static const inkLight = Color(0xFF94A3B8);
  static const border = Color(0xFFE8EDF5);

  static Color primaryOp(double o) => primary.withValues(alpha: o);
  static Color whiteOp(double o) => Colors.white.withValues(alpha: o);
}

TextStyle _ts(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _C.ink,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

class ReceiptDialog extends StatefulWidget {
  const ReceiptDialog({
    super.key,
    required this.sale,
    this.shop,
    required this.onClose,
  });

  final SaleEntity sale;
  final ShopEntity? shop;
  final VoidCallback onClose;

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  static const String _printerMacKey = 'selected_printer_mac';

  bool _isPrinting = false;
  bool _isConnectingPrinter = false;
  String? _connectedPrinterName;
  ShopEntity? _resolvedShop;
  bool _shopLoading = true;
  String? _shopError;
  bool _showRawReceipt = false;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    try {
      final shop = await sl<ShopProfileService>().resolveShop(
        fromSale: widget.sale.shop,
        fromAuth: widget.shop,
      );
      if (!mounted) return;
      setState(() {
        _resolvedShop = shop;
        _shopLoading = false;
        if (shop == null) {
          _shopError = 'Shop profile not found. Contact your administrator.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shopLoading = false;
        _shopError = 'Could not load shop profile: $e';
      });
    }
  }

  ShopEntity get _effectiveShop {
    if (_resolvedShop != null) return _resolvedShop!;
    throw StateError('Shop profile not loaded');
  }

  ReceiptContent get _ticket => ReceiptContent.from(
        sale: widget.sale,
        shop: _effectiveShop,
      );

  String get _formattedDate =>
      DateFormat('dd/MM/yyyy HH:mm:ss').format(widget.sale.createdAt);

  Future<void> _connectPrinter() async {
    if (_isConnectingPrinter || _isPrinting) return;
    setState(() => _isConnectingPrinter = true);
    try {
      final hasPermission =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!hasPermission) {
        _showError('Bluetooth permission denied. Allow permissions and retry.');
        return;
      }

      final enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        _showError('Bluetooth is off. Turn it on, then connect printer.');
        return;
      }

      final pairedDevices = await PrintBluetoothThermal.pairedBluetooths;
      if (pairedDevices.isEmpty) {
        _showError(
            'No paired printers found. Pair the printer in device settings first.');
        return;
      }

      if (!mounted) return;
      final selected = await showModalBottomSheet<BluetoothInfo>(
        context: context,
        backgroundColor: _C.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _C.inkLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('Select Printer',
                    style: _ts(15, weight: FontWeight.w700)),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: pairedDevices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final device = pairedDevices[i];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _C.primaryOp(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.print_rounded,
                              color: _C.primary, size: 20),
                        ),
                        title: Text(
                          device.name.isEmpty ? 'Unknown Printer' : device.name,
                          style: _ts(14, weight: FontWeight.w600),
                        ),
                        subtitle: Text(device.macAdress,
                            style: _ts(11.5, color: _C.inkMid)),
                        onTap: () => Navigator.of(ctx).pop(device),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (selected == null) return;
      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: selected.macAdress,
      );
      if (!connected) {
        _showError('Failed to connect to ${selected.name}.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_printerMacKey, selected.macAdress);
      if (!mounted) return;
      setState(() {
        _connectedPrinterName =
            selected.name.isEmpty ? 'Bluetooth Printer' : selected.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer connected successfully.')),
      );
    } catch (e) {
      _showError('Printer connection failed: $e');
    } finally {
      if (mounted) setState(() => _isConnectingPrinter = false);
    }
  }

  Future<bool> _ensureBluetoothConnected() async {
    try {
      if (await PrintBluetoothThermal.connectionStatus) return true;
      final prefs = await SharedPreferences.getInstance();
      final mac = prefs.getString(_printerMacKey);
      if (mac == null || mac.isEmpty) return false;
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac)
          .timeout(const Duration(seconds: 10));
      if (!ok) return false;
      await Future.delayed(const Duration(milliseconds: 800));
      return true;
    } catch (e) {
      debugPrint('BT reconnect: $e');
      return false;
    }
  }

  Future<void> _printReceipt() async {
    if (_isPrinting ||
        _shopLoading ||
        _resolvedShop == null ||
        _shopError != null) {
      if (_shopError != null && mounted) {
        _showError(_shopError!);
      }
      return;
    }
    setState(() => _isPrinting = true);
    HapticFeedback.mediumImpact();

    try {
      if (PosDeviceService.instance.hasBuiltInPrinter) {
        try {
          await ReceiptTicket.printH10S(_ticket);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt printed on H10S.')),
            );
          }
          return;
        } catch (e) {
          debugPrint('[Print] H10S: $e');
        }
      }

      final btOk = await _ensureBluetoothConnected();
      if (btOk) {
        final bytes = await ReceiptTicket.buildBluetoothBytes(_ticket);
        final ok = await PrintBluetoothThermal.writeBytes(bytes);
        if (ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Receipt printed via Bluetooth.')),
            );
          }
          return;
        }
      }

      final pdfBytes = await ReceiptTicket.buildPdf(_ticket);
      final name = widget.sale.serialNumber.isNotEmpty
          ? widget.sale.serialNumber
          : widget.sale.id;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Receipt_$name',
      );
    } catch (e) {
      _showError('Print failed: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_isPrinting || _resolvedShop == null) return;
    setState(() => _isPrinting = true);
    HapticFeedback.lightImpact();
    try {
      final pdfBytes = await ReceiptTicket.buildPdf(_ticket);
      final name = widget.sale.serialNumber.isNotEmpty
          ? widget.sale.serialNumber
          : widget.sale.id;
      await Printing.sharePdf(bytes: pdfBytes, filename: 'Receipt_$name.pdf');
    } catch (e) {
      _showError('Share failed: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFFF4D4D),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_shopLoading) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _C.primaryOp(0.15),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _C.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text('Loading shop receipt profile…',
                  style: _ts(14, color: _C.inkMid, weight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (_resolvedShop == null) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _C.primaryOp(0.15),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_outlined,
                    size: 28, color: Color(0xFFFF4D4D)),
              ),
              const SizedBox(height: 16),
              Text('Receipt unavailable',
                  style: _ts(15, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                _shopError ?? 'Shop profile unavailable.',
                style: _ts(13, color: _C.inkMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final maxH = MediaQuery.of(context).size.height * 0.88;
    final ticket = _ticket;
    final receiptLines = TraReceiptFormatter.fromContent(ticket);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
        child: SizedBox(
          height: maxH,
          child: Container(
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _C.primaryOp(0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                _Header(sale: widget.sale, formattedDate: _formattedDate),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      children: [
                        Text(
                          'Print preview',
                          style: _ts(11, weight: FontWeight.w700, color: _C.inkMid, letterSpacing: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Center(child: ReceiptPaper(content: ticket)),
                        const SizedBox(height: 16),
                        _RawReceiptToggle(
                          expanded: _showRawReceipt,
                          onTap: () =>
                              setState(() => _showRawReceipt = !_showRawReceipt),
                        ),
                        if (_showRawReceipt) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _C.border),
                            ),
                            child: SelectableText(
                              receiptLines.join('\n'),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                height: 1.35,
                                color: _C.ink,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _ActionBar(
                  isPrinting: _isPrinting,
                  isConnectingPrinter: _isConnectingPrinter,
                  connectedPrinterName: _connectedPrinterName,
                  hasBuiltInPrinter:
                      PosDeviceService.instance.hasBuiltInPrinter,
                  onConnectPrinter: _connectPrinter,
                  onPrint: _printReceipt,
                  onShare: _sharePdf,
                  onClose: widget.onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sale, required this.formattedDate});
  final SaleEntity sale;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    final receiptLabel = sale.serialNumber.isNotEmpty
        ? sale.serialNumber
        : 'Receipt #${sale.id}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.primary, _C.primaryLt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _C.whiteOp(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _C.whiteOp(0.25), width: 1.5),
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 14),
          Text('Payment Successful',
              style: _ts(18, weight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.whiteOp(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(receiptLabel,
                style: _ts(12, color: Colors.white, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),
          Text(formattedDate, style: _ts(11.5, color: _C.whiteOp(0.65))),
        ],
      ),
    );
  }
}

class _RawReceiptToggle extends StatelessWidget {
  const _RawReceiptToggle({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 15, color: _C.inkMid),
              const SizedBox(width: 8),
              Text(
                expanded ? 'Hide receipt text' : 'View receipt text',
                style: _ts(12.5, color: _C.inkMid, weight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: _C.inkMid,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isPrinting,
    required this.isConnectingPrinter,
    required this.connectedPrinterName,
    required this.hasBuiltInPrinter,
    required this.onConnectPrinter,
    required this.onPrint,
    required this.onShare,
    required this.onClose,
  });

  final bool isPrinting;
  final bool isConnectingPrinter;
  final String? connectedPrinterName;
  final bool hasBuiltInPrinter;
  final VoidCallback onConnectPrinter;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: _C.white,
        border: Border(top: BorderSide(color: _C.border)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connectedPrinterName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected_rounded,
                      size: 16, color: _C.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Connected: $connectedPrinterName',
                      style: _ts(12, color: _C.inkMid, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          if (!hasBuiltInPrinter)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isConnectingPrinter ? null : onConnectPrinter,
                  icon: isConnectingPrinter
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth_rounded, size: 16),
                  label: Text(isConnectingPrinter
                      ? 'Connecting…'
                      : 'Connect printer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _C.primary,
                    side: BorderSide(color: _C.primaryOp(0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPrinting ? null : onPrint,
              icon: isPrinting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded, size: 18),
              label: Text(isPrinting ? 'Printing…' : 'Print Receipt'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isPrinting ? null : onShare,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _C.primary,
                    side: BorderSide(color: _C.primaryOp(0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                  label: const Text('New Sale'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _C.inkMid,
                    side: const BorderSide(color: _C.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
