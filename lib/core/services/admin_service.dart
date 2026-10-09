import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/services/supabase_service.dart';

class AdminService {
  static const String edgeFunctionUrl =
      'https://YOUR_SUPABASE_PROJECT_REF.supabase.co/functions/v1/admin-change-password';

  // 1. تغيير كلمة المرور فورياً عبر Edge Function
  static Future<bool> changeUserPassword({
    required String targetUserId,
    required String newPassword,
    required String adminId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': targetUserId,
          'new_password': newPassword,
          'admin_id': adminId,
        }),
      ).timeout(SupabaseService.defaultTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 2. تحديث صلاحية المستخدم (user / admin / superuser)
  static Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId)
          .timeout(SupabaseService.defaultTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  // 3. ضغط ورفع صورة البنر لسلة التخزين banners
  static Future<String?> uploadBannerImage(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      Uint8List imageBytes;

      // ضغط الصورة تلقائياً إذا كانت أكبر من 500KB
      if (fileSize > 500 * 1024) {
        final compressed = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          minWidth: 1280,
          minHeight: 720,
          quality: 80,
        );
        imageBytes = compressed ?? await imageFile.readAsBytes();
      } else {
        imageBytes = await imageFile.readAsBytes();
      }

      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.client.storage
          .from('banners')
          .uploadBinary(fileName, imageBytes)
          .timeout(SupabaseService.defaultTimeout);

      return SupabaseService.client.storage.from('banners').getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  // 4. حفظ البنر في الجدول
  static Future<bool> insertBanner({
    required String title,
    required String imageUrl,
    required String targetUrl,
    required int displayOrder,
  }) async {
    try {
      await SupabaseService.client.from('banners').insert({
        'title': title,
        'image_url': imageUrl,
        'target_url': targetUrl,
        'display_order': displayOrder,
        'is_active': true,
      }).timeout(SupabaseService.defaultTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  // 5. حذف بنر
  static Future<bool> deleteBanner(String bannerId) async {
    try {
      await SupabaseService.client
          .from('banners')
          .delete()
          .eq('id', bannerId)
          .timeout(SupabaseService.defaultTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  // 6. تحديث التحديث الإجباري للإصدار
  static Future<bool> toggleForceUpdate(String versionId, bool isForce) async {
    try {
      await SupabaseService.client
          .from('app_versions')
          .update({'force_update': isForce})
          .eq('id', versionId)
          .timeout(SupabaseService.defaultTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
