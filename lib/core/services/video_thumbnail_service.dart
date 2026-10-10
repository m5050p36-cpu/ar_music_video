import '../../models/video_item.dart';
import 'media_scanner.dart';

/// wrapper متوافق مع الواجهة القديمة — يعتمد داخليًا على MediaScanner/photo_manager
/// (بدلًا من video_thumbnail المحذوفة)
class VideoThumbnailService {
  VideoThumbnailService._();

  static const int parallelWorkers = 4;

  /// يفحص ملفات الفيديو عبر MediaStore ويعيد قائمة VideoItem.
  /// (المعامل `videoPaths` محفوظ للتوافق فقط — يُتجاهل لأن الفحص تلقائي)
  static Future<List<VideoItem>> generateThumbnailsInBatches(
    List<String> videoPaths,
  ) async {
    return MediaScanner.scanVideos();
  }
}
