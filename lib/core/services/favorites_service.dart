import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set de ids favoritos persistido en el dispositivo; singleton con [idsNotifier] compartido para que togglear un favorito en una pantalla se refleje al instante en las demás.
class FavoritesService {
  factory FavoritesService() => instance;

  FavoritesService._internal();

  static final FavoritesService instance = FavoritesService._internal();

  static const _key = 'favorite_destination_ids';

  /// Snapshot en memoria para que los listeners no relean SharedPreferences en cada notificación.
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

  /// Agrega/quita [id], persiste y actualiza [idsNotifier]; devuelve el nuevo estado.
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
