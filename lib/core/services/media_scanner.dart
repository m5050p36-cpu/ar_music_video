import 'package:on_audio_query/on_audio_query.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/audio_track.dart';
import '../../models/video_item.dart';

/// فحص تلقائي لوسائط الجهاز عبر MediaStore — بدون اختيار يدوي.
class MediaScanner {
  MediaScanner._();

  static final OnAudioQuery _audioQuery = OnAudioQuery();

  /// يفحص كل مقاطع الصوت في الجهاز
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
      return [];
    }
  }

  /// يجلب صورة غلاف مقطع واحد (lazy — عند الطلب فقط)
  static Future<List<int>?> getAlbumArt(int songId) async {
    try {
      return await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 400,
      );
    } catch (_) {
      return null;
    }
  }

  /// يفحص كل الفيديوهات في الجهاز
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
      final assets = await allVideos.getAssetListRange(start: 0, end: 1000);

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

        items.add(
          VideoItem(
            id: a.id,
            title: title,
            path: file.path,
            folderName: folder,
            duration: Duration(seconds: a.duration),
            thumbnailPath: null,
          ),
        );
      }
      return items;
    } catch (e) {
      return [];
    }
  }

  static String _fileName(String p) {
    final parts = p.split('/');
    return parts.isEmpty ? p : parts.last;
  }
}
