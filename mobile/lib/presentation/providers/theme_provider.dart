import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    _initPrefs();
    return ThemeMode.system;
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final value = _prefs?.getString(_key);
      if (value != null && _prefs != null) {
        state = ThemeMode.values.firstWhere(
          (e) => e.toString() == value,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {}
  }

  Future<void> toggleTheme(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    state = mode;
    if (_prefs != null) {
      await _prefs!.setString(_key, mode.toString());
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
