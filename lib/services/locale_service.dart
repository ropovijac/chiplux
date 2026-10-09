import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();

  static final LocaleService instance = LocaleService._();

  static const String _preferenceKey = 'chiplux_locale_v1';

  // null means: follow the device/system language.
  Locale? _locale;

  Locale? get locale => _locale;

  String get preferenceCode => _locale?.languageCode ?? 'system';

  /// The language Chiplux is actually displaying right now.
  ///
  /// When the user chooses "System", fall back to the device language.
  /// Chiplux currently supports English and Croatian, so every other
  /// system language safely falls back to English.
  String get effectiveLanguageCode {
    final code =
        _locale?.languageCode ??
        PlatformDispatcher.instance.locale.languageCode;

    return code == 'hr' ? 'hr' : 'en';
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_preferenceKey);

    if (code == null || code == 'system') {
      _locale = null;
      return;
    }

    if (code == 'en' || code == 'hr') {
      _locale = Locale(code);
    }
  }

  Future<void> setLanguage(String code) async {
    if (!const {'system', 'en', 'hr'}.contains(code)) {
      throw ArgumentError.value(code, 'code', 'Unsupported Chiplux locale');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, code);

    _locale = code == 'system' ? null : Locale(code);
    notifyListeners();
  }
}
