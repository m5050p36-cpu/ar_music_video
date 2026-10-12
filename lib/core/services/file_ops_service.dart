import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// عمليات الملفات: نقل، نسخ، حذف
class FileOpsService {
  FileOpsService._();

  /// يفتح منتقي المجلدات
  static Future<String?> pickDestinationDirectory() async {
    try {
      final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد الوجهة',
      );
      return dir;
    } catch (e) {
      debugPrint('pickDestination error: $e');
      return null;
    }
  }

  /// يبني اسمًا غير مكرر داخل المجلد
  static Future<String> _uniqueDest(
    String destDir,
    String fileName,
  ) async {
    final dotIdx = fileName.lastIndexOf('.');
    final hasExt = dotIdx > 0;
    final base = hasExt ? fileName.substring(0, dotIdx) : fileName;
    final ext = hasExt ? fileName.substring(dotIdx) : '';

    var candidate = '$destDir/$fileName';
    var n = 1;
    while (await File(candidate).exists()) {
      candidate = '$destDir/${base}_$n$ext';
      n++;
    }
    return candidate;
  }

  /// نسخ ملف
  static Future<bool> copyFile({
    required String sourcePath,
    required String destDir,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final name = sourcePath.split('/').last;
      final dest = await _uniqueDest(destDir, name);
      await src.copy(dest);
      return true;
    } catch (e) {
      debugPrint('copyFile error: $e');
      return false;
    }
  }

  /// نقل ملف (rename أو copy+delete)
  static Future<bool> moveFile({
    required String sourcePath,
    required String destDir,
  }) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final name = sourcePath.split('/').last;
      final dest = await _uniqueDest(destDir, name);

      try {
        await src.rename(dest);
      } on FileSystemException {
        // أجهزة تخزين مختلفة — copy + delete
        await src.copy(dest);
        await src.delete();
      }
      return true;
    } catch (e) {
      debugPrint('moveFile error: $e');
      return false;
    }
  }

  /// حذف ملف صوتي — يستخدم حذف مباشر من نظام الملفات.
  /// MediaStore سيُحدَّث تلقائيًا في الفحص التالي.
  static Future<bool> deleteAudio({
    required String songId,
    required String path,
  }) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('deleteAudio error: $e');
      return false;
    }
  }

  /// حذف فيديو — يستخدم PhotoManager (يدعم Scoped Storage)
  static Future<bool> deleteVideo({
    required String assetId,
    required String path,
  }) async {
    try {
      // 1. حاول عبر PhotoManager (يعمل على Android 10+)
      if (assetId.isNotEmpty) {
        try {
          final result =
              await PhotoManager.editor.deleteWithIds([assetId]);
          if (result.isNotEmpty) return true;
        } catch (e) {
          debugPrint('PhotoManager delete failed: $e');
        }
      }

      // 2. حذف مباشر
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('deleteVideo error: $e');
      return false;
    }
  }
}
