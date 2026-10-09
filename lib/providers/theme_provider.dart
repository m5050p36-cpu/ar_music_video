import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_themes.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.dark;
  bool _loaded = false;

  AppThemeMode get mode => _mode;
  bool get isLoaded => _loaded;
  ThemeData get currentTheme => AppThemes.get(_mode);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = AppThemeMode.fromName(prefs.getString(_prefsKey));
    } catch (e) {
      debugPrint('ThemeProvider.load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (e) {
      debugPrint('ThemeProvider.setMode error: $e');
    }
  }

  // ─── Aliases للتوافق مع الكود القديم ─────────────────
  Future<void> setTheme(AppThemeMode mode) => setMode(mode);
  Future<void> setThemeByName(String name) =>
      setMode(AppThemeMode.fromName(name));

  /// يبدّل للثيم التالي في الدورة
  Future<void> cycleTheme() {
    final idx = AppThemeMode.values.indexOf(_mode);
    final next = AppThemeMode.values[(idx + 1) % AppThemeMode.values.length];
    return setMode(next);
  }
}
