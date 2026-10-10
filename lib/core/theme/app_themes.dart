import 'package:flutter/material.dart';

/// 7 ثيمات للتطبيق
enum AppThemeMode {
  dark('داكن', Icons.dark_mode),
  light('فاتح', Icons.light_mode),
  amoled('AMOLED', Icons.brightness_2),
  ocean('محيط', Icons.water),
  sunset('غروب', Icons.wb_twilight),
  forest('غابة', Icons.forest),
  rose('وردي', Icons.local_florist);

  final String labelAr;
  final IconData icon;
  const AppThemeMode(this.labelAr, this.icon);

  static AppThemeMode fromName(String? name) {
    if (name == null) return AppThemeMode.dark;
    return AppThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => AppThemeMode.dark,
    );
  }
}

class AppThemes {
  AppThemes._();

  static ThemeData get(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:    return _build(_paletteDark);
      case AppThemeMode.light:   return _build(_paletteLight);
      case AppThemeMode.amoled:  return _build(_paletteAmoled);
      case AppThemeMode.ocean:   return _build(_paletteOcean);
      case AppThemeMode.sunset:  return _build(_paletteSunset);
      case AppThemeMode.forest:  return _build(_paletteForest);
      case AppThemeMode.rose:    return _build(_paletteRose);
    }
  }

  // ─── لوحات الألوان ────────────────────────────────────

  static const _paletteDark = _Palette(
    brightness: Brightness.dark,
    primary: Color(0xFF1DB954),
    secondary: Color(0xFF1ED760),
    background: Color(0xFF121212),
    surface: Color(0xFF181818),
    surfaceAlt: Color(0xFF282828),
    error: Color(0xFFCF6679),
    onPrimary: Colors.white,
    onSurface: Color(0xFFE8E8E8),
  );

  static const _paletteLight = _Palette(
    brightness: Brightness.light,
    primary: Color(0xFF1DB954),
    secondary: Color(0xFF169C46),
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F0F0),
    error: Color(0xFFB3261E),
    onPrimary: Colors.white,
    onSurface: Color(0xFF1A1A1A),
  );

  static const _paletteAmoled = _Palette(
    brightness: Brightness.dark,
    primary: Color(0xFF00E676),
    secondary: Color(0xFF00BFA5),
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceAlt: Color(0xFF0A0A0A),
    error: Color(0xFFFF5252),
    onPrimary: Colors.black,
    onSurface: Color(0xFFEAEAEA),
  );

  static const _paletteOcean = _Palette(
    brightness: Brightness.dark,
    primary: Color(0xFF29B6F6),
    secondary: Color(0xFF00BCD4),
    background: Color(0xFF0A1929),
    surface: Color(0xFF0F2740),
    surfaceAlt: Color(0xFF163455),
    error: Color(0xFFFF6E6E),
    onPrimary: Colors.white,
    onSurface: Color(0xFFE0F2F1),
  );

  static const _paletteSunset = _Palette(
    brightness: Brightness.dark,
    primary: Color(0xFFFF7043),
    secondary: Color(0xFFFFB74D),
    background: Color(0xFF1A0F0A),
    surface: Color(0xFF241510),
    surfaceAlt: Color(0xFF33201A),
    error: Color(0xFFEF5350),
    onPrimary: Colors.white,
    onSurface: Color(0xFFFFEBE0),
  );

  static const _paletteForest = _Palette(
    brightness: Brightness.dark,
    primary: Color(0xFF66BB6A),
    secondary: Color(0xFF43A047),
    background: Color(0xFF0E1A0E),
    surface: Color(0xFF142514),
    surfaceAlt: Color(0xFF1F331F),
    error: Color(0xFFEF9A9A),
    onPrimary: Colors.white,
    onSurface: Color(0xFFE8F5E9),
  );

  static const _paletteRose = _Palette(
    brightness: Brightness.dark,
    primary: Color(0xFFEC407A),
    secondary: Color(0xFFF06292),
    background: Color(0xFF1A0E14),
    surface: Color(0xFF261420),
    surfaceAlt: Color(0xFF351C2C),
    error: Color(0xFFEF5350),
    onPrimary: Colors.white,
    onSurface: Color(0xFFFCE4EC),
  );

  // ─── باني الثيم ───────────────────────────────────────

  static ThemeData _build(_Palette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      onSecondary: p.onPrimary,
      error: p.error,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.onSurface,
      surfaceContainerHighest: p.surfaceAlt,
    );

    final baseText = p.brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final textTheme = baseText.apply(
      bodyColor: p.onSurface,
      displayColor: p.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: p.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.onSurface.withValues(alpha: 0.08),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: p.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.error, width: 1.6),
        ),
        labelStyle: TextStyle(color: p.onSurface.withValues(alpha: 0.7)),
        hintStyle: TextStyle(color: p.onSurface.withValues(alpha: 0.5)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.onSurface.withValues(alpha: 0.55),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: p.surface),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceAlt,
        contentTextStyle: TextStyle(color: p.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.primary.withValues(alpha: 0.25),
        labelStyle: TextStyle(color: p.onSurface),
        side: BorderSide.none,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceAlt,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.onSurface.withValues(alpha: 0.8),
        textColor: p.onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? p.primary.withValues(alpha: 0.5)
              : null,
        ),
      ),
    );
  }
}

class _Palette {
  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color error;
  final Color onPrimary;
  final Color onSurface;

  const _Palette({
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.error,
    required this.onPrimary,
    required this.onSurface,
  });
}
