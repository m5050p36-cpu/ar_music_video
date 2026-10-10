import '../../models/audio_track.dart';
import 'media_scanner.dart';

/// wrapper رقيق فوق MediaScanner للتوافق الخلفي
class MetadataService {
  MetadataService._();

  static Future<List<AudioTrack>> scanAndParseFiles(List<String> paths) async {
    return MediaScanner.scanAudio();
  }
}
