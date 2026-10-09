import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase_config.dart';

class SupabaseService {
  SupabaseService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Duration get defaultTimeout => SupabaseConfig.timeout;

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('SupabaseService.initialize() لم يُستدع بعد.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.projectUrl,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.publishableKey, // إصدار 2.16 لا يزال يقبل anonKey
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
          authFlowType: AuthFlowType.pkce,
        ),
        debug: false,
      );
      _isInitialized = true;
      debugPrint('✅ Supabase connected: ${SupabaseConfig.projectUrl}');
    } catch (e, st) {
      _isInitialized = false;
      debugPrint('⚠️ Supabase init failed (offline mode): $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (!_isInitialized) return null;
    final user = client.auth.currentUser;
    if (user == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final cachedRole = prefs.getString('user_role_${user.id}');
    final cachedName = prefs.getString('user_name_${user.id}');

    try {
      final res = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(defaultTimeout);

      if (res != null) {
        await prefs.setString('user_role_${user.id}', res['role'] ?? 'user');
        await prefs.setString('user_name_${user.id}', res['full_name'] ?? '');
        return res;
      }
    } catch (e) {
      debugPrint('getCurrentUserProfile network error: $e');
    }

    if (cachedRole != null) {
      return {
        'id': user.id,
        'email': user.email,
        'full_name': cachedName ?? '',
        'role': cachedRole,
      };
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getLatestVersion() async {
    if (!_isInitialized) return null;
    try {
      final res = await client
          .from('app_versions')
          .select()
          .eq('is_active', true)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(defaultTimeout);
      return res;
    } catch (e) {
      debugPrint('getLatestVersion error: $e');
      return null;
    }
  }
}
