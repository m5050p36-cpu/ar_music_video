import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';

import 'permission_service.dart';

class FileOpsService {
  FileOpsService._();

  static final OnAudioQuery _audioQuery = OnAudioQuery();

  /// نتيجة الحذف
  static const int resultOk = 0;
  static const int resultFileNotFound = 1;
  static const int resultPermissionDenied = 2;
  static const int resultFailed = 3;

  // ═══════════════════════════════════════════════════════════════
  // اختيار مجلد
  // ═══════════════════════════════════════════════════════════════
  static Future<String?> pickDestinationDirectory() async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد الوجهة',
      );
    } catch (e) {
      debugPrint('pickDestination error: $e');
      return null;
    }
  }

  static Future<String> _uniqueDest(String dir, String name) async {
    final dot = name.lastIndexOf('.');
    final hasExt = dot > 0;
    final base = hasExt ? name.substring(0, dot) : name;
    final ext = hasExt ? name.substring(dot) : '';
    var candidate = '$dir/$name';
    var n = 1;
    while (await File(candidate).exists()) {
      candidate = '$dir/${base}_$n$ext';
      n++;
    }
    return candidate;
  }

  // ═══════════════════════════════════════════════════════════════
  // نسخ / نقل
  // ═══════════════════════════════════════════════════════════════
  static Future<bool> copyFile({
    required String sourcePath,
    required String destDir,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final dest = await _uniqueDest(destDir, sourcePath.split('/').last);
      await src.copy(dest);
      return true;
    } catch (e) {
      debugPrint('copyFile error: $e');
      return false;
    }
  }

  static Future<bool> moveFile({
    required String sourcePath,
    required String destDir,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final dest = await _uniqueDest(destDir, sourcePath.split('/').last);
      try {
        await src.rename(dest);
      } on FileSystemException {
        await src.copy(dest);
        await src.delete();
      }
      return true;
    } catch (e) {
      debugPrint('moveFile error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // حذف صوتي — يعمل من الجهاز فعليًا
  // ═══════════════════════════════════════════════════════════════
  static Future<int> deleteAudio({
    required String songId,
    required String path,
  }) async {
    try {
      final f = File(path);
      if (!await f.exists()) return resultFileNotFound;

      // 1. جرّب الحذف المباشر أولًا (يعمل مع MANAGE_EXTERNAL_STORAGE)
      try {
        await f.delete();
        // 2. حدّث MediaStore
        await _refreshMediaStore(path);
        return resultOk;
      } on FileSystemException catch (e) {
        if (e.osError?.errorCode == 13 || // EACCES
            e.message.toLowerCase().contains('permission')) {
          // حاول طلب الصلاحية
          final granted = await PermissionService.requestManageStorage();
          if (granted) {
            // أعد المحاولة
            try {
              await f.delete();
              await _refreshMediaStore(path);
              return resultOk;
            } catch (_) {}
          }
          return resultPermissionDenied;
        }
        debugPrint('deleteAudio fs error: $e');
      }
      return resultFailed;
    } catch (e) {
      debugPrint('deleteAudio error: $e');
      return resultFailed;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // حذف فيديو
  // ═══════════════════════════════════════════════════════════════
  static Future<int> deleteVideo({
    required String assetId,
    required String path,
  }) async {
    try {
      // 1. جرّب PhotoManager أولًا (يدعم Scoped Storage على Android 10+)
      if (assetId.isNotEmpty) {
        try {
          final result =
              await PhotoManager.editor.deleteWithIds([assetId]);
          if (result.isNotEmpty) return resultOk;
        } catch (e) {
          debugPrint('PhotoManager delete failed: $e');
        }
      }

      // 2. جرّب حذف مباشر
      final f = File(path);
      if (!await f.exists()) return resultFileNotFound;

      try {
        await f.delete();
        await _refreshMediaStore(path);
        return resultOk;
      } on FileSystemException catch (e) {
        if (e.osError?.errorCode == 13 ||
            e.message.toLowerCase().contains('permission')) {
          final granted = await PermissionService.requestManageStorage();
          if (granted) {
            try {
              await f.delete();
              await _refreshMediaStore(path);
              return resultOk;
            } catch (_) {}
          }
          return resultPermissionDenied;
        }
      }
      return resultFailed;
    } catch (e) {
      debugPrint('deleteVideo error: $e');
      return resultFailed;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // تحديث MediaStore (ليختفي الملف من التطبيقات الأخرى)
  // ═══════════════════════════════════════════════════════════════
  static Future<void> _refreshMediaStore(String path) async {
    try {
      await _audioQuery.scanMedia(path);
    } catch (e) {
      debugPrint('scanMedia error: $e');
    }
  }
}
