import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _prefsKey = 'app_language';
  static const _supported = <Locale>[Locale('ar'), Locale('en')];

  Locale _locale = const Locale('ar');
  bool _loaded = false;

  Locale get currentLocale => _locale;
  bool get isLoaded => _loaded;
  bool get isArabic => _locale.languageCode == 'ar';
  String get currentCode => _locale.languageCode;
  List<Locale> get supportedLocales => _supported;

  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && _supported.any((l) => l.languageCode == code)) {
        _locale = Locale(code);
      }
    } catch (e) {
      debugPrint('LanguageProvider.load error: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.languageCode);
    } catch (e) {
      debugPrint('LanguageProvider.setLocale error: $e');
    }
  }

  Future<void> toggle() => setLocale(
        isArabic ? const Locale('en') : const Locale('ar'),
      );

  // ─── Aliases للتوافق مع الكود القديم ─────────────────
  Future<void> toggleLanguage() => toggle();
  Future<void> setLanguage(String code) => setLocale(Locale(code));
}
