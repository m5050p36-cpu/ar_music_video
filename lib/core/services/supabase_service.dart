import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://YOUR_SUPABASE_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const Duration defaultTimeout = Duration(seconds: 15);

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
    } catch (e) {
      debugPrint('Supabase Init Warning (App will run offline): $e');
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
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
