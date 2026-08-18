import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, device-persisted set of "favorite" destination/business ids for
/// the current user — the single source of truth for every heart/favorite
/// toggle in the app (Profile's Favoritos tab, BusinessDetailScreen's
/// AppBar heart).
///
/// A singleton: every screen that calls `FavoritesService()` gets the exact
/// same instance and the exact same [idsNotifier]. Screens listen to that
/// notifier (a [ValueNotifier] is itself a [Listenable]/[ChangeNotifier]),
/// so toggling a favorite in one screen (e.g. [BusinessDetailScreen])
/// updates it and any other screen listening (e.g. `ProfileScreen`, kept
/// alive in [MainLayout]'s `IndexedStack`) reacts immediately — no app
/// restart or manual pull-to-refresh required.
class FavoritesService {
  factory FavoritesService() => instance;

  FavoritesService._internal();

  static final FavoritesService instance = FavoritesService._internal();

  static const _key = 'favorite_destination_ids';

  /// Always-current snapshot of favorite ids, kept in memory so listeners
  /// don't have to re-read SharedPreferences on every notification.
  final ValueNotifier<Set<String>> idsNotifier = ValueNotifier<Set<String>>(
    <String>{},
  );

  bool _hydrated = false;

  Future<void> _ensureHydrated() async {
    if (_hydrated) return;
    final prefs = await SharedPreferences.getInstance();
    idsNotifier.value = (prefs.getStringList(_key) ?? const []).toSet();
    _hydrated = true;
  }

  Future<Set<String>> getFavoriteIds() async {
    await _ensureHydrated();
    return idsNotifier.value;
  }

  Future<bool> isFavorite(String id) async {
    final ids = await getFavoriteIds();
    return ids.contains(id);
  }

  /// Adds/removes [id], persists the change and updates [idsNotifier] —
  /// returns the new favorite state. [id] is always compared/stored as a
  /// plain [String] (both mock destination ids and business uuids already
  /// are strings) so there's no int/String mismatch to worry about.
  Future<bool> toggleFavorite(String id) async {
    await _ensureHydrated();
    final updated = Set<String>.of(idsNotifier.value);
    final nowFavorite = !updated.remove(id);
    if (nowFavorite) updated.add(id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated.toList());
    idsNotifier.value = updated;

    debugPrint(
      '[FavoritesService] toggleFavorite("$id") -> nowFavorite=$nowFavorite, '
      'totalFavorites=${updated.length}',
    );

    return nowFavorite;
  }
}
