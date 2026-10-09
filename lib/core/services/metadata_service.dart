import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/audio_track.dart';

class MetadataService {
  static const int parallelWorkers = 5;

  static Future<List<AudioTrack>> scanAndParseFiles(List<String> filePaths) async {
    final prefs = await SharedPreferences.getInstance();
    final List<AudioTrack> results = [];

    for (var i = 0; i < filePaths.length; i += parallelWorkers) {
      final end = (i + parallelWorkers < filePaths.length) ? i + parallelWorkers : filePaths.length;
      final batch = filePaths.sublist(i, end);

      final batchResults = await Future.wait(batch.map((path) async {
        final cacheTitle = prefs.getString('meta_title_$path');
        final cacheArtist = prefs.getString('meta_artist_$path');
        final cacheDuration = prefs.getInt('meta_duration_$path');

        if (cacheTitle != null) {
          return AudioTrack(
            id: path.hashCode.toString(),
            title: cacheTitle,
            artist: cacheArtist ?? 'فنان غير معروف',
            album: prefs.getString('meta_album_$path') ?? 'ألبوم عام',
            path: path,
            duration: Duration(milliseconds: cacheDuration ?? 0),
          );
        }

        try {
          final file = File(path);
          // دالة readMetadata متزامنة بدون await
          final metadata = readMetadata(file, getImage: true);

          final title = (metadata.title != null && metadata.title!.trim().isNotEmpty)
              ? metadata.title!
              : file.uri.pathSegments.last;
          final artist = metadata.artist ?? 'فنان غير معروف';
          final album = metadata.album ?? 'ألبوم عام';
          final durationMs = metadata.duration?.inMilliseconds ?? 0;

          await prefs.setString('meta_title_$path', title);
          await prefs.setString('meta_artist_$path', artist);
          await prefs.setString('meta_album_$path', album);
          await prefs.setInt('meta_duration_$path', durationMs);

          return AudioTrack(
            id: path.hashCode.toString(),
            title: title,
            artist: artist,
            album: album,
            path: path,
            duration: Duration(milliseconds: durationMs),
            albumArtBytes: metadata.pictures.isNotEmpty ? metadata.pictures.first.bytes : null,
          );
        } catch (_) {
          return AudioTrack(
            id: path.hashCode.toString(),
            title: path.split('/').last,
            artist: 'ملف محلي',
            album: 'ألبوم عام',
            path: path,
            duration: Duration.zero,
          );
        }
      }));

      results.addAll(batchResults);
    }

    return results;
  }
}
