import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';

class EcoServiceException implements Exception {
  const EcoServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persiste [EcoActivityModel] en `eco_activities`/`eco_participants` (supabase/sql/009_eco_activities.sql); mismo patrón singleton que [BusinessStorageService].
class EcoService {
  factory EcoService() => EcoService.instance;

  EcoService._internal();

  static final EcoService instance = EcoService._internal();

  /// Se incrementa en cada escritura local para que las pantallas se refresquen sin pull-to-refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  /// Lo que pide cada consulta de actividades: la fila, sus participantes
  /// embebidos y, si la jornada se publicó en nombre de una fundación, los
  /// datos de esa fundación para el bloque "Organizador" — todo en un solo
  /// viaje en vez de una consulta por actividad.
  static const _selectWithOrganization =
      '*, eco_participants(user_id, joined_at), '
      'organizations(id, name, handle, logo_url, is_verified)';

  /// El mismo select sin el embed de `organizations`, para proyectos donde
  /// supabase/sql/010_organizations.sql todavía no corrió (ver [_isMissingOrganizations]).
  static const _selectWithoutOrganization =
      '*, eco_participants(user_id, joined_at)';

  /// PostgREST no encuentra la relación (PGRST200) o la columna
  /// (42703/42P01) porque falta la migración 010. En vez de romper todo el
  /// módulo ECO por una migración pendiente, quien llama repite la consulta
  /// sin el embed y sigue mostrando las jornadas como antes.
  static bool _isMissingOrganizations(PostgrestException e) =>
      e.code == 'PGRST200' || e.code == '42703' || e.code == '42P01';

  /// Ordena por `start_time` ascendente ("lo próximo primero"), no descendente.
  Future<List<EcoActivityModel>> getUpcomingActivities() async {
    return _select(pastOnly: false);
  }

  /// Separado de [getUpcomingActivities] para no filtrar/ordenar una lista mixta en el cliente.
  Future<List<EcoActivityModel>> getPastActivities() async {
    return _select(pastOnly: true);
  }

  /// Todas las jornadas de una fundación, la más próxima primero — el
  /// listado del perfil público de la organización.
  Future<List<EcoActivityModel>> getActivitiesByOrganization(
    String organizationId,
  ) async {
    return _select(organizationId: organizationId);
  }

  /// Las jornadas que una persona publicó a título personal (sin
  /// `organization_id`) — el listado de su perfil público.
  Future<List<EcoActivityModel>> getPersonalActivitiesByOrganizer(
    String organizerId,
  ) async {
    return _select(personalOrganizerId: organizerId);
  }

