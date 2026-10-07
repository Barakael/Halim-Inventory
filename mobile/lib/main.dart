import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/network/api_path.dart';
import 'core/services/pos_device_service.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };

      await Hive.initFlutter();

      const String baseUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://terapay.teratech.co.tz/api',
      );

      try {
        await PosDeviceService.instance.initialize();
      } catch (e, st) {
        debugPrint('PosDeviceService init failed: $e\n$st');
      }

      await setupDependencies(baseUrl: normalizeApiBaseUrl(baseUrl));
      runApp(const App());
    },
    (error, stack) => debugPrint('Uncaught error: $error\n$stack'),
  );
}
