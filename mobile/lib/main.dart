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

      // Bake production/LAN API at build time:
      // flutter build apk --dart-define=API_BASE_URL=https://haslim.co.tz/api
      const String baseUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://haslim.co.tz/api',
      );

      final normalized = normalizeApiBaseUrl(baseUrl);
      assert(() {
        // ignore: avoid_print
        print('API_BASE_URL=$normalized');
        return true;
      }());

      try {
        await PosDeviceService.instance.initialize();
      } catch (e, st) {
        debugPrint('PosDeviceService init failed: $e\n$st');
      }

      await setupDependencies(baseUrl: normalized);
      runApp(const App());
    },
    (error, stack) => debugPrint('Uncaught error: $error\n$stack'),
  );
}
