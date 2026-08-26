import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';

class FavoritesServiceException implements Exception {
  const FavoritesServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Set de ids favoritos, **por cuenta**; singleton con [idsNotifier] compartido
/// para que togglear un favorito en una pantalla se refleje al instante en las
/// demás.
///
/// ## Por qué el almacenamiento es híbrido
///
/// Los favoritos de una cuenta con sesión viven en la tabla `user_favorites`
/// (supabase/sql/013_final_schema_additions.sql). Eso es lo que permite que el
/// dueño de un negocio vea cuánta gente lo guardó: mientras los favoritos
/// fueran locales, ese número no existía en ningún lado.
///
/// Pero el mismo set mezcla dos clases de id: el uuid de un negocio real y el
/// slug de un destino curado de `mock_destinations.dart` (`laguna-de-apoyo`).
/// `user_favorites.item_id` es `uuid not null`, así que los slugs **no caben en
/// la tabla** y se quedan en [SharedPreferences]. No es una decisión de diseño
/// sino la consecuencia de que los destinos del mock todavía no sean filas
/// reales; el híbrido desaparece solo el día que se retire ese archivo.
///
/// Un invitado tampoco tiene fila en `profiles`, así que todos sus favoritos
/// siguen siendo locales, en su propio cajón, y no se mezclan con los de
/// ninguna cuenta.
///
/// [idsNotifier] expone las dos fuentes como un único set, así que ninguna
/// pantalla necesita saber nada de esto.
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

  static const _table = 'user_favorites';

  /// Hoy solo se favoritan negocios: el corazón existe en el detalle de
  /// negocio, en las tarjetas de Inicio y en las del mapa, en ningún otro lado.
  /// La columna acepta también `eco_activity` y `route` para cuando eso cambie.
  static const _itemType = 'business';

  /// Snapshot en memoria para que los listeners no relean el almacenamiento en cada notificación.
  final ValueNotifier<Set<String>> idsNotifier = ValueNotifier<Set<String>>(
    <String>{},
  );

  /// Clave bajo la que se hidrató [idsNotifier]; null = todavía no se hidrató.
  /// Comparar contra [_currentKey] es lo que detecta un cambio de cuenta sin
  /// necesidad de que nadie avise.
  String? _hydratedKey;

  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentUserId => AuthService().currentAuthUser?.id;

