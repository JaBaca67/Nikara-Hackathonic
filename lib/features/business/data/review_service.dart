import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/utils/image_upload.dart';
import 'package:nikara_app/core/utils/input_sanitizers.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/eco/data/eco_moment_service.dart';

class ReviewServiceException implements Exception {
  const ReviewServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Promedio y cantidad de reseñas de un negocio — lo que el dashboard del dueño
/// muestra como "Calificación · N reseñas".
class RatingSummary {
  const RatingSummary({required this.average, required this.count});

  static const empty = RatingSummary(average: 0, count: 0);

  final double average;
  final int count;

  bool get isEmpty => count == 0;
}

/// Lee y escribe la tabla `reviews`
/// (supabase/sql/013_final_schema_additions.sql); mismo patrón singleton que
/// [AuthService]/`EcoService`.
///
/// Hasta ahora las reseñas vivían **solo** en el cache de
/// `SharedPreferences` de `BusinessStorageService`, así que existían nada más
/// que en el dispositivo de quien las escribió: nadie más las veía y el dueño
/// del negocio no tenía forma de saber cómo lo estaban calificando. Este
/// servicio es lo que las vuelve un dato real y compartido.
///
/// `target_type` ya admitía `'eco_activity'` desde la 013, pero este servicio
/// lo tenía fijo a `'business'` — [getForEcoActivity]/[addReview] (con
/// `targetType: ecoActivityTargetType`) es lo que lo habilita de verdad, para
/// "Momentos" en `EcoDetailScreen`.
///
/// `media_urls` (migración 040) es lo que [addReview] usa para persistir las
/// fotos que antes se perdían por completo — ver la nota en esa migración.
class ReviewService {
  factory ReviewService() => instance;

  ReviewService._internal();

  static final ReviewService instance = ReviewService._internal();

  /// Sube en cada escritura para que las pantallas se refresquen sin
  /// pull-to-refresh, igual que `BusinessStorageService.revision`.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const _table = 'reviews';

  /// Bucket público de Storage para las fotos adjuntas a una reseña/momento
  /// (supabase/sql/040_review_media_and_eco_target.sql).
  static const mediaBucket = 'reviews';

  /// `reviews.target_id` apunta a `businesses.id` o a `eco_activities.id`
  /// según `target_type`.
  static const businessTargetType = 'business';
  static const ecoActivityTargetType = 'eco_activity';

  SupabaseClient get _client => Supabase.instance.client;

