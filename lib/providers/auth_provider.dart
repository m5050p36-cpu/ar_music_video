import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, guest, loading }

class AuthProvider extends ChangeNotifier {
  static const _guestKey = 'is_guest_mode';

  AuthStatus _status = AuthStatus.unknown;
  User? _currentUser;
  Map<String, dynamic>? _profile;
  bool _disposed = false;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get profile => _profile;
  bool get isAdmin =>
      _profile?['role'] == 'admin' || _profile?['role'] == 'superuser';
  bool get isGuest => _status == AuthStatus.guest;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuestSaved = prefs.getBool(_guestKey) ?? false;

      // 1. إن اختار الزائر سابقًا، ابدأ guest فورًا
      if (isGuestSaved) {
        _setStatus(AuthStatus.guest);
        return;
      }

      // 2. إن لم تُهيأ Supabase → unauthenticated (سيُرى شاشة Login)
      if (!SupabaseService.isInitialized) {
        _setStatus(AuthStatus.unauthenticated);
        return;
      }

      // 3. هل هناك جلسة محفوظة؟
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        _currentUser = user;
        _profile = await SupabaseService.getCurrentUserProfile();
        _setStatus(AuthStatus.authenticated);
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('AuthProvider._initAuth error: $e');
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  void _setStatus(AuthStatus s) {
    if (_disposed) return;
    _status = s;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    if (!SupabaseService.isInitialized) return false;
    _setStatus(AuthStatus.loading);
    try {
      final res = await SupabaseService.client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(SupabaseService.defaultTimeout);

      if (res.user != null) {
        _currentUser = res.user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_guestKey, false);
        _profile = await SupabaseService.getCurrentUserProfile();
        _setStatus(AuthStatus.authenticated);
        return true;
      }
    } catch (e) {
      debugPrint('signIn error: $e');
    }
    _setStatus(AuthStatus.unauthenticated);
    return false;
  }

  Future<bool> signUp(
    String email,
    String password,
    String fullName,
  ) async {
    if (!SupabaseService.isInitialized) return false;
    _setStatus(AuthStatus.loading);
    try {
      final res = await SupabaseService.client.auth
          .signUp(
            email: email,
            password: password,
            data: {'full_name': fullName},
          )
          .timeout(SupabaseService.defaultTimeout);

      if (res.user != null) {
        _currentUser = res.user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_guestKey, false);
        _profile = await SupabaseService.getCurrentUserProfile();
        _setStatus(AuthStatus.authenticated);
        return true;
      }
    } catch (e) {
      debugPrint('signUp error: $e');
    }
    _setStatus(AuthStatus.unauthenticated);
    return false;
  }

  Future<void> continueAsGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestKey, true);
    } catch (_) {}
    _currentUser = null;
    _profile = null;
    _setStatus(AuthStatus.guest);
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestKey);
    } catch (_) {}

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.auth
            .signOut()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    _currentUser = null;
    _profile = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
