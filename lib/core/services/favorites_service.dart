import 'package:shared_preferences/shared_preferences.dart';

/// Global, device-persisted set of "favorite" destination ids for the
/// current user — the single source of truth for every heart/favorite
/// toggle in the app (Profile's Favoritos tab today; Home/Map can read the
/// same store once their own cards wire up a toggle).
class FavoritesService {
  static const _key = 'favorite_destination_ids';

  Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<bool> isFavorite(String id) async {
    final ids = await getFavoriteIds();
    return ids.contains(id);
  }

  /// Adds/removes [id] and returns the new favorite state.
  Future<bool> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_key) ?? const []).toSet();
    final nowFavorite = !ids.remove(id);
    if (nowFavorite) ids.add(id);
    await prefs.setStringList(_key, ids.toList());
    return nowFavorite;
  }
}
