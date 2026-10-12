import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class PermissionService {
  PermissionService._();

  static Future<bool> requestAll(BuildContext? context) async {
    if (!Platform.isAndroid) return true;

    final perms = <Permission>[
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
      debugPrint('permission request error: $e');
    }

    try {
      await PhotoManager.requestPermissionExtend();
    } catch (_) {}

    // ═══ Android 11+ — يحتاج MANAGE_EXTERNAL_STORAGE للحذف الفعلي ═══
    if (Platform.isAndroid) {
      try {
        final manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          // يفتح شاشة الإعدادات — لا يمكن منحه من dialog عادي
          await Permission.manageExternalStorage.request();
        }
      } catch (e) {
        debugPrint('manageExternalStorage request error: $e');
      }
    }

    final bool audioGranted =
        (statuses[Permission.audio]?.isGranted ?? false) ||
        (statuses[Permission.storage]?.isGranted ?? false);
    final bool videoGranted =
        (statuses[Permission.videos]?.isGranted ?? false) ||
        (statuses[Permission.storage]?.isGranted ?? false);

    return audioGranted || videoGranted;
  }

  /// هل صلاحية إدارة الملفات مُمنوحة (Android 11+)؟
  static Future<bool> hasManageStorage() async {
    if (!Platform.isAndroid) return true;
    try {
      final s = await Permission.manageExternalStorage.status;
      return s.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// يفتح شاشة الإعدادات لمنح صلاحية إدارة الملفات
  static Future<bool> requestManageStorage() async {
    if (!Platform.isAndroid) return true;
    try {
      final s = await Permission.manageExternalStorage.request();
      return s.isGranted;
    } catch (_) {
      return false;
    }
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

  static void showSettingsDialog(BuildContext context, String reason) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صلاحية مطلوبة'),
        content: Text(reason),
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
