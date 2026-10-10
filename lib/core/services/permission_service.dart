import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// يطلب كل الصلاحيات التي يحتاجها التطبيق — يعمل على كل إصدارات Android.
class PermissionService {
  PermissionService._();

  /// يُستدعى مرة واحدة عند أول تشغيل.
  /// يرجّع `true` إن مُنحت كل الصلاحيات الأساسية.
  static Future<bool> requestAll(BuildContext? context) async {
    if (!Platform.isAndroid) return true;

    final List<Permission> perms = [
      Permission.notification,
      Permission.audio,
      Permission.videos,
      Permission.photos,
      Permission.storage,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    try {
      statuses = await perms.request();
    } catch (e) {
      debugPrint('permission_handler request error: $e');
    }

    try {
      await PhotoManager.requestPermissionExtend();
    } catch (e) {
      debugPrint('photo_manager request error: $e');
    }

    // ⚠️ الأقواس ضرورية — بدونها أسبقية ?? تُفسد التعبير
    final bool audioGranted =
        (statuses[Permission.audio]?.isGranted ?? false) ||
        (statuses[Permission.storage]?.isGranted ?? false);
    final bool videoGranted =
        (statuses[Permission.videos]?.isGranted ?? false) ||
        (statuses[Permission.storage]?.isGranted ?? false);

    final bool coreGranted = audioGranted || videoGranted;

    if (!coreGranted && context != null && context.mounted) {
      final bool permanentlyDenied =
          statuses.values.any((s) => s.isPermanentlyDenied);
      if (permanentlyDenied) {
        _showSettingsDialog(context);
      }
    }

    return coreGranted;
  }

  static Future<bool> hasCorePermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      final audio = await Permission.audio.status;
      if (audio.isGranted) return true;
      final storage = await Permission.storage.status;
      if (storage.isGranted) return true;
      final video = await Permission.videos.status;
      return video.isGranted;
    } catch (_) {
      return false;
    }
  }

  static void _showSettingsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الصلاحيات مرفوضة'),
        content: const Text(
          'لأجل عرض ملفات الصوت والفيديو في جهازك، نحتاج صلاحية الوصول.\n\n'
          'افتح الإعدادات → الصلاحيات → فعّل "الموسيقى والفيديو".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }
}
