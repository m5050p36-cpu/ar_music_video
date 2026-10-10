import 'package:photo_manager/photo_manager.dart';

class VideoItem {
  final String id;
  final String title;
  final String path;
  final String folderName;
  final Duration duration;
  final String? thumbnailPath;

  /// مرجع مباشر للـ AssetEntity — يُستخدم لتوليد الصورة المصغرة بكفاءة
  /// عبر MediaStore دون قراءة الملف كاملاً.
  final AssetEntity? asset;

  VideoItem({
    required this.id,
    required this.title,
    required this.path,
    required this.folderName,
    required this.duration,
    this.thumbnailPath,
    this.asset,
  });
}
