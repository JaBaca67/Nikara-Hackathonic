import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/utils/image_upload.dart';
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
  static const _participantsEmbed =
      'eco_participants(user_id, joined_at, '
      'profiles(id, full_name, avatar_url))';

  static const _selectWithOrganization =
      '*, $_participantsEmbed, '
      'organizations(id, name, handle, logo_url, is_verified)';

  /// Select degradado para proyectos con migraciones pendientes: sin el embed
  /// de `organizations` (010) y sin el de `profiles` anidado en los
  /// participantes, que depende de que 013 haya reapuntado
  /// `eco_participants.user_id` a `public.profiles`.
  static const _selectWithoutOrganization =
      '*, eco_participants(user_id, joined_at)';

  /// PostgREST no encuentra la relación (PGRST200) o la columna
  /// (42703/42P01) porque falta la migración 010. En vez de romper todo el
  /// módulo ECO por una migración pendiente, quien llama repite la consulta
  /// sin el embed y sigue mostrando las jornadas como antes.
  static bool _isMissingEmbed(PostgrestException e) =>
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
      if (_isMissingEmbed(e)) {
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
      if (_isMissingEmbed(e)) {
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

  /// Inscritos con nombre y foto en un solo viaje: `eco_participants.user_id`
  /// apunta a `public.profiles(id)` desde 013, así que el perfil se embebe en
  /// vez de resolverse con una consulta por persona.
  Future<List<EcoParticipant>> getParticipants(String activityId) async {
    try {
      return await _runParticipantsSelect(
        activityId,
        'user_id, joined_at, profiles(id, full_name, avatar_url)',
      );
    } on PostgrestException catch (e) {
      if (_isMissingEmbed(e)) {
        return _runParticipantsSelect(activityId, 'user_id, joined_at');
      }
      throw EcoServiceException(
        'No se pudieron cargar los participantes: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<List<EcoParticipant>> _runParticipantsSelect(
    String activityId,
    String select,
  ) async {
    final rows = await _client
        .from('eco_participants')
        .select(select)
        .eq('activity_id', activityId)
        .order('joined_at');
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(EcoParticipant.fromRow)
        .toList(growable: false);
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

  /// Bucket público de Supabase Storage con las portadas de las jornadas (ver supabase/sql/014_eco_activity_image.sql).
  static const imageBucket = 'eco_activities';

  /// Sube la portada elegida con `image_picker` y devuelve su URL pública, la
  /// que se guarda tal cual en `eco_activities.image_url`.
  ///
  /// La ruta es `<user_id>/<uuid>.<ext>` porque las políticas de
  /// `storage.objects` de la migración 014 usan el primer segmento como dueño
  /// del archivo. Se leen bytes (`readAsBytes`) y no un `File` para que el
  /// mismo código funcione en web, donde `XFile.path` es un `blob:`.
  Future<String> uploadActivityImage(XFile image) async {
    final user = AuthService().currentAuthUser;
    if (user == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para subir una imagen.',
      );
    }

    final format = resolveImageUploadFormat(
      image.name,
      reportedMimeType: image.mimeType,
    );
    final objectPath = '${user.id}/${const Uuid().v4()}.${format.extension}';
    try {
      final bytes = await image.readAsBytes();
      await _client.storage
          .from(imageBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: format.mimeType,
              upsert: false,
            ),
          );
      return _client.storage.from(imageBucket).getPublicUrl(objectPath);
    } on StorageException catch (e) {
      // 404 aquí siempre es "el bucket no existe": la ruta del objeto la
      // acabamos de generar, así que no puede ser un archivo faltante.
      if (e.statusCode == '404') {
        throw const EcoServiceException(
          'Falta crear el almacenamiento de imágenes ECO. Corre '
          'supabase/sql/014_eco_activity_image.sql en Supabase.',
        );
      }
      throw EcoServiceException('No se pudo subir la imagen: ${e.message}');
    } catch (_) {
      throw const EcoServiceException(
        'No se pudo subir la imagen. Verifica tu internet e intenta de nuevo.',
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
    String? imageUrl,
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
        // Se omite la clave si es null para que funcione sin la migración 014.
        'image_url': ?imageUrl,
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
      // PGRST204 = PostgREST no conoce `image_url` porque falta la migración
      // 014; se distingue del error genérico para decir exactamente qué correr.
      if (e.code == 'PGRST204' && imageUrl != null) {
        throw const EcoServiceException(
          'Falta la columna image_url. Corre '
          'supabase/sql/014_eco_activity_image.sql en Supabase y vuelve a '
          'publicar.',
        );
      }
      throw EcoServiceException(
        'No se pudo guardar la actividad: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Las jornadas que organiza el usuario actual, incluidas las publicadas en
  /// nombre de una fundación (el `organizer_id` sigue siendo quien las creó).
  /// Alimenta el apartado "Mis actividades ECO" del perfil.
  ///
  /// Ordena por `start_time` descendente, al revés que el feed: acá lo útil es
  /// tener arriba lo último que publicaste para editarlo, no lo más próximo.
  Future<List<EcoActivityModel>> getMyActivities() async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return const [];
    try {
      return await _runMineSelect(userId, _selectWithOrganization);
    } on PostgrestException catch (e) {
      if (_isMissingEmbed(e)) {
        return _runMineSelect(userId, _selectWithoutOrganization);
      }
      throw EcoServiceException(
        'No se pudieron cargar tus actividades: ${e.message}',
      );
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<List<EcoActivityModel>> _runMineSelect(
    String userId,
    String select,
  ) async {
    final rows = await _client
        .from('eco_activities')
        .select(select)
        .eq('organizer_id', userId)
        .order('start_time', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => EcoActivityModel.fromRow(row, currentUserId: userId))
        .toList(growable: false);
  }

  /// RLS está deshabilitada en `eco_activities` (ver 009), así que la
  /// pertenencia se valida acá en Dart — mismo criterio que el resto del
  /// esquema. Sin este chequeo cualquier cliente podría editar la jornada de
  /// otra persona conociendo su id.
  Future<void> _assertOwnership(String activityId) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const EcoServiceException(
        'Necesitas iniciar sesión para gestionar tus actividades.',
      );
    }
    final row = await _client
        .from('eco_activities')
        .select('organizer_id')
        .eq('id', activityId)
        .maybeSingle();
    if (row == null) {
      throw const EcoServiceException('Esa actividad ya no existe.');
    }
    if (row['organizer_id'] != userId) {
      throw const EcoServiceException(
        'Solo quien creó la actividad puede modificarla.',
      );
    }
  }

  /// Contraparte de [createActivity] para editar. [imageUrl] con valor
  /// reemplaza la portada, `null` la deja como está y [removeImage] la borra —
  /// tres estados que un solo parámetro nullable no puede distinguir.
  Future<void> updateActivity({
    required String id,
    required String title,
    required String description,
    required String category,
    required String location,
    double? latitude,
    double? longitude,
    String? imageUrl,
    bool removeImage = false,
    required DateTime startTime,
    int? maxCapacity,
    List<String> requirements = const [],
    String? organizationId,
    bool clearOrganization = false,
  }) async {
    try {
      await _assertOwnership(id);
      final patch = <String, dynamic>{
        'title': title,
        'description': description,
        'category': category,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'start_time': startTime.toUtc().toIso8601String(),
        'max_capacity': maxCapacity,
        'requirements': requirements,
      };
      if (removeImage) {
        patch['image_url'] = null;
      } else if (imageUrl != null) {
        patch['image_url'] = imageUrl;
      }
      // Igual que en createActivity: la clave se omite si no hay nada que
      // cambiar, para no romper en proyectos sin la migración 010.
      if (clearOrganization) {
        patch['organization_id'] = null;
      } else if (organizationId != null) {
        patch['organization_id'] = organizationId;
      }

      await _client.from('eco_activities').update(patch).eq('id', id);
      revision.value++;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' && (removeImage || imageUrl != null)) {
        throw const EcoServiceException(
          'Falta la columna image_url. Corre '
          'supabase/sql/014_eco_activity_image.sql en Supabase y vuelve a '
          'guardar.',
        );
      }
      throw EcoServiceException(
        'No se pudo actualizar la actividad: ${e.message}',
      );
    } on EcoServiceException {
      rethrow;
    } catch (_) {
      throw const EcoServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// `eco_participants` cae solo por el `on delete cascade` de 009.
  Future<void> deleteActivity(String id) async {
    try {
      await _assertOwnership(id);
      await _client.from('eco_activities').delete().eq('id', id);
      revision.value++;
    } on PostgrestException catch (e) {
      throw EcoServiceException(
        'No se pudo eliminar la actividad: ${e.message}',
      );
    } on EcoServiceException {
      rethrow;
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
