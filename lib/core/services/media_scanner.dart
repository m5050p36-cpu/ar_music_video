import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/audio_track.dart';
import '../../models/video_item.dart';

class MediaScanner {
  MediaScanner._();

  static final OnAudioQuery _audioQuery = OnAudioQuery();
  static Directory? _thumbDir;

  /// مجلد حفظ الصور المصغرة (دائم)
  static Future<Directory> _getThumbDir() async {
    if (_thumbDir != null && _thumbDir!.existsSync()) return _thumbDir!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/video_thumbs');
    if (!dir.existsSync()) await dir.create(recursive: true);
    _thumbDir = dir;
    return dir;
  }

  // ═══════════════════════ Audio ═══════════════════════

  static Future<List<AudioTrack>> scanAudio() async {
    try {
      final granted = await _audioQuery.permissionsStatus();
      if (!granted) {
        final ok = await _audioQuery.permissionsRequest();
        if (!ok) return [];
      }

      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final tracks = <AudioTrack>[];
      for (final s in songs) {
        if (s.isAlarm == true) continue;
        if (s.isRingtone == true) continue;
        if (s.isNotification == true) continue;
        if (s.size == 0) continue;
        if (s.data.isEmpty) continue;

        tracks.add(
          AudioTrack(
            id: s.id.toString(),
            title: (s.title.isNotEmpty) ? s.title : _fileName(s.data),
            artist: s.artist ?? 'فنان غير معروف',
            album: s.album ?? 'ألبوم عام',
            path: s.data,
            duration: Duration(milliseconds: s.duration ?? 0),
            albumArtUri: null,
          ),
        );
      }
      return tracks;
    } catch (e) {
      debugPrint('scanAudio error: $e');
      return [];
    }
  }

  // ═══════════════════════ Video ═══════════════════════

  static Future<List<VideoItem>> scanVideos() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.common,
            mediaLocation: false,
          ),
        ),
      );
      if (!permission.isAuth) return [];

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          videoOption: const FilterOption(
            sizeConstraint: SizeConstraint(minWidth: 100, minHeight: 100),
          ),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (albums.isEmpty) return [];

      final allVideos = albums.first;
      final assets = await allVideos.getAssetListRange(start: 0, end: 2000);
      final thumbDir = await _getThumbDir();

      final items = <VideoItem>[];
      for (final a in assets) {
        final file = await a.file;
        if (file == null) continue;

        final rawTitle = a.title;
        final title = (rawTitle != null && rawTitle.isNotEmpty)
            ? rawTitle
            : _fileName(file.path);

        final rawPath = a.relativePath;
        final folder = (rawPath != null && rawPath.isNotEmpty)
            ? rawPath.split('/').first
            : 'فيديوهات';

        // توليد الصورة المصغرة مرة واحدة فقط — تُحفظ دائمًا
        final thumbPath = await _ensureThumbnail(a, thumbDir);

        items.add(
          VideoItem(
            id: a.id,
            title: title,
            path: file.path,
            folderName: folder,
            duration: Duration(seconds: a.duration),
            thumbnailPath: thumbPath,
            asset: a,
          ),
        );
      }
      return items;
    } catch (e) {
      debugPrint('scanVideos error: $e');
      return [];
    }
  }

  /// يولّد الصورة المصغرة إن لم تكن موجودة — وإلا يعيد المسار المحفوظ
  static Future<String?> _ensureThumbnail(
    AssetEntity asset,
    Directory thumbDir,
  ) async {
    try {
      final file = File('${thumbDir.path}/${asset.id}.jpg');
      if (file.existsSync() && file.lengthSync() > 0) {
        return file.path;
      }

      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(400, 400),
        quality: 80,
      );
      if (bytes == null) return null;
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('thumbnail error for ${asset.id}: $e');
      return null;
    }
  }

  static String _fileName(String p) {
    final parts = p.split('/');
    return parts.isEmpty ? p : parts.last;
  }
}
