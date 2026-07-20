import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_frs/presentation/providers/theme_provider.dart';

class AppTheme {
  static const Color errorColor = Color(0xFFC62828);

  static ThemeData buildTheme(Brightness brightness, AppThemeColor colorPreset) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = colorPreset.primary;
    final secondaryColor = colorPreset.secondary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      textTheme: isDark
          ? GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
          : GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: isDark ? 2 : 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
      ),
    );
  }

  static ThemeData get lightTheme => buildTheme(Brightness.light, AppThemeColor.indigo);
  static ThemeData get darkTheme => buildTheme(Brightness.dark, AppThemeColor.indigo);
}
