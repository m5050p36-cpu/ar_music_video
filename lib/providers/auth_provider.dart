import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/supabase_service.dart';

enum AuthStatus { authenticated, unauthenticated, guest, loading }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.guest;
  User? _currentUser;
  Map<String, dynamic>? _profile;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get profile => _profile;
  bool get isAdmin => _profile?['role'] == 'admin' || _profile?['role'] == 'superuser';
  bool get isGuest => _status == AuthStatus.guest;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGuestSaved = prefs.getBool('is_guest_mode') ?? true;

      if (!SupabaseService.isInitialized || SupabaseService.client == null) {
        _status = AuthStatus.guest;
        notifyListeners();
        return;
      }

      if (isGuestSaved) {
        _status = AuthStatus.guest;
        notifyListeners();
        return;
      }

      final user = SupabaseService.client?.auth.currentUser;
      if (user != null) {
        _currentUser = user;
        _profile = await SupabaseService.getCurrentUserProfile();
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.guest;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    if (!SupabaseService.isInitialized || SupabaseService.client == null) {
      return false;
    }
    try {
      final res = await SupabaseService.client!.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(SupabaseService.defaultTimeout);

      if (res.user != null) {
        _currentUser = res.user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', false);
        _profile = await SupabaseService.getCurrentUserProfile();
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('SignIn error: $e');
    }
    return false;
  }

  Future<bool> signUp(String email, String password, String fullName) async {
    if (!SupabaseService.isInitialized || SupabaseService.client == null) {
      return false;
    }
    try {
      final res = await SupabaseService.client!.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      ).timeout(SupabaseService.defaultTimeout);

      if (res.user != null) {
        _currentUser = res.user;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', false);
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('SignUp error: $e');
    }
    return false;
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);
    _status = AuthStatus.guest;
    _currentUser = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest_mode');
    if (SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        await SupabaseService.client!.auth.signOut().timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    _currentUser = null;
    _profile = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
