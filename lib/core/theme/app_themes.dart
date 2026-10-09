import 'package:flutter/material.dart';

enum AppThemeMode {
  dark,
  light,
  amoled,
  ocean,
  sunset,
  forest,
  rose,
}

class AppThemes {
  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return _buildTheme(
          primary: const Color(0xFF6366F1), // Indigo
          background: const Color(0xFF0F172A),
          surface: const Color(0xFF1E293B),
          text: Colors.white,
          brightness: Brightness.dark,
        );
      case AppThemeMode.light:
        return _buildTheme(
          primary: const Color(0xFF4F46E5),
          background: const Color(0xFFF8FAFC),
          surface: Colors.white,
          text: const Color(0xFF0F172A),
          brightness: Brightness.light,
        );
      case AppThemeMode.amoled:
        return _buildTheme(
          primary: const Color(0xFF818CF8),
          background: Colors.black, // Pure Black for AMOLED battery saving
          surface: const Color(0xFF121212),
          text: Colors.white,
          brightness: Brightness.dark,
        );
      case AppThemeMode.ocean:
        return _buildTheme(
          primary: const Color(0xFF06B6D4), // Cyan
          background: const Color(0xFF082F49),
          surface: const Color(0xFF0C4A6E),
          text: Colors.white,
          brightness: Brightness.dark,
        );
      case AppThemeMode.sunset:
        return _buildTheme(
          primary: const Color(0xFFF97316), // Orange
          background: const Color(0xFF431407),
          surface: const Color(0xFF7C2D12),
          text: Colors.white,
          brightness: Brightness.dark,
        );
      case AppThemeMode.forest:
        return _buildTheme(
          primary: const Color(0xFF10B981), // Emerald
          background: const Color(0xFF064E3B),
          surface: const Color(0xFF065F46),
          text: Colors.white,
          brightness: Brightness.dark,
        );
      case AppThemeMode.rose:
        return _buildTheme(
          primary: const Color(0xFFF43F5E), // Rose
          background: const Color(0xFF4C0519),
          surface: const Color(0xFF881337),
          text: Colors.white,
          brightness: Brightness.dark,
        );
    }
  }

  static ThemeData _buildTheme({
    required Color primary,
    required Color background,
    required Color surface,
    required Color text,
    required Brightness brightness,
  }) {
    return ThemeData(
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: primary.withAlpha(200),
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
        titleTextStyle: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      cardColor: surface,
      useMaterial3: true,
    );
  }
}
