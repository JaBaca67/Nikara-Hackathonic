import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';

class RouteServiceException implements Exception {
  const RouteServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lee y escribe `public.routes` / `public.route_stops` (ver
/// supabase/sql/011_routes.sql) — los itinerarios por días del módulo de
/// Rutas. Mismo patrón de servicio singleton que [EcoService] y
/// [BusinessStorageService].
///
/// RLS está deshabilitada en este proyecto, así que la pertenencia se
/// valida acá: [updateRoute], [replaceStops] y [deleteRoute] solo tocan
/// filas de quien tiene la sesión abierta, y [cloneRoute] exige que la ruta
/// ajena sea pública antes de copiarla.
class RouteService {
  factory RouteService() => RouteService.instance;

  RouteService._internal();

  static final RouteService instance = RouteService._internal();

  /// Sube en cada escritura de este dispositivo — `RoutesMainScreen` y el
  /// selector "Agregar a ruta" la escuchan igual que a
  /// `EcoService.revision`, así una ruta recién creada aparece sin
  /// pull-to-refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  /// PostgREST no encuentra la columna `image_urls` porque falta la
  /// migración 012. `createRoute`/`updateRoute` degradan a guardar la ruta
  /// sin fotos de portada propias en vez de fallar por completo — el
  /// collage de la tarjeta sigue funcionando con las fotos de las paradas.
  static bool _isMissingImageUrlsColumn(PostgrestException e) =>
      e.code == 'PGRST204' || e.code == '42703';

  // `profiles(id, full_name)` embebe por `routes.owner_id -> profiles.id`
  // (la misma FK desde 011_routes.sql, no hace falta ninguna migración
  // nueva para esto) — quién creó la ruta, para la cabecera de la pestaña
  // Comunidad. Se pide siempre y no solo en [getPublicRoutes]: es un embed
  // liviano y así una ruta propia recién vuelta a cargar también trae el
  // nombre, sin duplicar la constante de select.
  static const _select = '*, route_stops(*), profiles(id, full_name)';

  /// Las rutas de la cuenta con sesión abierta, la más reciente primero.
  /// Lista vacía para un invitado: una ruta necesita `owner_id`.
  Future<List<RouteModel>> getMyRoutes() async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('routes')
          .select(_select)
          .eq('owner_id', userId)
          .order('created_at', ascending: false);
      return _mapRows(rows);
    } on PostgrestException catch (e) {
      // 42P01 = la tabla no existe todavía (migración 011 sin correr).
      if (e.code == '42P01') {
        throw const RouteServiceException(
          'Falta correr la migración de rutas en Supabase '
          '(supabase/sql/011_routes.sql).',
        );
      }
      throw RouteServiceException(
        'No se pudieron cargar tus rutas: ${e.message}',
      );
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Rutas que otras personas publicaron en la comunidad — las que se
  /// pueden abrir y copiar. Excluye las propias: esas ya salen en
  /// [getMyRoutes].
  Future<List<RouteModel>> getPublicRoutes() async {
    try {
      final userId = AuthService().currentAuthUser?.id;
      var query = _client.from('routes').select(_select).eq('is_public', true);
      if (userId != null) query = query.neq('owner_id', userId);
      final rows = await query.order('created_at', ascending: false);
      return _mapRows(rows);
    } on PostgrestException catch (e) {
      throw RouteServiceException(
        'No se pudieron cargar las rutas de la comunidad: ${e.message}',
      );
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<RouteModel?> getRouteById(String id) async {
    try {
      final row = await _client
          .from('routes')
          .select(_select)
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : RouteModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw RouteServiceException('No se pudo cargar la ruta: ${e.message}');
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Alta desde el wizard: inserta la ruta y sus paradas ya renumeradas.
  Future<RouteModel> createRoute({
    required String title,
    required int days,
    required bool isPublic,
    List<RouteStopModel> stops = const [],
    List<String> imageUrls = const [],
    String? clonedFromRouteId,
  }) async {
    final userId = _requireUserId(
      'Necesitas iniciar sesión para crear una ruta.',
    );
    try {
      final row = await _insertRoute(
        userId: userId,
        title: title,
        days: days,
        isPublic: isPublic,
        imageUrls: imageUrls,
        clonedFromRouteId: clonedFromRouteId,
      );
      final routeId = row['id'] as String;
      final saved = await _insertStops(routeId, stops);
      revision.value++;
      return RouteModel.fromRow(row).copyWith(stops: saved);
    } on PostgrestException catch (e) {
      throw RouteServiceException('No se pudo guardar la ruta: ${e.message}');
    } on RouteServiceException {
      rethrow;
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<Map<String, dynamic>> _insertRoute({
    required String userId,
    required String title,
    required int days,
    required bool isPublic,
    required List<String> imageUrls,
    String? clonedFromRouteId,
  }) async {
    final payload = {
      'owner_id': userId,
      'title': title,
      'days': days,
      'is_public': isPublic,
      'image_urls': imageUrls,
      'cloned_from_route_id': ?clonedFromRouteId,
    };
    try {
      return await _client.from('routes').insert(payload).select().single();
    } on PostgrestException catch (e) {
      if (!_isMissingImageUrlsColumn(e)) rethrow;
      return await _client
          .from('routes')
          .insert({...payload}..remove('image_urls'))
          .select()
          .single();
    }
  }

  /// Cambia los datos de cabecera de una ruta propia. Al reducir [days], el
  /// llamador tiene que haber reubicado antes las paradas que quedaban en
  /// los días eliminados (ver `RouteModel.reindex` y el paso 3 del wizard).
  Future<void> updateRoute(
    String routeId, {
    String? title,
    int? days,
    bool? isPublic,
    RouteStatus? status,
    List<String>? imageUrls,
  }) async {
    final userId = _requireUserId(
      'Necesitas iniciar sesión para editar una ruta.',
    );
    final changes = <String, dynamic>{
      'title': ?title,
      'days': ?days,
      'is_public': ?isPublic,
      'status': ?status?.name,
      'image_urls': ?imageUrls,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      // El filtro por dueño es la validación de pertenencia: sin RLS, es
      // lo que impide editar la ruta de otra persona.
      await _updateRoute(routeId, userId, changes);
      revision.value++;
    } on PostgrestException catch (e) {
      throw RouteServiceException(
        'No se pudieron guardar los cambios: ${e.message}',
      );
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<void> _updateRoute(
    String routeId,
    String userId,
    Map<String, dynamic> changes,
  ) async {
    try {
      await _client
          .from('routes')
          .update(changes)
          .eq('id', routeId)
          .eq('owner_id', userId);
    } on PostgrestException catch (e) {
      if (!_isMissingImageUrlsColumn(e) || !changes.containsKey('image_urls')) {
        rethrow;
      }
      await _client
          .from('routes')
          .update({...changes}..remove('image_urls'))
          .eq('id', routeId)
          .eq('owner_id', userId);
    }
  }

  /// Reemplaza todas las paradas de una ruta propia por [stops].
  ///
  /// Borra e inserta en vez de hacer un diff: el paso 3 puede haber movido,
  /// quitado y reordenado varias paradas a la vez, y "así queda la ruta" es
  /// mucho más simple de razonar (y de mantener consistente) que una lista
  /// de altas/bajas/updates de posición.
  Future<List<RouteStopModel>> replaceStops(
    String routeId,
    List<RouteStopModel> stops,
  ) async {
    final userId = _requireUserId(
      'Necesitas iniciar sesión para editar una ruta.',
    );
    try {
      await _assertOwnership(routeId, userId);
      await _client.from('route_stops').delete().eq('route_id', routeId);
      final saved = await _insertStops(routeId, stops);
      revision.value++;
      return saved;
    } on PostgrestException catch (e) {
      throw RouteServiceException(
        'No se pudieron guardar las paradas: ${e.message}',
      );
    } on RouteServiceException {
      rethrow;
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// "Agregar a ruta" desde el detalle de un negocio o de una jornada ECO:
  /// suma [stop] al final del día [dayNumber] de una ruta que ya existe.
  Future<void> addStop(
    String routeId,
    RouteStopModel stop, {
    int dayNumber = 1,
  }) async {
    final userId = _requireUserId(
      'Necesitas iniciar sesión para agregar paradas.',
    );
    try {
      final route = await _assertOwnership(routeId, userId);
      final day = dayNumber.clamp(1, route.days);
      final existing = route.stopsForDay(day);
      if (existing.any((s) => s.sourceKey == stop.sourceKey)) {
        throw const RouteServiceException(
          'Este lugar ya está en ese día de la ruta.',
        );
      }
      await _insertStops(routeId, [
        stop.copyWith(dayNumber: day, position: existing.length),
      ]);
      revision.value++;
    } on PostgrestException catch (e) {
      throw RouteServiceException('No se pudo agregar la parada: ${e.message}');
    } on RouteServiceException {
      rethrow;
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// "Copiar / Usar esta ruta" — duplica el itinerario completo (cabecera y
  /// paradas) en la cuenta de quien está usando la app, para que lo edite a
  /// su gusto sin tocar el original.
  ///
  /// La copia nace privada aunque el original sea público: republicarla es
  /// una decisión de quien la copió, no algo que se hereda. Una ruta ajena
  /// solo se puede copiar si es pública; la propia siempre (es el
  /// "Duplicar" del menú de la pantalla de detalle).
  Future<RouteModel> cloneRoute(RouteModel source) async {
    final userId = _requireUserId(
      'Necesitas iniciar sesión para copiar una ruta.',
    );
    if (!source.isOwnedBy(userId) && !source.isPublic) {
      throw const RouteServiceException(
        'Esta ruta es privada, no se puede copiar.',
      );
    }
    // Se releen las paradas del original en vez de confiar en las que traía
    // el modelo en memoria: quien lo abrió pudo llegar desde una tarjeta
    // vieja y la copia tiene que ser del itinerario tal como está hoy.
    final fresh = await getRouteById(source.id) ?? source;
    return createRoute(
      title: source.isOwnedBy(userId) ? '${fresh.title} (copia)' : fresh.title,
      days: fresh.days,
      isPublic: false,
      stops: fresh.stops,
      // Las fotos de portada se mantienen tal cual en la copia — son la
      // identidad visual de la ruta, no algo ligado a quién la publicó.
      imageUrls: fresh.imageUrls,
      clonedFromRouteId: fresh.id,
    );
  }

  Future<void> deleteRoute(String routeId) async {
    final userId = _requireUserId(
      'Necesitas iniciar sesión para eliminar una ruta.',
    );
    try {
      // route_stops cae solo por el `on delete cascade` de la FK.
      await _client
          .from('routes')
          .delete()
          .eq('id', routeId)
          .eq('owner_id', userId);
      revision.value++;
    } on PostgrestException catch (e) {
      throw RouteServiceException('No se pudo eliminar la ruta: ${e.message}');
    } catch (_) {
      throw const RouteServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<List<RouteStopModel>> _insertStops(
    String routeId,
    List<RouteStopModel> stops,
  ) async {
    if (stops.isEmpty) return const [];
    final payload = [
      for (final stop in RouteModel.reindex(stops))
        {...stop.toInsert(), 'route_id': routeId},
    ];
    final rows = await _client.from('route_stops').insert(payload).select();
    return RouteModel.sortStops(
      (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RouteStopModel.fromRow)
          .toList(),
    );
  }

  /// Trae la ruta y confirma que [userId] es su dueño — el chequeo que
  /// reemplaza a las políticas RLS que este proyecto no usa.
  Future<RouteModel> _assertOwnership(String routeId, String userId) async {
    final route = await getRouteById(routeId);
    if (route == null) {
      throw const RouteServiceException('Esa ruta ya no existe.');
    }
    if (!route.isOwnedBy(userId)) {
      throw const RouteServiceException('Esta ruta no es tuya.');
    }
    return route;
  }

  String _requireUserId(String message) {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) throw RouteServiceException(message);
    return userId;
  }

  List<RouteModel> _mapRows(dynamic rows) => (rows as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(RouteModel.fromRow)
      .toList(growable: false);
}
