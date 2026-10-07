import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Captures keyboard-wedge barcode scans from built-in POS scanners (e.g. H10S).
///
/// Uses [HardwareKeyboard] only — does not steal focus from dialogs / text fields.
class HardwareBarcodeListener extends StatefulWidget {
  const HardwareBarcodeListener({
    super.key,
    required this.onBarcode,
    required this.child,
    this.enabled = true,
  });

  final ValueChanged<String> onBarcode;
  final Widget child;
  final bool enabled;

  @override
  State<HardwareBarcodeListener> createState() =>
      _HardwareBarcodeListenerState();
}

class _HardwareBarcodeListenerState extends State<HardwareBarcodeListener> {
  Timer? _flushTimer;
  String _buffer = '';
  bool _handlerInstalled = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _installHandler();
  }

  @override
  void didUpdateWidget(covariant HardwareBarcodeListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _installHandler();
    } else if (!widget.enabled && oldWidget.enabled) {
      _removeHandler();
      _buffer = '';
      _flushTimer?.cancel();
    }
  }

  void _installHandler() {
    if (_handlerInstalled) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _handlerInstalled = true;
  }

  void _removeHandler() {
    if (!_handlerInstalled) return;
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _handlerInstalled = false;
  }

  /// True when a real editable field (dialog / search) owns focus.
  bool get _userTypingInField {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return false;
    final ctx = focused.context;
    if (ctx == null) return false;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null ||
        ctx.findAncestorWidgetOfExactType<TextField>() != null ||
        ctx.findAncestorWidgetOfExactType<TextFormField>() != null;
  }

  /// True when a dialog / bottom sheet is covering POS.
  bool get _modalOpen {
    final route = ModalRoute.of(context);
    return route != null && !route.isCurrent;
  }

  bool _onHardwareKey(KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) return false;
    if (_userTypingInField || _modalOpen) return false;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _completeScan(_buffer);
      return true;
    }

    final char = event.character;
    if (char != null &&
        char.isNotEmpty &&
        char != '\n' &&
        char != '\r' &&
        char != '\t') {
      _buffer += char;
      _flushTimer?.cancel();
      _flushTimer = Timer(const Duration(milliseconds: 120), () {
        if (_buffer.length >= 4) _completeScan(_buffer);
      });
      return true;
    }
    return false;
  }

  void _completeScan(String raw) {
    final code = raw.trim();
    _buffer = '';
    _flushTimer?.cancel();
    if (code.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onBarcode(code);
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _removeHandler();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