  String get _currentKey {
    final userId = _currentUserId;
    return userId == null ? _guestKey : '$_keyPrefix$userId';
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Qué id puede viajar a Postgres y cuál se queda en el dispositivo.
  static bool _isRemotable(String id) => _uuidPattern.hasMatch(id);

  Future<void> _ensureHydrated() async {
    final key = _currentKey;
    if (_hydratedKey == key) return;

    final local = await _readLocal(key);
    final userId = _currentUserId;
    if (userId == null) {
      idsNotifier.value = local;
      _hydratedKey = key;
      return;
    }

    final localOnly = local.where((id) => !_isRemotable(id)).toSet();
    final pendingUpload = local.where(_isRemotable).toSet();
    try {
      // Migración de una sola vez: lo que esta cuenta ya tenía guardado en el
      // dispositivo sube a la tabla y se retira de la copia local, así deja de
      // haber dos verdades para el mismo favorito.
      if (pendingUpload.isNotEmpty) {
        await _insertRemote(userId, pendingUpload);
        await _writeLocal(key, localOnly);
      }
      final remote = await _readRemote(userId);
      idsNotifier.value = {...localOnly, ...remote};
      _hydratedKey = key;
    } on PostgrestException catch (e) {
      // Se muestra lo que hay en el dispositivo en vez de un corazón vacío, y
      // **no** se marca como hidratado a propósito: así la próxima lectura
      // reintenta contra la red en lugar de dejar la sesión entera degradada
      // por un error puntual.
      debugPrint(
        '[FavoritesService] _ensureHydrated: no se pudo leer user_favorites '
        '(${e.code}) ${e.message} — se usan los favoritos locales.',
      );
      idsNotifier.value = local;
    }
  }

  Future<Set<String>> getFavoriteIds() async {
    await _ensureHydrated();
    return idsNotifier.value;
  }

  Future<bool> isFavorite(String id) async {
    final ids = await getFavoriteIds();
    return ids.contains(id);
  }

  /// Agrega/quita [id], persiste y actualiza [idsNotifier]; devuelve el nuevo
  /// estado.
  ///
  /// Lanza [FavoritesServiceException] si la escritura remota falla, y en ese
  /// caso **no** toca [idsNotifier]: el corazón se queda como estaba, que es lo
  /// honesto. Pintarlo lleno con la fila sin escribir haría creer que el
  /// negocio quedó guardado.
  Future<bool> toggleFavorite(String id) async {
    await _ensureHydrated();
    final updated = Set<String>.of(idsNotifier.value);
    final nowFavorite = !updated.remove(id);
    if (nowFavorite) updated.add(id);

    final userId = _currentUserId;
    if (userId != null && _isRemotable(id)) {
      try {
        if (nowFavorite) {
          await _insertRemote(userId, {id});
        } else {
          await _client
              .from(_table)
              .delete()
              .eq('user_id', userId)
              .eq('item_type', _itemType)
              .eq('item_id', id);
        }
      } on PostgrestException catch (e) {
        throw FavoritesServiceException(
          nowFavorite
              ? 'No se pudo guardar en favoritos: ${e.message}'
              : 'No se pudo quitar de favoritos: ${e.message}',
        );
      } catch (_) {
        throw const FavoritesServiceException(
          'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
        );
      }
    } else {
      await _writeLocal(
        _currentKey,
        updated.where((value) => !_isRemotable(value)).toSet(),
      );
    }

    idsNotifier.value = updated;
    return nowFavorite;
  }

  /// Cuánta gente guardó [businessId] — la métrica "Guardados por viajeros" del
  /// dashboard del dueño.
  ///
  /// Es una lectura **pública** deliberada: cuenta favoritos de todos los
  /// usuarios, no del que consulta, así que no lleva filtro de dueño (ver
  /// CLAUDE.md > Supabase & Security Guidelines). Lo que devuelve es un conteo
  /// agregado; nunca quién guardó qué.
  Future<int> countFavoritesForBusiness(String businessId) async {
    if (!_isRemotable(businessId)) return 0;
    try {
      final rows = await _client
          .from(_table)
          .select('id')
          .eq('item_type', _itemType)
          .eq('item_id', businessId);
      return (rows as List<dynamic>).length;
    } on PostgrestException catch (e) {
      throw FavoritesServiceException(
        'No se pudieron contar los guardados: ${e.message}',
      );
    } catch (_) {
      throw const FavoritesServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Descarta el snapshot en memoria para que la próxima lectura vuelva al
  /// almacenamiento. La llama [AuthService] al alternar de cuenta o cerrar
  /// sesión: sin esto los favoritos del perfil anterior se seguirían viendo
  /// hasta reiniciar la app, porque el singleton no se recrea.
  void invalidate() {
    _hydratedKey = null;
    idsNotifier.value = const <String>{};
  }

  // ==================== Almacenamiento ====================

  /// `upsert` y no `insert`: la tabla tiene un unique `(user_id, item_type,
  /// item_id)` y la migración inicial puede reenviar un favorito que ya estaba
  /// en la nube (dos dispositivos con la misma cuenta), que no es un error.
  Future<void> _insertRemote(String userId, Set<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from(_table).upsert([
      for (final id in ids)
        {'user_id': userId, 'item_type': _itemType, 'item_id': id},
    ], onConflict: 'user_id,item_type,item_id');
  }

  Future<Set<String>> _readRemote(String userId) async {
    final rows = await _client
        .from(_table)
        .select('item_id')
        .eq('user_id', userId)
        .eq('item_type', _itemType);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => row['item_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<Set<String>> _readLocal(String key) async {
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
    return (ids ?? const <String>[]).toSet();
  }

  Future<void> _writeLocal(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.toList());
  }
}
