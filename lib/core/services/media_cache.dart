import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/audio_track.dart';
import '../../models/video_item.dart';

/// تخزين دائم لقوائم الصوتيات والفيديوهات — يمنع إعادة الفحص في كل مرة.
class MediaCache {
  MediaCache._();

  static const _audioKey = 'cache_audio_list_v2';
  static const _videoKey = 'cache_video_list_v3';
  static const _audioTsKey = 'cache_audio_ts_v2';
  static const _videoTsKey = 'cache_video_ts_v3';

  /// مدة صلاحية الكاش — بعدها نُعيد الفحص
  static const Duration ttl = Duration(hours: 6);

  // ═══════════════════════ Audio ═══════════════════════

  static Future<List<AudioTrack>> loadAudio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_audioKey);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(AudioTrack.fromJson)
          .toList();
      return list;
    } catch (e) {
      debugPrint('MediaCache.loadAudio error: $e');
      return [];
    }
  }

  static Future<void> saveAudio(List<AudioTrack> tracks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(tracks.map((t) => t.toJson()).toList());
      await prefs.setString(_audioKey, json);
      await prefs.setInt(
        _audioTsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('MediaCache.saveAudio error: $e');
    }
  }

  static Future<bool> isAudioStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_audioTsKey);
      if (ts == null) return true;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts));
      return age > ttl;
    } catch (_) {
      return true;
    }
  }

  // ═══════════════════════ Video ═══════════════════════

  static Future<List<VideoItem>> loadVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_videoKey);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(VideoItem.fromJson)
          .toList();
      return list;
    } catch (e) {
      debugPrint('MediaCache.loadVideos error: $e');
      return [];
    }
  }

  static Future<void> saveVideos(List<VideoItem> videos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(videos.map((v) => v.toJson()).toList());
      await prefs.setString(_videoKey, json);
      await prefs.setInt(
        _videoTsKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('MediaCache.saveVideos error: $e');
    }
  }

  static Future<bool> isVideoStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_videoTsKey);
      if (ts == null) return true;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts));
      return age > ttl;
    } catch (_) {
      return true;
    }
  }

  /// مسح الكاش (للاستخدام عند إعادة الفحص اليدوي)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_audioKey);
    await prefs.remove(_videoKey);
    await prefs.remove(_audioTsKey);
    await prefs.remove(_videoTsKey);
  }
}
