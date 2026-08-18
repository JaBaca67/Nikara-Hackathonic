import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/core/services/auth_service.dart';

/// Set de ids favoritos persistido en el dispositivo, **por cuenta**; singleton
/// con [idsNotifier] compartido para que togglear un favorito en una pantalla
/// se refleje al instante en las demás.
///
/// La clave lleva el id del usuario porque antes era una sola global
/// (`favorite_destination_ids`): con el selector de cuentas eso significaba que
/// al alternar de perfil se veían los favoritos del anterior — y como
/// `_hydratedKey` es estado de un singleton que sobrevive al
/// `pushAndRemoveUntil` del cambio de cuenta, ni siquiera bastaba con separar
/// la clave: hay que re-hidratar cuando cambia el dueño. Mismo defecto que
/// tenía el avatar antes de la migración 015.
class FavoritesService {
  factory FavoritesService() => instance;

  FavoritesService._internal();

  static final FavoritesService instance = FavoritesService._internal();

  /// Clave única de antes de separar por cuenta. Se adopta una sola vez (ver
  /// [_ensureHydrated]) para no perder los favoritos ya guardados.
  static const _legacyKey = 'favorite_destination_ids';

  static const _keyPrefix = 'favorite_ids_';

  /// Sin sesión los favoritos siguen funcionando (el modo invitado puede
  /// guardar), pero en su propio cajón: al iniciar sesión no se mezclan con los
  /// de la cuenta.
  static const _guestKey = '${_keyPrefix}guest';

  /// Snapshot en memoria para que los listeners no relean SharedPreferences en cada notificación.
  final ValueNotifier<Set<String>> idsNotifier = ValueNotifier<Set<String>>(
    <String>{},
  );

  /// Clave bajo la que se hidrató [idsNotifier]; null = todavía no se hidrató.
  /// Comparar contra [_currentKey] es lo que detecta un cambio de cuenta sin
  /// necesidad de que nadie avise.
  String? _hydratedKey;

  String get _currentKey {
    final userId = AuthService().currentAuthUser?.id;
    return userId == null ? _guestKey : '$_keyPrefix$userId';
  }

  Future<void> _ensureHydrated() async {
    final key = _currentKey;
    if (_hydratedKey == key) return;
    final prefs = await SharedPreferences.getInstance();

    var ids = prefs.getStringList(key);
    if (ids == null) {
      // Primera lectura de esta cuenta: si todavía existe la lista global
      // anterior, se adopta y se borra. Se la queda la primera cuenta que
      // abra favoritos tras actualizar, que es la única atribución posible.
      final legacy = prefs.getStringList(_legacyKey);
      if (legacy != null) {
        ids = legacy;
        await prefs.setStringList(key, legacy);
        await prefs.remove(_legacyKey);
      }
    }

    idsNotifier.value = (ids ?? const <String>[]).toSet();
    _hydratedKey = key;
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
    await prefs.setStringList(_currentKey, updated.toList());
    idsNotifier.value = updated;

    return nowFavorite;
  }

  /// Descarta el snapshot en memoria para que la próxima lectura vuelva a
  /// SharedPreferences. La llama [AuthService] al alternar de cuenta o cerrar
  /// sesión: sin esto los favoritos del perfil anterior se seguirían viendo
  /// hasta reiniciar la app, porque el singleton no se recrea.
  void invalidate() {
    _hydratedKey = null;
    idsNotifier.value = const <String>{};
  }
}
