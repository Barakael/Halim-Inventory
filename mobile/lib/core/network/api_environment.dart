import '../utils/platform_utils.dart';

/// Local Laravel API (`frontend/.env` `LARAVEL_URL` + `/api`).
///
/// A physical phone cannot use the computer's loopback address. Pass the
/// machine's LAN address instead:
/// `--dart-define=API_BASE_URL=http://192.168.10.170:8000/api`
const String apiBaseUrlOverride = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String localApiBaseUrl() {
  if (apiBaseUrlOverride.isNotEmpty) return apiBaseUrlOverride;
  // Android emulator reaches the host machine through 10.0.2.2.
  if (PlatformUtils.isAndroid) return 'http://10.0.2.2:8000/api';
  return 'http://127.0.0.1:8000/api';
}
