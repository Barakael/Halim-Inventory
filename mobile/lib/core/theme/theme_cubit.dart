import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'brand_palette.dart';

/// Persisted brand theme preset: classic / warm / grove.
class ThemeCubit extends Cubit<BrandPalette> {
  ThemeCubit() : super(BrandPalette.classic);

  static const _prefsKey = 'app_theme_id';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKey);
    final palette = BrandPalette.byId(id);
    BrandTokens.current = palette;
    emit(palette);
  }

  Future<void> setTheme(String id) async {
    final palette = BrandPalette.byId(id);
    BrandTokens.current = palette;
    emit(palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, palette.id);
  }

  Future<void> setPalette(BrandPalette palette) => setTheme(palette.id);
}
