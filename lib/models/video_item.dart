import 'package:photo_manager/photo_manager.dart';

class VideoItem {
  final String id;
  final String title;
  final String path;
  final String folderName;
  final Duration duration;

  /// مسار الصورة المصغرة المحفوظة على الجهاز
  final String? thumbnailPath;

  /// مرجع مباشر للـ AssetEntity — متاح فقط في نفس جلسة الفحص
  /// عند التحميل من الكاش يكون null
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'folderName': folderName,
        'durationMs': duration.inMilliseconds,
        'thumbnailPath': thumbnailPath,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      folderName: (json['folderName'] ?? 'فيديوهات').toString(),
      duration: Duration(milliseconds: (json['durationMs'] ?? 0) as int),
      thumbnailPath: json['thumbnailPath'] as String?,
      asset: null,
    );
  }
}
