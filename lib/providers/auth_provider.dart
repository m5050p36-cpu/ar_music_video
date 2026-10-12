import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, guest, loading }

class AuthProvider extends ChangeNotifier {
  static const _guestKey = 'is_guest_mode';
  static const _sessionBackupKey = 'session_backup_v1';

  AuthStatus _status = AuthStatus.unknown;
  User? _currentUser;
  Map<String, dynamic>? _profile;
  bool _disposed = false;

  StreamSubscription<AuthState>? _authSub;
  String? _lastError;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get profile => _profile;
  String? get lastError => _lastError;
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

      // ═══ انتظر Supabase حتى 8 ثوان (كافٍ لأي شبكة) ═══
      var waited = 0;
      while (!SupabaseService.isInitialized && waited < 80) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
        if (_disposed) return;
      }

      // ═══ بعد الجهوزية ═══
      if (SupabaseService.isInitialized) {
        // 1. اربط stream التغييرات
        _authSub = SupabaseService.client.auth.onAuthStateChange.listen(
          _onAuthChange,
          onError: (e) => debugPrint('auth stream error: $e'),
        );

        // 2. اقرأ الجلسة المخزّنة
        final session = SupabaseService.client.auth.currentSession;
        if (session?.user != null) {
          _currentUser = session!.user;
          await _saveSessionBackup(session.user);
          await _loadProfile();
          _setStatus(AuthStatus.authenticated);
          return;
        }

        // 3. لا جلسة — لكن هل هناك backup محلي؟
        final backupEmail = prefs.getString(_sessionBackupKey);
        if (backupEmail != null && backupEmail.isNotEmpty) {
          // كان مسجل دخول سابقًا — أعد المحاولة في الخلفية
          _watchForLateSession();
        }
      }

      _setStatus(AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('AuthProvider._initAuth error: $e');
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  /// يراقب جلسة قد تُستعاد بعد دقائق (نادر)
  void _watchForLateSession() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (_disposed || !SupabaseService.isInitialized) return;
      final session = SupabaseService.client.auth.currentSession;
      if (session?.user != null) {
        _currentUser = session!.user;
        await _loadProfile();
        _setStatus(AuthStatus.authenticated);
      }
    });
  }

  Future<void> _saveSessionBackup(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionBackupKey, user.email ?? user.id);
    } catch (_) {}
  }

  Future<void> _clearSessionBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionBackupKey);
    } catch (_) {}
  }

  Future<void> _onAuthChange(AuthState state) async {
    if (_disposed) return;
    final session = state.session;

    if (session?.user != null) {
      _currentUser = session!.user;
      await _saveSessionBackup(session.user);
      await _loadProfile();
      _setStatus(AuthStatus.authenticated);
    } else {
      _currentUser = null;
      _profile = null;
      if (state.event == AuthChangeEvent.signedOut) {
        await _clearSessionBackup();
        _setStatus(AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> _loadProfile() async {
    if (_currentUser == null) return;
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

  Future<void> refreshProfile() async {
    await _loadProfile();
    if (!_disposed) notifyListeners();
  }

  void _setStatus(AuthStatus s) {
    if (_disposed) return;
    _status = s;
    notifyListeners();
  }

  String _translateError(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'البريد أو كلمة المرور غير صحيحة';
    }
    if (msg.contains('email not confirmed')) {
      return 'البريد غير مُفعّل — افتح بريدك واضغط رابط التفعيل';
    }
    if (msg.contains('user already registered')) {
      return 'هذا البريد مُسجّل مسبقًا';
    }
    if (msg.contains('password should be at least')) {
      return 'كلمة المرور قصيرة جدًا (6 أحرف على الأقل)';
    }
    if (msg.contains('unable to validate email')) {
      return 'صيغة البريد غير صحيحة';
    }
    if (msg.contains('email rate limit')) {
      return 'طلبات كثيرة — انتظر دقيقة';
    }
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('timeout') ||
        msg.contains('network')) {
      return 'لا يوجد اتصال بالإنترنت';
    }
    return 'حدث خطأ: $e';
  }

  Future<bool> signIn(String email, String password) async {
    _lastError = null;

    if (!SupabaseService.isInitialized) {
      _lastError = 'لم يتم الاتصال بـ Supabase';
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      _lastError = 'املأ البريد وكلمة المرور';
      return false;
    }

    _setStatus(AuthStatus.loading);

    try {
      final res = await SupabaseService.client.auth
          .signInWithPassword(email: cleanEmail, password: password)
          .timeout(const Duration(seconds: 20));

      final user = res.user;
      if (user != null) {
        _currentUser = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_guestKey, false);
        await _saveSessionBackup(user);
        await _loadProfile();
        _setStatus(AuthStatus.authenticated);
        return true;
      }

      _lastError = 'لم يستجب الخادم';
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } on AuthException catch (e) {
      _lastError = _translateError(e.message);
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } on TimeoutException {
      _lastError = 'انتهت مدة الاتصال';
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      _lastError = _translateError(e);
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String fullName) async {
    _lastError = null;

    if (!SupabaseService.isInitialized) {
      _lastError = 'لم يتم الاتصال بـ Supabase';
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();

    if (cleanEmail.isEmpty || password.isEmpty) {
      _lastError = 'املأ البريد وكلمة المرور';
      return false;
    }
    if (password.length < 6) {
      _lastError = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
      return false;
    }
    if (cleanName.isEmpty) {
      _lastError = 'الاسم الكامل مطلوب';
      return false;
    }

    _setStatus(AuthStatus.loading);

    try {
      final res = await SupabaseService.client.auth
          .signUp(
            email: cleanEmail,
            password: password,
            data: {'full_name': cleanName},
          )
          .timeout(const Duration(seconds: 20));

      final user = res.user;
      final session = res.session;

      if (user != null && session != null) {
        _currentUser = user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_guestKey, false);
        await _saveSessionBackup(user);
        await Future.delayed(const Duration(milliseconds: 600));
        await _loadProfile();
        _setStatus(AuthStatus.authenticated);
        return true;
      }

      if (user != null && session == null) {
        _lastError = 'تم إنشاء الحساب، لكن Supabase يطلب تأكيد البريد';
        _setStatus(AuthStatus.unauthenticated);
        return false;
      }

      _lastError = 'لم يتم إنشاء الحساب';
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } on AuthException catch (e) {
      _lastError = _translateError(e.message);
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } on TimeoutException {
      _lastError = 'انتهت مدة الاتصال';
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      _lastError = _translateError(e);
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<void> continueAsGuest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_guestKey, true);
    } catch (_) {}
    _currentUser = null;
    _profile = null;
    _lastError = null;
    _setStatus(AuthStatus.guest);
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestKey);
    } catch (_) {}
    await _clearSessionBackup();

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.client.auth
            .signOut()
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    _currentUser = null;
    _profile = null;
    _lastError = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }
}
