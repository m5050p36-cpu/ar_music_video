import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../core/services/supabase_service.dart';

class AdminService {
  static const String edgeFunctionUrl =
      'https://sxaumorffdslpwtiyowa.supabase.co/functions/v1/admin-change-password';

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

  static Future<bool> updateUserRole(String userId, String newRole) async {
    if (!SupabaseService.isInitialized) return false;
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
      }).timeout(SupabaseService.defaultTimeout);
      return true;
    } catch (_) {
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
          .timeout(SupabaseService.defaultTimeout);
      return true;
    } catch (_) {
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
          .timeout(SupabaseService.defaultTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
