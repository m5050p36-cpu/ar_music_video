import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نموذج الألوان المخصصة — كل لون يمكن للمستخدم تغييره
class CustomTheme {
  static const _prefsKey = 'custom_theme_v1';

  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color appBarBg;
  final Color appBarFg;
  final Color bottomNavBg;
  final Color onSurface;
  final Color error;
  final bool isLight;

  const CustomTheme({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.appBarBg,
    required this.appBarFg,
    required this.bottomNavBg,
    required this.onSurface,
    required this.error,
    required this.isLight,
  });

  // ═══════════════ الوضع الافتراضي — داكن ═══════════════
  static const CustomTheme defaultDark = CustomTheme(
    primary: Color(0xFF1DB954),
    secondary: Color(0xFF1ED760),
    background: Color(0xFF121212),
    surface: Color(0xFF181818),
    surfaceAlt: Color(0xFF282828),
    appBarBg: Color(0xFF121212),
    appBarFg: Color(0xFFE8E8E8),
    bottomNavBg: Color(0xFF181818),
    onSurface: Color(0xFFE8E8E8),
    error: Color(0xFFCF6679),
    isLight: false,
  );

  // ═══════════════ الوضع الافتراضي — فاتح ═══════════════
  static const CustomTheme defaultLight = CustomTheme(
    primary: Color(0xFF1DB954),
    secondary: Color(0xFF169C46),
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F1F3),
    appBarBg: Color(0xFFF7F8FA),
    appBarFg: Color(0xFF1A1A1A),
    bottomNavBg: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1A1A),
    error: Color(0xFFB3261E),
    isLight: true,
  );

  // ═══════════════ الحفظ والتحميل ═══════════════
  static Future<CustomTheme?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      return CustomTheme.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw)),
      );
    } catch (e) {
      debugPrint('CustomTheme.load error: $e');
      return null;
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(toJson()));
    } catch (e) {
      debugPrint('CustomTheme.save error: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  // ═══════════════ JSON ═══════════════
  Map<String, dynamic> toJson() => {
        'primary': _colorToInt(primary),
        'secondary': _colorToInt(secondary),
        'background': _colorToInt(background),
        'surface': _colorToInt(surface),
        'surfaceAlt': _colorToInt(surfaceAlt),
        'appBarBg': _colorToInt(appBarBg),
        'appBarFg': _colorToInt(appBarFg),
        'bottomNavBg': _colorToInt(bottomNavBg),
        'onSurface': _colorToInt(onSurface),
        'error': _colorToInt(error),
        'isLight': isLight,
      };

  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    return CustomTheme(
      primary: _intToColor(json['primary']),
      secondary: _intToColor(json['secondary']),
      background: _intToColor(json['background']),
      surface: _intToColor(json['surface']),
      surfaceAlt: _intToColor(json['surfaceAlt']),
      appBarBg: _intToColor(json['appBarBg']),
      appBarFg: _intToColor(json['appBarFg']),
      bottomNavBg: _intToColor(json['bottomNavBg']),
      onSurface: _intToColor(json['onSurface']),
      error: _intToColor(json['error']),
      isLight: json['isLight'] == true,
    );
  }

  static int _colorToInt(Color c) => c.toARGB32();
  static Color _intToColor(dynamic v) =>
      Color(v is int ? v : 0xFF000000);

  // ═══════════════ copyWith ═══════════════
  CustomTheme copyWith({
    Color? primary,
    Color? secondary,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? appBarBg,
    Color? appBarFg,
    Color? bottomNavBg,
    Color? onSurface,
    Color? error,
    bool? isLight,
  }) {
    return CustomTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      appBarBg: appBarBg ?? this.appBarBg,
      appBarFg: appBarFg ?? this.appBarFg,
      bottomNavBg: bottomNavBg ?? this.bottomNavBg,
      onSurface: onSurface ?? this.onSurface,
      error: error ?? this.error,
      isLight: isLight ?? this.isLight,
    );
  }
}