  Future<List<EcoActivityModel>> _select({
    bool? pastOnly,
    String? organizationId,
    String? personalOrganizerId,
  }) async {
    try {
      return await _runSelect(
        select: _selectWithOrganization,
        pastOnly: pastOnly,
        organizationId: organizationId,
        personalOrganizerId: personalOrganizerId,
      );
    } on PostgrestException catch (e) {
      if (_isMissingOrganizations(e)) {
        // Migración 010 pendiente: filtrar por fundación no puede devolver
        // nada todavía, y el resto de las consultas se sirve sin el embed.
        if (organizationId != null) return const [];
        return _runSelect(
          select: _selectWithoutOrganization,
          pastOnly: pastOnly,
          personalOrganizerId: personalOrganizerId,
          skipOrganizationFilter: true,
        );
      }
      throw EcoServiceException(
        'No se pudieron cargar las actividades: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// El embed anidado de eco_participants trae la lista completa en un solo viaje, en vez de una consulta por actividad.
  Future<List<EcoActivityModel>> _runSelect({
    required String select,
    bool? pastOnly,
    String? organizationId,
    String? personalOrganizerId,
    bool skipOrganizationFilter = false,
  }) async {
    var query = _client.from('eco_activities').select(select);
    if (pastOnly != null) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      query = pastOnly
          ? query.lt('start_time', nowIso)
          : query.gte('start_time', nowIso);
    }
    if (organizationId != null) {
      query = query.eq('organization_id', organizationId);
    }
    if (personalOrganizerId != null) {
      query = query.eq('organizer_id', personalOrganizerId);
      if (!skipOrganizationFilter) {
        query = query.isFilter('organization_id', null);
      }
    }
    final rows = await query.order('start_time', ascending: pastOnly != true);
    final currentUserId = AuthService().currentAuthUser?.id;
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => EcoActivityModel.fromRow(row, currentUserId: currentUserId),
        )
        .toList(growable: false);
  }

  Future<EcoActivityModel?> getActivityById(String id) async {
    try {
      return await _getActivityById(id, select: _selectWithOrganization);
    } on PostgrestException catch (e) {
      if (_isMissingOrganizations(e)) {
        return _getActivityById(id, select: _selectWithoutOrganization);
      }
      throw EcoServiceException('No se pudo cargar la actividad: ${e.message}');
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<EcoActivityModel?> _getActivityById(
    String id, {
    required String select,
  }) async {
    final row = await _client
        .from('eco_activities')
        .select(select)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return EcoActivityModel.fromRow(
      row,
      currentUserId: AuthService().currentAuthUser?.id,
    );
  }

  /// `profiles` no es embebible aquí (sin FK directa a `eco_participants`, ambos apuntan a `auth.users`): los nombres se resuelven aparte vía `AuthService.getProfileById`.
  Future<List<({String userId, DateTime joinedAt})>> getParticipants(
    String activityId,
  ) async {
    try {
      final rows = await _client
          .from('eco_participants')
          .select('user_id, joined_at')
          .eq('activity_id', activityId)
          .order('joined_at');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (row) => (
              userId: row['user_id'] as String,
              joinedAt: DateTime.parse(row['joined_at'] as String),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudieron cargar los participantes: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// "Unirme": se asume que quien llama ya validó con [GuestGuard.allow] (un invitado no tiene id para insertar).
  Future<void> joinActivity(String activityId) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para unirte a una actividad.',
      );
    }
    try {
      await _client.from('eco_participants').insert({
        'activity_id': activityId,
        'user_id': userId,
      });
      revision.value++;
    } on PostgrestException catch (e) {
      // Violación de unicidad = ya estaba inscrito, no es un error real desde su perspectiva.
      if (e.code == '23505') {
        throw const EcoServiceException(
          'Ya estás participando en esta actividad.',
        );
      }
      throw EcoServiceException(
        'No se pudo completar la inscripción: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// "Abandonar actividad".
  Future<void> leaveActivity(String activityId) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para gestionar tus actividades.',
      );
    }
    try {
      await _client
          .from('eco_participants')
          .delete()
          .eq('activity_id', activityId)
          .eq('user_id', userId);
      revision.value++;
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudo abandonar la actividad: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// El cliente nunca envía `organizer_verified` (default `false`, igual que `BusinessModel.isVerified`); [organizationId] nulo publica a título personal, con valor publica en nombre de esa fundación (badge sale de `organizations.is_verified`).
  Future<void> createActivity({
    required String title,
    required String description,
    required String category,
    required String location,
    double? latitude,
    double? longitude,
    required DateTime startTime,
    int? maxCapacity,
    List<String> requirements = const [],
    String? organizationId,
  }) async {
    final user = AuthService().currentAuthUser;
    if (user == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para registrar una actividad.',
      );
    }
    try {
      final profile = await AuthService().getCurrentProfile();
      await _client.from('eco_activities').insert({
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'start_time': startTime.toUtc().toIso8601String(),
        'max_capacity': maxCapacity,
        'organizer_id': user.id,
        'organizer_name': profile?.fullName,
        'requirements': requirements,
        // Se omite la clave si es null para que funcione sin la migración 010.
        'organization_id': ?organizationId,
      });
      revision.value++;
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudo guardar la actividad: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Cubre cambios de otros dispositivos ([revision] solo cubre los propios); si Realtime no está habilitado, simplemente no llegan eventos y la app sigue funcionando con sus fetches normales.
  Future<void> Function() subscribeToChanges(VoidCallback onChange) {
    final channel = _client
        .channel('public:eco_activities_and_participants')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eco_activities',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eco_participants',
          callback: (_) => onChange(),
        )
        .subscribe();
    return () => _client.removeChannel(channel);
  }
}
