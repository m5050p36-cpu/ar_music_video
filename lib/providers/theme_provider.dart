import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_themes.dart';
import '../core/theme/custom_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.dark;
  CustomTheme? _custom;
  bool _loaded = false;

  AppThemeMode get mode => _mode;
  CustomTheme? get custom => _custom;
  bool get isLoaded => _loaded;

  ThemeData get currentTheme => AppThemes.get(_mode, custom: _custom);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = AppThemeMode.fromName(prefs.getString(_prefsKey));
      _custom = await CustomTheme.load();
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

  /// يفعّل الثيم المخصص + يطبقه
  Future<void> setCustomTheme(CustomTheme theme) async {
    _custom = theme;
    _mode = AppThemeMode.custom;
    notifyListeners();
    try {
      await theme.save();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, AppThemeMode.custom.name);
    } catch (e) {
      debugPrint('ThemeProvider.setCustomTheme error: $e');
    }
  }

  /// يعيد التعيين للافتراضي للوضع الحالي
  Future<void> resetCustomTheme() async {
    _custom = _mode == AppThemeMode.custom
        ? (_custom?.isLight == true
            ? CustomTheme.defaultLight
            : CustomTheme.defaultDark)
        : _custom;
    if (_custom != null) {
      await _custom!.save();
    }
    notifyListeners();
  }

  Future<void> deleteCustomTheme() async {
    _custom = null;
    await CustomTheme.clear();
    if (_mode == AppThemeMode.custom) {
      _mode = AppThemeMode.dark;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, _mode.name);
      } catch (_) {}
    }
    notifyListeners();
  }

  // aliases
  Future<void> setTheme(AppThemeMode mode) => setMode(mode);
  Future<void> setThemeByName(String name) =>
      setMode(AppThemeMode.fromName(name));

  Future<void> cycleTheme() {
    final idx = AppThemeMode.values.indexOf(_mode);
    final next = AppThemeMode.values[(idx + 1) % AppThemeMode.values.length];
    return setMode(next);
  }
}
