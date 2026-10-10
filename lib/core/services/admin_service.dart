import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';
import 'supabase_service.dart';

class AdminService {
  AdminService._();

  // ═══════════════════════════════════════════════════════════════
  // تغيير كلمة المرور
  // ═══════════════════════════════════════════════════════════════
  static Future<bool> changeUserPassword({
    required String targetUserId,
    required String newPassword,
    String? adminId,
  }) async {
    if (!SupabaseService.isInitialized) return false;

    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) return false;
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
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('changeUserPassword error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // إدارة المستخدمين
  // ═══════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════
  // البنرات — رفع صورة
  // ═══════════════════════════════════════════════════════════════
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
          format: CompressFormat.jpeg,
        );
        imageBytes = compressed ?? await imageFile.readAsBytes();
      } else {
        imageBytes = await imageFile.readAsBytes();
      }

      final fileName =
          'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await SupabaseService.client.storage
          .from('banners')
          .uploadBinary(fileName, imageBytes)
          .timeout(SupabaseConfig.timeout);

      return SupabaseService.client.storage
          .from('banners')
          .getPublicUrl(fileName);
    } catch (e) {
      debugPrint('uploadBannerImage error: $e');
      return null;
    }
  }

  /// حذف صورة من Storage بناءً على رابطها العام
  static Future<void> deleteBannerImage(String publicUrl) async {
    if (!SupabaseService.isInitialized) return;
    try {
      final uri = Uri.parse(publicUrl);
      final segments = uri.pathSegments;
      final idx = segments.indexOf('banners');
      if (idx < 0 || idx + 1 >= segments.length) return;
      final fileName = segments.sublist(idx + 1).join('/');
      await SupabaseService.client.storage
          .from('banners')
          .remove([fileName])
          .timeout(SupabaseConfig.timeout);
    } catch (e) {
      debugPrint('deleteBannerImage error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // البنرات — CRUD
  // ═══════════════════════════════════════════════════════════════
  static Future<bool> insertBanner({
    required String? title,
    required String imageUrl,
    required String? targetUrl,
    required int displayOrder,
    required int height,
    bool isActive = true,
  }) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client.from('banners').insert({
        'title': (title == null || title.trim().isEmpty)
            ? null
            : title.trim(),
        'image_url': imageUrl,
        'target_url': (targetUrl == null || targetUrl.trim().isEmpty)
            ? null
            : targetUrl.trim(),
        'display_order': displayOrder,
        'height': height.clamp(100, 400),
        'is_active': isActive,
      }).timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('insertBanner error: $e');
      return false;
    }
  }

  static Future<bool> updateBanner({
    required String bannerId,
    required String? title,
    required String imageUrl,
    required String? targetUrl,
    required int displayOrder,
    required int height,
    required bool isActive,
  }) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client
          .from('banners')
          .update({
            'title': (title == null || title.trim().isEmpty)
                ? null
                : title.trim(),
            'image_url': imageUrl,
            'target_url': (targetUrl == null || targetUrl.trim().isEmpty)
                ? null
                : targetUrl.trim(),
            'display_order': displayOrder,
            'height': height.clamp(100, 400),
            'is_active': isActive,
          })
          .eq('id', bannerId)
          .timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('updateBanner error: $e');
      return false;
    }
  }

  static Future<bool> deleteBanner(String bannerId) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      // احذف الصورة أولًا
      final row = await SupabaseService.client
          .from('banners')
          .select('image_url')
          .eq('id', bannerId)
          .maybeSingle()
          .timeout(SupabaseConfig.timeout);
      if (row != null && row['image_url'] != null) {
        await deleteBannerImage(row['image_url'] as String);
      }

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

  static Future<bool> toggleBannerActive(
    String bannerId,
    bool isActive,
  ) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client
          .from('banners')
          .update({'is_active': isActive})
          .eq('id', bannerId)
          .timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('toggleBannerActive error: $e');
      return false;
    }
  }

  /// تبديل ترتيب بنرين (swap display_order)
  static Future<bool> swapBannerOrder({
    required String idA,
    required int orderA,
    required String idB,
    required int orderB,
  }) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      // استخدام +1000 كقيمة وسيطة لتفادي التصادم على UNIQUE (لو وُجد)
      await SupabaseService.client
          .from('banners')
          .update({'display_order': orderA + 1000})
          .eq('id', idA)
          .timeout(SupabaseConfig.timeout);

      await SupabaseService.client
          .from('banners')
          .update({'display_order': orderA})
          .eq('id', idB)
          .timeout(SupabaseConfig.timeout);

      await SupabaseService.client
          .from('banners')
          .update({'display_order': orderB})
          .eq('id', idA)
          .timeout(SupabaseConfig.timeout);

      return true;
    } catch (e) {
      debugPrint('swapBannerOrder error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // الإصدارات
  // ═══════════════════════════════════════════════════════════════
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
