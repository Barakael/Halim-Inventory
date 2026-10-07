import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Runtime detection for Senraise H10 / H10S POS terminals (built-in printer & scanner).
class PosDeviceInfo {
  const PosDeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.brand,
    required this.device,
    required this.isH10Series,
    required this.hasBuiltInPrinter,
  });

  final String manufacturer;
  final String model;
  final String brand;
  final String device;
  final bool isH10Series;
  final bool hasBuiltInPrinter;

  String get displayName {
    if (isH10Series) return 'H10S POS Terminal';
    if (model.isNotEmpty) return model;
    return 'Mobile Device';
  }

  factory PosDeviceInfo.unknown() => const PosDeviceInfo(
        manufacturer: '',
        model: '',
        brand: '',
        device: '',
        isH10Series: false,
        hasBuiltInPrinter: false,
      );
}

class PosDeviceService {
  PosDeviceService._();

  static final PosDeviceService instance = PosDeviceService._();

  PosDeviceInfo _info = PosDeviceInfo.unknown();
  bool _initialized = false;

  PosDeviceInfo get info => _info;
  bool get isInitialized => _initialized;
  bool get isH10Series => _info.isH10Series;
  bool get hasBuiltInPrinter => _info.hasBuiltInPrinter;

  Future<void> initialize() async {
    if (_initialized) return;

    if (!Platform.isAndroid) {
      _info = PosDeviceInfo.unknown();
      _initialized = true;
      return;
    }

    try {
      final android = await DeviceInfoPlugin().androidInfo;
      final manufacturer = android.manufacturer.toLowerCase();
      final model = android.model.toLowerCase();
      final brand = android.brand.toLowerCase();
      final device = android.device.toLowerCase();
      final product = android.product.toLowerCase();

      final isH10 = _matchesH10(manufacturer) ||
          _matchesH10(model) ||
          _matchesH10(brand) ||
          _matchesH10(device) ||
          _matchesH10(product);

      _info = PosDeviceInfo(
        manufacturer: android.manufacturer,
        model: android.model,
        brand: android.brand,
        device: android.device,
        isH10Series: isH10,
        hasBuiltInPrinter: isH10,
      );
    } catch (_) {
      _info = PosDeviceInfo.unknown();
    }

    _initialized = true;
  }

  bool _matchesH10(String value) {
    final v = value.toLowerCase();
    return v.contains('h10') ||
        v.contains('senraise') ||
        v.contains('posh5') ||
        (v.contains('sr') && v.contains('pos'));
  }
}
