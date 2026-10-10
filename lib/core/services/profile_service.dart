import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../config/supabase_config.dart';
import 'supabase_service.dart';

class ProfileService {
  ProfileService._();

  /// يرفع صورة المستخدم ويُعيد الرابط العام.
  /// التخزين: avatars/{userId}/avatar_{timestamp}.jpg
  static Future<String?> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    if (!SupabaseService.isInitialized) return null;

    try {
      final fileSize = await file.length();
      Uint8List bytes;

      if (fileSize > 300 * 1024) {
        final compressed = await FlutterImageCompress.compressWithFile(
          file.absolute.path,
          minWidth: 512,
          minHeight: 512,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        bytes = compressed ?? await file.readAsBytes();
      } else {
        bytes = await file.readAsBytes();
      }

      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(path, bytes)
          .timeout(SupabaseConfig.timeout);

      return SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('uploadAvatar error: $e');
      return null;
    }
  }

  /// يُحدّث avatar_url في جدول profiles
  static Future<bool> updateAvatarUrl({
    required String userId,
    required String? avatarUrl,
  }) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId)
          .timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('updateAvatarUrl error: $e');
      return false;
    }
  }

  /// يُحدّث الاسم
  static Future<bool> updateFullName({
    required String userId,
    required String fullName,
  }) async {
    if (!SupabaseService.isInitialized) return false;
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'full_name': fullName.trim()})
          .eq('id', userId)
          .timeout(SupabaseConfig.timeout);
      return true;
    } catch (e) {
      debugPrint('updateFullName error: $e');
      return false;
    }
  }

  /// رفع + تحديث قاعدة البيانات في خطوة واحدة
  static Future<String?> updateAvatar({
    required String userId,
    required File file,
  }) async {
    final url = await uploadAvatar(userId: userId, file: file);
    if (url == null) return null;
    final ok = await updateAvatarUrl(userId: userId, avatarUrl: url);
    return ok ? url : null;
  }
}
