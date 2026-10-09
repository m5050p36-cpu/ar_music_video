import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  // المفاتيح الحقيقية لمشروعك في Supabase
  static const String supabaseUrl = 'https://sxaumorffdslpwtiyowa.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_qg85Q8zCYMY8BwWMsCwF_g_pi986J4p';
  static const Duration defaultTimeout = Duration(seconds: 15);

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
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
      debugPrint('Supabase successfully connected to: $supabaseUrl');
    } catch (e) {
      debugPrint('Supabase connection error (running in offline mode): $e');
      _isInitialized = false;
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
