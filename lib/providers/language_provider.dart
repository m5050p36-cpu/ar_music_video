import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  LanguageProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language_code') ?? 'ar';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _locale = _locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language_code', _locale.languageCode);
  }
}
