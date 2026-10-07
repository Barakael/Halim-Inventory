import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app language: English (`en`) or Kiswahili (`sw`).
class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  static const _prefsKey = 'app_locale_code';

  static const supported = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == 'sw' || code == 'en') {
      emit(Locale(code!));
    }
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (code != 'en' && code != 'sw') return;
    emit(Locale(code));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  Future<void> toggle() async {
    await setLocale(
      state.languageCode == 'sw' ? const Locale('en') : const Locale('sw'),
    );
  }

  bool get isSwahili => state.languageCode == 'sw';
}
