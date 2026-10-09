import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://YOUR_SUPABASE_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const Duration defaultTimeout = Duration(seconds: 15);

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> initialize() async {
    // إذا كانت المفاتيح افتراضية، نتجاهل التهيئة ليعمل التطبيق Offline دون انهيار
    if (supabaseUrl.contains('YOUR_SUPABASE') || supabaseAnonKey.contains('YOUR_SUPABASE')) {
      debugPrint('Running in pure local offline mode');
      _isInitialized = false;
      return;
    }

    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
        ),
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase safe warning: $e');
      _isInitialized = false;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (!_isInitialized || client == null) return null;
    final user = client?.auth.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cachedRole = prefs.getString('user_role_${user.id}');
    final cachedName = prefs.getString('user_name_${user.id}');

    try {
      final res = await client!
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single()
          .timeout(defaultTimeout);

      await prefs.setString('user_role_${user.id}', res['role'] ?? 'user');
      await prefs.setString('user_name_${user.id}', res['full_name'] ?? '');
      return res;
    } catch (_) {
      if (cachedRole != null) {
        return {
          'id': user.id,
          'email': user.email,
          'full_name': cachedName ?? '',
          'role': cachedRole,
        };
      }
    }
    return null;
  }
}
