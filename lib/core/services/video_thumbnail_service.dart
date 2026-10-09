import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/video_item.dart';

class VideoThumbnailService {
  static const int parallelWorkers = 4;

  static Future<List<VideoItem>> generateThumbnailsInBatches(List<String> videoPaths) async {
    final prefs = await SharedPreferences.getInstance();
    final tempDir = await getTemporaryDirectory();
    final List<VideoItem> results = [];

    // المعالجة على دفعات (4 بالتوازي)
    for (var i = 0; i < videoPaths.length; i += parallelWorkers) {
      final end = (i + parallelWorkers < videoPaths.length) ? i + parallelWorkers : videoPaths.length;
      final batch = videoPaths.sublist(i, end);

      final batchResults = await Future.wait(batch.map((path) async {
        final fileName = path.split('/').last;
        final folder = path.split('/').length > 1 ? path.split('/')[path.split('/').length - 2] : 'فيديوهات عامة';

        // فحص الكاش الدائم
        final cachedThumb = prefs.getString('vthumb_$path');
        if (cachedThumb != null && File(cachedThumb).existsSync()) {
          return VideoItem(
            id: path.hashCode.toString(),
            title: fileName,
            path: path,
            folderName: folder,
            duration: Duration.zero,
            thumbnailPath: cachedThumb,
          );
        }

        try {
          final thumb = await VideoThumbnail.thumbnailFile(
            video: path,
            thumbnailPath: tempDir.path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 200,
            quality: 75,
          );

          if (thumb != null) {
            await prefs.setString('vthumb_$path', thumb);
          }

          return VideoItem(
            id: path.hashCode.toString(),
            title: fileName,
            path: path,
            folderName: folder,
            duration: Duration.zero,
            thumbnailPath: thumb,
          );
        } catch (_) {
          return VideoItem(
            id: path.hashCode.toString(),
            title: fileName,
            path: path,
            folderName: folder,
            duration: Duration.zero,
            thumbnailPath: null,
          );
        }
      }));

      results.addAll(batchResults);
    }

    return results;
  }
}
