import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeColor {
  indigo("Indigo Navy", Color(0xFF1B365D), Color(0xFF008080)),
  emerald("Emerald Mint", Color(0xFF064E3B), Color(0xFF10B981)),
  purple("Royal Amethyst", Color(0xFF3B0764), Color(0xFFA855F7)),
  rose("Sunset Ruby", Color(0xFF881337), Color(0xFFF43F5E)),
  ocean("Ocean Azure", Color(0xFF0F172A), Color(0xFF06B6D4));

  final String label;
  final Color primary;
  final Color secondary;

  const AppThemeColor(this.label, this.primary, this.secondary);
}

class AppThemeState {
  final ThemeMode mode;
  final AppThemeColor color;

  const AppThemeState({
    required this.mode,
    required this.color,
  });

  AppThemeState copyWith({
    ThemeMode? mode,
    AppThemeColor? color,
  }) {
    return AppThemeState(
      mode: mode ?? this.mode,
      color: color ?? this.color,
    );
  }
}

class ThemeNotifier extends Notifier<AppThemeState> {
  static const _modeKey = 'theme_mode';
  static const _colorKey = 'theme_color';
  SharedPreferences? _prefs;

  @override
  AppThemeState build() {
    _initPrefs();
    return const AppThemeState(
      mode: ThemeMode.dark,
      color: AppThemeColor.indigo,
    );
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final modeStr = _prefs?.getString(_modeKey);
      final colorStr = _prefs?.getString(_colorKey);

      ThemeMode mode = ThemeMode.dark;
      if (modeStr != null) {
        mode = ThemeMode.values.firstWhere(
          (e) => e.toString() == modeStr,
          orElse: () => ThemeMode.dark,
        );
      }

      AppThemeColor color = AppThemeColor.indigo;
      if (colorStr != null) {
        color = AppThemeColor.values.firstWhere(
          (e) => e.name == colorStr,
          orElse: () => AppThemeColor.indigo,
        );
      }

      state = AppThemeState(mode: mode, color: color);
    } catch (_) {}
  }

  Future<void> toggleTheme(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    state = state.copyWith(mode: mode);
    if (_prefs != null) {
      await _prefs!.setString(_modeKey, mode.toString());
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    if (_prefs != null) {
      await _prefs!.setString(_modeKey, mode.toString());
    }
  }

  Future<void> setColor(AppThemeColor color) async {
    state = state.copyWith(color: color);
    if (_prefs != null) {
      await _prefs!.setString(_colorKey, color.name);
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeState>(() {
  return ThemeNotifier();
});
