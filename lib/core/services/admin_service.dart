import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';
import 'supabase_service.dart';

class AdminService {
  AdminService._();

  /// تغيير كلمة مرور أي مستخدم عبر Edge Function (يتطلب مستدعي أدمن).
  /// ملاحظة: `adminId` مُبقى للتوافق فقط، القيمة الفعلية تأتي من JWT.
  static Future<bool> changeUserPassword({
    required String targetUserId,
    required String newPassword,
    String? adminId,
  }) async {
    if (!SupabaseService.isInitialized) return false;

    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) {
      debugPrint('changeUserPassword: no active session');
      return false;
    }
    if (newPassword.length < 6) return false;

    try {
      final res = await http
          .post(
            Uri.parse(SupabaseConfig.changePasswordFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'user_id': targetUserId,
              'new_password': newPassword,
            }),
          )
          .timeout(SupabaseConfig.timeout);

      if (res.statusCode == 200) return true;
      debugPrint('changeUserPassword failed: ${res.statusCode} ${res.body}');
      return false;
    } catch (e) {
      debugPrint('changeUserPassword error: $e');
      return false;
    }
  }

  static Future<bool> updateUserRole(String userId, String newRole) async {
    if (!SupabaseService.isInitialized) return false;
    if (!['user', 'admin', 'superuser'].contains(newRole)) return false;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId)
          .timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('updateUserRole error: $e');
      return false;
    }
  }

  static Future<String?> uploadBannerImage(File imageFile) async {
    if (!SupabaseService.isInitialized) return null;
    try {
      final fileSize = await imageFile.length();
      Uint8List imageBytes;

      if (fileSize > 500 * 1024) {
        final compressed = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          minWidth: 1280,
          minHeight: 720,
          quality: 80,
          format: CompressFormat.jpeg, // ← lowercase
        );
        imageBytes = compressed ?? await imageFile.readAsBytes();
      } else {
        imageBytes = await imageFile.readAsBytes();
      }

      final fileName =
          'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await SupabaseService.client.storage
          .from('banners')
          .uploadBinary(fileName, imageBytes) // ← بدون FileOptions
          .timeout(SupabaseConfig.timeout);

      return SupabaseService.client.storage
          .from('banners')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('uploadBannerImage error: $e');
      return null;
    }
  }

  static Future<bool> insertBanner({
    required String title,
    required String imageUrl,
    required String targetUrl,
    required int displayOrder,
  }) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client.from('banners').insert({
        'title': title,
        'image_url': imageUrl,
        'target_url': targetUrl,
        'display_order': displayOrder,
        'is_active': true,
      }).timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('insertBanner error: $e');
      return false;
    }
  }

  static Future<bool> deleteBanner(String bannerId) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client
          .from('banners')
          .delete()
          .eq('id', bannerId)
          .timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('deleteBanner error: $e');
      return false;
    }
  }

  static Future<bool> toggleForceUpdate(String versionId, bool isForce) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client
          .from('app_versions')
          .update({'force_update': isForce})
          .eq('id', versionId)
          .timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('toggleForceUpdate error: $e');
      return false;
    }
  }
}
