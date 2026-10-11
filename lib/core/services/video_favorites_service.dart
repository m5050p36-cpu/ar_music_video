import 'package:shared_preferences/shared_preferences.dart';

/// خدمة المفضلة للفيديوهات — منفصلة عن مفضلة الصوتيات
class VideoFavoritesService {
  VideoFavoritesService._();

  static const String _key = 'user_favorite_videos';

  static Future<List<String>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> toggleFavorite(String videoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      bool isFav;
      if (list.contains(videoPath)) {
        list.remove(videoPath);
        isFav = false;
      } else {
        list.add(videoPath);
        isFav = true;
      }
      await prefs.setStringList(_key, list);
      return isFav;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isFavorite(String videoPath) async {
    final list = await getFavorites();
    return list.contains(videoPath);
  }
}
