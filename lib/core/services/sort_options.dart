import 'package:shared_preferences/shared_preferences.dart';

import '../../models/audio_track.dart';
import '../../models/video_item.dart';

enum SortOption {
  titleAsc,
  titleDesc,
  newestFirst,
  oldestFirst,
  durationDesc,
  durationAsc,
  artistAsc,
  albumAsc,
}

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.titleAsc:
        return 'A → Z';
      case SortOption.titleDesc:
        return 'Z → A';
      case SortOption.newestFirst:
        return 'الأحدث أولًا';
      case SortOption.oldestFirst:
        return 'الأقدم أولًا';
      case SortOption.durationDesc:
        return 'الأطول أولًا';
      case SortOption.durationAsc:
        return 'الأقصر أولًا';
      case SortOption.artistAsc:
        return 'حسب الفنان';
      case SortOption.albumAsc:
        return 'حسب الألبوم';
    }
  }
}

class SortHelper {
  SortHelper._();

  static const _audioKey = 'sort_audio_v1';
  static const _videoKey = 'sort_video_v1';

  static Future<SortOption> loadAudio() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_audioKey);
    return _fromName(name) ?? SortOption.titleAsc;
  }

  static Future<SortOption> loadVideo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_videoKey);
    return _fromName(name) ?? SortOption.newestFirst;
  }

  static Future<void> saveAudio(SortOption s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioKey, s.name);
  }

  static Future<void> saveVideo(SortOption s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_videoKey, s.name);
  }

  static SortOption? _fromName(String? name) {
    if (name == null) return null;
    for (final s in SortOption.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  static List<AudioTrack> applyAudio(
    List<AudioTrack> tracks,
    SortOption option,
  ) {
    final out = List<AudioTrack>.from(tracks);
    switch (option) {
      case SortOption.titleAsc:
        out.sort((a, b) => a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            ));
        break;
      case SortOption.titleDesc:
        out.sort((a, b) => b.title.toLowerCase().compareTo(
              a.title.toLowerCase(),
            ));
        break;
      case SortOption.newestFirst:
      case SortOption.oldestFirst:
        // لا يوجد تاريخ ملف — نستخدم المسار كتقريب
        out.sort((a, b) => option == SortOption.newestFirst
            ? b.path.compareTo(a.path)
            : a.path.compareTo(b.path));
        break;
      case SortOption.durationDesc:
        out.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case SortOption.durationAsc:
        out.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case SortOption.artistAsc:
        out.sort((a, b) => a.artist.toLowerCase().compareTo(
              b.artist.toLowerCase(),
            ));
        break;
      case SortOption.albumAsc:
        out.sort((a, b) => a.album.toLowerCase().compareTo(
              b.album.toLowerCase(),
            ));
        break;
    }
    return out;
  }

  static List<VideoItem> applyVideo(
    List<VideoItem> videos,
    SortOption option,
  ) {
    final out = List<VideoItem>.from(videos);
    switch (option) {
      case SortOption.titleAsc:
        out.sort((a, b) => a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            ));
        break;
      case SortOption.titleDesc:
        out.sort((a, b) => b.title.toLowerCase().compareTo(
              a.title.toLowerCase(),
            ));
        break;
      case SortOption.newestFirst:
      case SortOption.oldestFirst:
      case SortOption.artistAsc:
      case SortOption.albumAsc:
        // لا ينطبق — نستخدم العنوان
        out.sort((a, b) => a.title.compareTo(b.title));
        break;
      case SortOption.durationDesc:
        out.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case SortOption.durationAsc:
        out.sort((a, b) => a.duration.compareTo(b.duration));
        break;
    }
    return out;
  }
}
