import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Listens for built-in POS scanner broadcasts (Senraise H10S and similar).
class PosScannerService {
  PosScannerService._();

  static final PosScannerService instance = PosScannerService._();

  static const _channel = EventChannel('com.teratech.tera_pos/scanner');

  Stream<String>? _stream;
  StreamSubscription<String>? _subscription;

  Stream<String> get scans {
    if (!Platform.isAndroid) return const Stream.empty();
    _stream ??= _channel
        .receiveBroadcastStream()
        .where((event) => event != null)
        .map((event) => event.toString().trim())
        .where((code) => code.isNotEmpty);
    return _stream!;
  }

  StreamSubscription<String> listen(void Function(String barcode) onScan) {
    _subscription?.cancel();
    _subscription = scans.listen(onScan);
    return _subscription!;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
