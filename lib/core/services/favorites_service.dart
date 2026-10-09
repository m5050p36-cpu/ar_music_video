import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _key = 'user_favorite_tracks';

  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<bool> toggleFavorite(String trackPath) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    bool isFav;
    if (list.contains(trackPath)) {
      list.remove(trackPath);
      isFav = false;
    } else {
      list.add(trackPath);
      isFav = true;
    }
    await prefs.setStringList(_key, list);
    return isFav;
  }
}
