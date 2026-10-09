import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/audio_track.dart';

/// يُنفَّذ في isolate منفصل — لا يعطّل الـ UI
Map<String, dynamic> _readMetadataInIsolate(String path) {
  try {
    final file = File(path);
    final meta = readMetadata(file, getImage: true);
    return {
      'title': (meta.title?.trim().isNotEmpty ?? false)
          ? meta.title!.trim()
          : file.uri.pathSegments.last,
      'artist': meta.artist ?? 'فنان غير معروف',
      'album': meta.album ?? 'ألبوم عام',
      'durationMs': meta.duration?.inMilliseconds ?? 0,
      'imageBytes':
          meta.pictures.isNotEmpty ? meta.pictures.first.bytes : null,
      'ok': true,
    };
  } catch (e) {
    return {
      'title': path.split('/').last,
      'artist': 'ملف محلي',
      'album': 'ألبوم عام',
      'durationMs': 0,
      'imageBytes': null,
      'ok': false,
    };
  }
}

class MetadataService {
  MetadataService._();

  static const int parallelWorkers = 5;

  static Future<List<AudioTrack>> scanAndParseFiles(
    List<String> filePaths,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final List<AudioTrack> results = [];

    for (var i = 0; i < filePaths.length; i += parallelWorkers) {
      final end = (i + parallelWorkers < filePaths.length)
          ? i + parallelWorkers
          : filePaths.length;
      final batch = filePaths.sublist(i, end);

      final batchResults = await Future.wait(
        batch.map((path) => _parseOne(path, prefs)),
      );
      results.addAll(batchResults);
    }
    return results;
  }

  static Future<AudioTrack> _parseOne(
    String path,
    SharedPreferences prefs,
  ) async {
    // 1. حاول من الكاش
    final cachedTitle = prefs.getString('meta_title_$path');
    if (cachedTitle != null) {
      return AudioTrack(
        id: path.hashCode.toString(),
        title: cachedTitle,
        artist: prefs.getString('meta_artist_$path') ?? 'فنان غير معروف',
        album: prefs.getString('meta_album_$path') ?? 'ألبوم عام',
        path: path,
        duration: Duration(
          milliseconds: prefs.getInt('meta_duration_$path') ?? 0,
        ),
        // ملاحظة: لا نخزّن bytes الصورة في prefs (ثقيلة). سنعيد القراءة عند أول تشغيل فقط.
      );
    }

    // 2. اقرأ في isolate منفصل
    final meta = await compute(_readMetadataInIsolate, path);

    // 3. احفظ في الكاش
    await prefs.setString('meta_title_$path', meta['title'] as String);
    await prefs.setString('meta_artist_$path', meta['artist'] as String);
    await prefs.setString('meta_album_$path', meta['album'] as String);
    await prefs.setInt('meta_duration_$path', meta['durationMs'] as int);

    // 4. أعِد AudioTrack
    return AudioTrack(
      id: path.hashCode.toString(),
      title: meta['title'] as String,
      artist: meta['artist'] as String,
      album: meta['album'] as String,
      path: path,
      duration: Duration(milliseconds: meta['durationMs'] as int),
      albumArtBytes: meta['imageBytes'] as Uint8List?,
    );
  }
}
