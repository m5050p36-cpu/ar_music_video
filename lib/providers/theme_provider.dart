import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_themes.dart';

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.dark;

  AppThemeMode get currentTheme => _currentTheme;
  ThemeData get themeData => AppThemes.getTheme(_currentTheme);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme_mode') ?? 0;
    if (themeIndex < AppThemeMode.values.length) {
      _currentTheme = AppThemeMode.values[themeIndex];
      notifyListeners();
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    _currentTheme = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme_mode', mode.index);
  }
}
