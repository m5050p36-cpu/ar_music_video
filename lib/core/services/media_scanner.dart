import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/audio_track.dart';
import '../../models/video_item.dart';

class MediaScanner {
  MediaScanner._();

  static final OnAudioQuery _audioQuery = OnAudioQuery();
  static const int _pathWorkers = 12;

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

  /// يطلب صلاحية الفيديو عبر قناتين (permission_handler + photo_manager)
  /// يُرجع true إن كانت ممنوحة
  static Future<bool> ensureVideoPermission() async {
    // ─── 1. permission_handler أولًا ───
    try {
      // Android 13+
      final videosStatus = await Permission.videos.status;
      debugPrint('📹 videos permission status: $videosStatus');

      if (!videosStatus.isGranted) {
        final result = await Permission.videos.request();
        debugPrint('📹 after request: $result');
        if (result.isPermanentlyDenied) {
          debugPrint('📹 PERMANENTLY DENIED — user must go to Settings');
          return false;
        }
      }

      // للتوافق مع Android 12 وأقل
      if (!await Permission.videos.isGranted) {
        final storage = await Permission.storage.status;
        if (!storage.isGranted) {
          await Permission.storage.request();
        }
      }
    } catch (e) {
      debugPrint('permission_handler error: $e');
    }

    // ─── 2. photo_manager ───
    try {
      final ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.common,
            mediaLocation: false,
          ),
        ),
      );
      debugPrint('📹 PhotoManager state: $ps');
      return ps.isAuth || ps.hasAccess;
    } catch (e) {
      debugPrint('PhotoManager request error: $e');
      return false;
    }
  }

  static Future<List<VideoItem>> scanVideos() async {
    try {
      // ═══ طلب الصلاحية أولًا ═══
      final hasPerm = await ensureVideoPermission();
      if (!hasPerm) {
        debugPrint('❌ Video permission denied');
        return [];
      }

      // ═══ جلب الألبومات ═══
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          videoOption: const FilterOption(
            sizeConstraint: SizeConstraint(minWidth: 50, minHeight: 50),
          ),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      debugPrint('📹 Albums found: ${albums.length}');
      if (albums.isEmpty) {
        debugPrint('❌ No albums — trying without filters');
        // جرّب بدون filter
        final fallback = await PhotoManager.getAssetPathList(
          type: RequestType.video,
          onlyAll: true,
        );
        debugPrint('📹 Fallback albums: ${fallback.length}');
        if (fallback.isEmpty) return [];
        return await _scanFromAlbum(fallback.first);
      }

      return await _scanFromAlbum(albums.first);
    } catch (e, st) {
      debugPrint('scanVideos error: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
      return [];
    }
  }

  static Future<List<VideoItem>> _scanFromAlbum(AssetPathEntity album) async {
    try {
      final count = await album.assetCountAsync;
      debugPrint('📹 Total videos in album: $count');
      if (count == 0) return [];

      final assets = await album.getAssetListRange(start: 0, end: count);
      debugPrint('📹 Loaded ${assets.length} assets');

      return await _buildItems(assets);
    } catch (e) {
      debugPrint('_scanFromAlbum error: $e');
      return [];
    }
  }

  static Future<List<VideoItem>> _buildItems(
    List<AssetEntity> assets,
  ) async {
    final items = <VideoItem>[];

    for (var i = 0; i < assets.length; i += _pathWorkers) {
      final end = (i + _pathWorkers < assets.length)
          ? i + _pathWorkers
          : assets.length;
      final batch = assets.sublist(i, end);

      final batchItems = await Future.wait(batch.map(_buildOne));
      items.addAll(batchItems.whereType<VideoItem>());
    }

    return items;
  }

  static Future<VideoItem?> _buildOne(AssetEntity a) async {
    try {
      final file = await a.file;
      if (file == null) return null;

      final rawTitle = a.title;
      final title = (rawTitle != null && rawTitle.isNotEmpty)
          ? rawTitle
          : _fileName(file.path);

      final rawPath = a.relativePath;
      final folder = (rawPath != null && rawPath.isNotEmpty)
          ? rawPath.split('/').first
          : 'فيديوهات';

      return VideoItem(
        id: a.id,
        title: title,
        path: file.path,
        folderName: folder,
        duration: Duration(seconds: a.duration),
        thumbnailPath: null,
        asset: a,
      );
    } catch (e) {
      debugPrint('buildOne error: $e');
      return null;
    }
  }

  static String _fileName(String p) {
    final parts = p.split('/');
    return parts.isEmpty ? p : parts.last;
  }
}
