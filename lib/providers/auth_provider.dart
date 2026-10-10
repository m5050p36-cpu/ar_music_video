import 'dart:async';
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

  StreamSubscription<AuthState>? _authSub;
  Timer? _initPoll;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get profile => _profile;
  bool get isAdmin =>
      _profile?['role'] == 'admin' || _profile?['role'] == 'superuser';
  bool get isSuperuser => _profile?['role'] == 'superuser';
  bool get isGuest => _status == AuthStatus.guest;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuestSaved = prefs.getBool(_guestKey) ?? false;

      if (isGuestSaved) {
        _setStatus(AuthStatus.guest);
        return;
      }

      // انتظر Supabase لحد 5 ثواني
      var waited = 0;
      while (!SupabaseService.isInitialized && waited < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }

      if (!SupabaseService.isInitialized) {
        _setStatus(AuthStatus.unauthenticated);
        return;
      }

      // 1. اربط listener — سيُحدّث الحالة تلقائيًا عند أي تغيير
      _authSub = SupabaseService.client.auth.onAuthStateChange.listen(
        _onAuthChange,
        onError: (e) => debugPrint('auth stream error: $e'),
      );

      // 2. اقرأ الجلسة الحالية (تُستعاد من التخزين المحلي فورًا)
      final session = SupabaseService.client.auth.currentSession;
      if (session?.user != null) {
        _currentUser = session!.user;
        await _loadProfile();
        _setStatus(AuthStatus.authenticated);
      } else {
        _setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('AuthProvider._initAuth error: $e');
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  Future<void> _onAuthChange(AuthState state) async {
    if (_disposed) return;
    final event = state.event;
    final session = state.session;

    if (session?.user != null) {
      _currentUser = session!.user;
      await _loadProfile();
      _setStatus(AuthStatus.authenticated);
    } else {
      _currentUser = null;
      _profile = null;
      if (event == AuthChangeEvent.signedOut) {
        _setStatus(AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null) return;
    // حاول 3 مرات — الأول قد يفشل بسبب RLS timing
    for (var i = 0; i < 3; i++) {
      final p = await SupabaseService.getCurrentUserProfile();
      if (p != null) {
        _profile = p;
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
    _profile = null;
  }

  /// يستدعيها التطبيق عند استئناف التشغيل
  Future<void> refreshProfile() async {
    await _loadProfile();
    if (!_disposed) notifyListeners();
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
        await _loadProfile();
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
        await Future.delayed(const Duration(milliseconds: 800));
        await _loadProfile();
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
    _authSub?.cancel();
    _initPoll?.cancel();
    super.dispose();
  }
}
