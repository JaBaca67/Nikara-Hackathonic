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

  /// Copia local, **por usuario**, de lo último que se leyó bien de
  /// `user_favorites`. Sirve solo para pintar los corazones cuando la lectura
  /// remota falla (sin internet, sesión sin refrescar).
  ///
  /// Va en una clave distinta de `favorite_ids_<id>` a propósito: esa lista es
  /// la de "solo locales + pendientes de subir", y la hidratación sube a la
  /// tabla todo uuid que encuentre ahí. Si la copia viviera en esa clave, un
  /// favorito quitado desde otro dispositivo se volvería a subir y
  /// reaparecería.
  static const _cachePrefix = 'favorite_cache_';

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

  /// Mensaje único cuando no se pudo leer el set (red caída, Supabase con
  /// error): lo usan [getFavoriteIds] y quien llame a [preload].
  static const loadFailedMessage =
      'No se pudieron cargar tus favoritos. Verifica tu internet e intenta de '
      'nuevo.';

  /// Mensaje de [toggleFavorite] cuando el cambio no pudo llegar al servidor
  /// por falta de conexión.
  static const offlineToggleMessage =
      'Sin conexión. No se pudo actualizar tu favorito.';

  /// Cuántas veces se llamó a [preload]; solo para que los tests comprueben
  /// que el "Reintentar" de una pantalla vuelve a pedir la carga.
  @visibleForTesting
  int preloadCallCount = 0;

  /// Lectura en curso, para que dos pantallas que piden favoritos a la vez
  /// (p. ej. Inicio y Perfil al arrancar) compartan una sola consulta en vez
  /// de subir y leer dos veces. [_hydratingKey] dice a qué cuenta pertenece.
  Future<bool>? _hydrating;
  String? _hydratingKey;

  /// Sube con cada [invalidate]. Una lectura que empezó antes de un cambio de
  /// cuenta compara su número al terminar y, si no coincide, descarta su
  /// resultado: sin esto podía llegar tarde y pisar los favoritos de la cuenta
  /// nueva con los de la anterior.
  int _generation = 0;

  /// Carga el set de la cuenta activa si todavía no está cargado.
  ///
  /// Devuelve `false` si no se pudo leer la tabla (el notifier queda con lo
  /// que hay en el dispositivo y **no** se marca como hidratado, así la próxima
  /// lectura reintenta). Nunca lanza.
  Future<bool> _ensureHydrated() {
    final key = _currentKey;
    if (_hydratedKey == key) return Future<bool>.value(true);
    final inFlight = _hydrating;
    if (inFlight != null && _hydratingKey == key) return inFlight;

    late final Future<bool> future;
    future = _hydrate(key, _generation).whenComplete(() {
      if (identical(_hydrating, future)) _hydrating = null;
    });
    _hydrating = future;
    _hydratingKey = key;
    return future;
  }

  /// Publica [ids] solo si cambian. Importa por Perfil: escucha
  /// [idsNotifier] y recarga entera con cada aviso, que vuelve a pedir los
  /// favoritos. Con la red caída cada lectura fallida publicaba un `Set`
  /// nuevo —distinto por identidad aunque tuviera lo mismo— y eso reiniciaba
  /// el ciclo sin fin.
  void _publish(Set<String> ids) {
    if (setEquals(idsNotifier.value, ids)) return;
    idsNotifier.value = ids;
  }

  Future<bool> _hydrate(String key, int generation) async {
    // La sesión cambió (cuenta nueva o cierre de sesión) mientras se leía: el
    // resultado ya no es de esta cuenta y no debe aplicarse.
    bool stale() => generation != _generation || key != _currentKey;

    final Set<String> local;
    try {
      local = await _readLocal(key);
    } on Exception catch (e) {
      debugPrint('[FavoritesService] no se pudo leer el almacenamiento: $e');
      return false;
    }
    final userId = _currentUserId;
    if (userId == null) {
      if (!stale()) {
        _publish(local);
        _hydratedKey = key;
      }
      return true;
    }

    final localOnly = local.where((id) => !_isRemotable(id)).toSet();
    final pendingUpload = local.where(_isRemotable).toSet();

    // Lo último que se leyó bien de esta cuenta se pinta ya, mientras se
    // consulta al servidor: con la red caída, `postgrest` reintenta la lectura
    // con esperas crecientes (unos 7 s) antes de rendirse, y los corazones no
    // deben quedar vacíos todo ese rato. Si la consulta funciona, lo que diga
    // el servidor reemplaza esto; no cuenta como "cargado".
    final cached = await _readCache(userId);
    if (!stale()) _publish({...local, ...cached});

    final Set<String> remote;
    try {
      // Migración de una sola vez: lo que esta cuenta ya tenía guardado en el
      // dispositivo sube a la tabla y se retira de la copia local, así deja de
      // haber dos verdades para el mismo favorito.
      if (pendingUpload.isNotEmpty) {
        await _insertRemote(userId, pendingUpload);
        await _writeLocal(key, localOnly);
      }
      remote = await _readRemote(userId);
    } on Exception catch (e) {
      // Cualquier fallo (Postgrest, red caída, timeout), no solo los de la
      // base: se pinta lo último que se leyó bien de esta cuenta (la copia) en
      // vez de un corazón vacío, y **no** se marca como hidratado a propósito
      // para que la próxima lectura vuelva a consultar al servidor en lugar de
      // dejar la sesión entera degradada por un error puntual.
      debugPrint(
        '[FavoritesService] no se pudo leer user_favorites: $e — se usa la '
        'copia local.',
      );
      if (!stale()) _publish({...local, ...cached});
      return false;
    }

    // La copia se reemplaza con lo que dice el servidor, aunque la sesión haya
    // cambiado mientras tanto: sigue siendo de `userId`.
    await _writeCache(userId, remote);
    if (!stale()) {
      _publish({...localOnly, ...remote});
      _hydratedKey = key;
    }
    return true;
  }

  /// Carga los favoritos de la cuenta activa **sin esperar a que alguna
  /// pantalla los pida**. Inicio y Mapa solo escuchan [idsNotifier]; si nadie
  /// lo llena, los corazones salen vacíos hasta que se abre Perfil. Se llama
  /// al aparecer la app (`MainLayout`), así que también corre tras iniciar
  /// sesión o cambiar de cuenta, que recrean esa pantalla.
  ///
  /// Devuelve `true` si quedaron cargados y `false` si falló; nunca lanza.
  Future<bool> preload() async {
    preloadCallCount++;
    try {
      return await _ensureHydrated();
    } on Exception catch (e) {
      debugPrint('[FavoritesService] preload falló: $e');
      return false;
    }
  }

  /// Lanza [FavoritesServiceException] (mensaje en español) si no se pudo
  /// leer la tabla, para que quien muestra el listado —Perfil— enseñe su
  /// estado de error en vez de un listado incompleto.
  Future<Set<String>> getFavoriteIds() async {
    final loaded = await _ensureHydrated();
    if (!loaded) throw const FavoritesServiceException(loadFailedMessage);
    return idsNotifier.value;
  }

  /// A diferencia de [getFavoriteIds] no lanza si la lectura falla: responde
  /// con lo que haya en el dispositivo, porque quien pregunta solo pinta un
  /// corazón y no vale romper el detalle de un negocio por eso.
  Future<bool> isFavorite(String id) async {
    await _ensureHydrated();
    return idsNotifier.value.contains(id);
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
      } on PostgrestException {
        // El texto de Postgrest viene en inglés y habla de la base de datos.
        throw FavoritesServiceException(
          nowFavorite
              ? 'No se pudo guardar en favoritos. Intenta de nuevo en un '
                    'momento.'
              : 'No se pudo quitar de favoritos. Intenta de nuevo en un '
                    'momento.',
        );
      } catch (_) {
        // Sin red no se finge: el cambio no llegó al servidor, así que el
        // corazón no se mueve. (No hay cola de cambios pendientes a propósito.)
        throw const FavoritesServiceException(offlineToggleMessage);
      }
      // Lo que se acaba de escribir también va a la copia, para que un
      // arranque sin internet no la deje atrasada respecto de este cambio.
      await _writeCache(userId, updated);
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
    } on PostgrestException {
      throw const FavoritesServiceException(
        'No se pudieron contar los guardados. Intenta de nuevo en un momento.',
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
    _generation++;
    _hydratedKey = null;
    _hydrating = null;
    _hydratingKey = null;
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

  /// Copia de lo último leído bien del servidor para [userId]. Nunca lanza:
  /// es un respaldo, y si no se puede leer simplemente no hay copia.
  Future<Set<String>> _readCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList('$_cachePrefix$userId') ?? const <String>[])
          .where(_isRemotable)
          .toSet();
    } on Exception catch (e) {
      debugPrint('[FavoritesService] no se pudo leer la copia local: $e');
      return const <String>{};
    }
  }

  /// Reemplaza la copia de [userId] por [ids] (solo los uuid: los slugs ya
  /// viven en su propia clave). Nunca lanza: un respaldo que no se pudo
  /// guardar no debe romper una lectura que sí funcionó.
  Future<void> _writeCache(String userId, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '$_cachePrefix$userId',
        ids.where(_isRemotable).toList(),
      );
    } on Exception catch (e) {
      debugPrint('[FavoritesService] no se pudo guardar la copia local: $e');
    }
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