  /// Complementa `revision` con reseñas escritas en otros dispositivos.
  Future<void> Function() subscribeToChanges(VoidCallback onChange) {
    final channel = _client
        .channel('map:reviews')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (_) => onChange(),
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) onChange();
        });
    return () => _client.removeChannel(channel);
  }

  /// El nombre del autor no es columna: sale del embed a `public_profiles`,
  /// así la reseña muestra el nombre actual de quien la escribió y no una
  /// copia congelada del día que la publicó.
  ///
  /// Embebe la **vista** y no la tabla desde `030_public_profiles_view.sql`:
  /// `profiles` solo deja leer la fila propia, así que el embed a la tabla
  /// devuelve `null` para el autor de cualquier reseña ajena — es decir,
  /// todas. La vista expone el nombre y el avatar sin el email ni el
  /// teléfono.
  static const _baseColumns =
      'id, user_id, target_id, rating, comment, created_at, '
      'public_profiles(full_name, avatar_url, residence_type, origin_country_code, origin_city, origin_municipality)';

  /// `media_urls` es de la migración 040 — se pide aparte y con fallback
  /// (ver [_getForTargets]) para no romper proyectos que todavía no la
  /// corrieron.
  static const _columnsWithMedia = '$_baseColumns, media_urls';

  /// Las reseñas de un negocio, de la más nueva a la más vieja.
  ///
  /// Lectura pública deliberada: cualquiera ve las reseñas de cualquier
  /// negocio, así que no lleva filtro de dueño (ver CLAUDE.md > Supabase &
  /// Security Guidelines).
  Future<List<ReviewModel>> getForBusiness(String businessId) async {
    final byBusiness = await getForBusinesses([businessId]);
    return byBusiness[businessId] ?? const [];
  }

  /// Todas las reseñas de varios negocios en **un solo viaje**, agrupadas por
  /// `target_id`.
  ///
  /// Existe para que los listados (Inicio, mapa) puedan mostrar la calificación
  /// real sin una consulta por tarjeta. Trae la reseña completa y no un
  /// promedio agregado porque el volumen actual es de decenas de filas y un
  /// modelo a medias —reseñas sin autor ni comentario, solo para que el
  /// promedio cuadre— sería una trampa esperando a la próxima pantalla que las
  /// liste. Si algún día el volumen lo justifica, acá va una vista agregada en
  /// Postgres, no un cambio en quien llama.
  Future<Map<String, List<ReviewModel>>> getForBusinesses(
    List<String> businessIds,
  ) => _getForTargets(businessIds, targetType: businessTargetType);

  /// Los "Momentos" (comentario + fotos) que participantes compartieron de
  /// una jornada ECO mientras la vivían — misma tabla, mismo modelo, otro
  /// `target_type` (antes fijo a `'business'`, nunca usado por jornadas).
  Future<List<ReviewModel>> getForEcoActivity(String activityId) async {
    final byActivity = await getForEcoActivities([activityId]);
    return byActivity[activityId] ?? const [];
  }

  Future<Map<String, List<ReviewModel>>> getForEcoActivities(
    List<String> activityIds,
  ) => _getForTargets(activityIds, targetType: ecoActivityTargetType);

  Future<Map<String, List<ReviewModel>>> _getForTargets(
    List<String> targetIds, {
    required String targetType,
  }) async {
    if (targetIds.isEmpty) return const {};
    try {
      List<dynamic> rows;
      try {
        rows = await _client
            .from(_table)
            .select(_columnsWithMedia)
            .eq('target_type', targetType)
            .inFilter('target_id', targetIds)
            .order('created_at', ascending: false);
      } on PostgrestException catch (e) {
        final missingMediaColumn =
            (e.code == 'PGRST204' || e.code == '42703') &&
            e.message.contains('media_urls');
        if (!missingMediaColumn) rethrow;
        rows = await _client
            .from(_table)
            .select(_baseColumns)
            .eq('target_type', targetType)
            .inFilter('target_id', targetIds)
            .order('created_at', ascending: false);
      }
      final grouped = <String, List<ReviewModel>>{};
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final targetId = row['target_id'] as String? ?? '';
        if (targetId.isEmpty) continue;
        (grouped[targetId] ??= []).add(_fromRow(row));
      }
      return grouped;
    } on PostgrestException catch (e) {
      // 42P01 = migración 013 sin correr. El negocio/jornada se sigue
      // mostrando sin reseñas en vez de romper el feed entero por una tabla
      // ausente.
      if (e.code == '42P01') {
        debugPrint(
          '[ReviewService] _getForTargets: falta la tabla `reviews` '
          '(013_final_schema_additions.sql) — se muestran sin reseñas.',
        );
        return const {};
      }
      throw ReviewServiceException(
        'No se pudieron cargar las reseñas: ${e.message}',
      );
    } catch (_) {
      throw const ReviewServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Promedio y cantidad de un negocio, para el dashboard de su dueño.
  Future<RatingSummary> getSummary(String businessId) async {
    final reviews = await getForBusiness(businessId);
    return summarize(reviews);
  }

  static RatingSummary summarize(List<ReviewModel> reviews) {
    if (reviews.isEmpty) return RatingSummary.empty;
    final total = reviews.fold<double>(0, (sum, r) => sum + r.rating);
    return RatingSummary(
      average: total / reviews.length,
      count: reviews.length,
    );
  }

  /// Publica una reseña (o "Momento" de jornada ECO) a nombre de la sesión
  /// activa.
  ///
  /// `user_id` se estampa con `currentUser.id` y nunca con un valor recibido
  /// de la UI: es la columna de dueño de esta tabla. [mediaFiles] se sube al
  /// bucket [mediaBucket] antes del insert; si la subida falla, no se publica
  /// una reseña a medias.
  Future<void> addReview({
    required String targetId,
    required double rating,
    required String comment,
    String targetType = businessTargetType,
    List<XFile> mediaFiles = const [],
  }) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const ReviewServiceException(
        'Inicia sesión para escribir una reseña.',
      );
    }
    // La columna es `integer check (rating between 1 and 5)`; redondear acá
    // evita un 400 críptico de Postgres si alguna pantalla manda 4.5.
    final safeRating = rating.round().clamp(1, 5);

    if (targetType == ecoActivityTargetType) {
      try {
        final state = await EcoMomentService().getState(targetId);
        if (state == null || !state.canPost) {
          throw ReviewServiceException(
            state?.blockedReason ?? 'Inicia sesión para compartir.',
          );
        }
      } on EcoMomentException catch (e) {
        throw ReviewServiceException(e.message);
      }
    }

    final mediaUrls = mediaFiles.isEmpty
        ? const <String>[]
        : await _uploadMedia(userId, mediaFiles);

    final row = {
      'user_id': userId,
      'target_type': targetType,
      'target_id': targetId,
      'rating': safeRating,
      'comment': sanitizeMultilineText(comment),
      'media_urls': mediaUrls,
    };
    try {
      try {
        await _client.from(_table).insert(row);
      } on PostgrestException catch (e) {
        // `media_urls` es de la 040, corrida aparte de la 013 que crea la
        // tabla — si todavía no corrió, se reintenta sin esa columna en vez
        // de bloquear toda reseña nueva.
        final missingMediaColumn =
            (e.code == 'PGRST204' || e.code == '42703') &&
            e.message.contains('media_urls');
        if (!missingMediaColumn) rethrow;
        await _client.from(_table).insert(row..remove('media_urls'));
      }
      revision.value++;
    } on PostgrestException catch (e) {
      if (targetType == ecoActivityTargetType &&
          e.code == 'P0001' &&
          mediaUrls.isNotEmpty) {
        // El trigger rechazó la fila: libera fotos nuevas si se cerró el foro
        // o se agotó el cupo mientras se subían. No borra tras fallos ambiguos
        // de conexión, donde la publicación podría haberse confirmado.
        final prefix = _client.storage.from(mediaBucket).getPublicUrl('');
        final paths = mediaUrls
            .where((url) => url.startsWith(prefix))
            .map((url) => Uri.decodeComponent(url.substring(prefix.length)))
            .where((path) => path.startsWith('$userId/'))
            .toList();
        if (paths.isNotEmpty) {
          try {
            await _client.storage.from(mediaBucket).remove(paths);
          } catch (_) {
            debugPrint(
              '[ReviewService] No se pudieron liberar fotos de un momento rechazado.',
            );
          }
        }
      }
      throw ReviewServiceException(
        targetType == ecoActivityTargetType && e.code == 'P0001'
            ? e.message
            : 'No se pudo publicar tu reseña. Intenta de nuevo en un momento.',
      );
    } catch (_) {
      throw const ReviewServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Sube cada foto a `<user_id>/<uuid>.<ext>` en [mediaBucket] y devuelve
  /// sus URLs públicas en el mismo orden — mismo patrón que
  /// `EcoService.uploadActivityImage`.
  Future<List<String>> _uploadMedia(String userId, List<XFile> files) async {
    final urls = <String>[];
    for (final file in files) {
      final format = resolveImageUploadFormat(
        file.name,
        reportedMimeType: file.mimeType,
      );
      final objectPath = '$userId/${const Uuid().v4()}.${format.extension}';
      try {
        final bytes = await file.readAsBytes();
        await _client.storage
            .from(mediaBucket)
            .uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(
                contentType: format.mimeType,
                upsert: false,
              ),
            );
        urls.add(_client.storage.from(mediaBucket).getPublicUrl(objectPath));
      } on StorageException catch (e) {
        if (e.statusCode == '404') {
          throw const ReviewServiceException(
            'Falta crear el almacenamiento de fotos de reseñas. Corre '
            'supabase/sql/040_review_media_and_eco_target.sql en Supabase.',
          );
        }
        throw ReviewServiceException('No se pudo subir una foto: ${e.message}');
      }
    }
    return urls;
  }

  ReviewModel _fromRow(Map<String, dynamic> row) {
    final profile = row['public_profiles'] as Map<String, dynamic>?;
    final name = (profile?['full_name'] as String? ?? '').trim();
    return ReviewModel(
      id: row['id'] as String,
      authorId: row['user_id'] as String? ?? '',
      authorName: name.isEmpty ? 'Viajero' : name,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      authorOrigin: UserOrigin.fromRow(profile ?? const {}),
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      comment: row['comment'] as String? ?? '',
      date:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      mediaPaths:
          (row['media_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
