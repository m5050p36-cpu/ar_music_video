import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// جلب صور أغلفة الألبومات مع cache في الذاكرة.
/// لا نستخدم SharedPreferences (ثقيل) — الذاكرة تكفي لجلسة كاملة.
class AlbumArtService {
  AlbumArtService._();

  static final OnAudioQuery _q = OnAudioQuery();

  /// cache: songId -> bytes (nullable يعني "لا يوجد غلاف")
  static final Map<String, Uint8List?> _cache = {};

  /// منع تكرار الاستدعاءات المتزامنة
  static final Map<String, Future<Uint8List?>> _pending = {};

  static Future<Uint8List?> getArt(String songId) {
    if (_cache.containsKey(songId)) {
      return Future.value(_cache[songId]);
    }
    if (_pending.containsKey(songId)) {
      return _pending[songId]!;
    }

    final future = _load(songId);
    _pending[songId] = future;
    future.whenComplete(() => _pending.remove(songId));
    return future;
  }

  static Future<Uint8List?> _load(String songId) async {
    try {
      final id = int.tryParse(songId);
      if (id == null) return null;

      final bytes = await _q.queryArtwork(
        id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 400,
      );

      final result = bytes == null ? null : Uint8List.fromList(bytes);
      _cache[songId] = result;
      return result;
    } catch (e) {
      debugPrint('AlbumArt error ($songId): $e');
      _cache[songId] = null;
      return null;
    }
  }

  /// مسح الكاش (نادرًا ما يُستخدم — مثلاً عند إعادة الفحص)
  static void clear() {
    _cache.clear();
    _pending.clear();
  }
}
