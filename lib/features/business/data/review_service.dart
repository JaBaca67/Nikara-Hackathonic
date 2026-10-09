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

/// Qué hizo [ReviewService.addReview]: escribir una reseña nueva o actualizar la
/// que la misma persona ya tenía de ese negocio.
enum ReviewWriteOutcome { created, updated }

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

  Future<int> countForUser(String userId) async {
    if (_client.auth.currentUser?.id != userId) {
      throw const ReviewServiceException('La cuenta cambió. Intenta de nuevo.');
    }
    try {
      return await _client
          .from(_table)
          .count(CountOption.exact)
          .eq('user_id', userId)
          .eq('target_type', businessTargetType);
    } catch (_) {
      throw const ReviewServiceException(
        'No se pudieron consultar tus reseñas.',
      );
    }
  }

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
      debugPrint('[ReviewService] _getForTargets: ${e.code} ${e.message}');
      throw const ReviewServiceException(
        'No se pudieron cargar las reseñas. Intenta de nuevo en un momento.',
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
    final counted = onePerAuthor(reviews);
    if (counted.isEmpty) return RatingSummary.empty;
    final total = counted.fold<double>(0, (sum, r) => sum + r.rating);
    return RatingSummary(
      average: total / counted.length,
      count: counted.length,
    );
  }

  /// Traduce los errores de Postgres propios de escribir una reseña. `null`
  /// si el código no es uno de los conocidos.
  @visibleForTesting
  static String? translateWriteError(
    PostgrestException e, {
    bool deleting = false,
  }) {
    switch (e.code) {
      case '23505':
        return 'Ya calificaste este lugar. Edita tu reseña en vez de crear '
            'otra.';
      case '42501':
        return deleting
            ? 'No tienes permiso para eliminar esta reseña. Inicia sesión de '
                  'nuevo e intenta otra vez.'
            : 'No tienes permiso para guardar esta reseña. Inicia sesión de '
                  'nuevo e intenta otra vez.';
    }
    return null;
  }

  /// Elimina la reseña propia de un negocio.
  ///
  /// Se borra por persona + negocio y no por id: la reseña que la pantalla
  /// acaba de crear todavía no conoce el id real de la fila. También limpia
  /// duplicados viejos de la misma persona. Solo toca `target_type =
  /// 'business'` (los Momentos de jornadas ECO y las fotos no se tocan) y el
  /// filtro de dueño va en la misma sentencia. Si no se borró ninguna fila y
  /// la reseña sigue ahí, es un permiso faltante y se avisa; si ya no existía,
  /// el resultado es el que se buscaba y no es un error.
  Future<void> deleteOwnReview(String businessId) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const ReviewServiceException(
        'Inicia sesión para eliminar tu reseña.',
      );
    }
    try {
      final deleted = await _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .eq('target_type', businessTargetType)
          .eq('target_id', businessId)
          .select('id');
      if (deleted.isEmpty) {
        final stillThere = await _findOwnReviewId(
          userId,
          businessId,
          businessTargetType,
        );
        if (stillThere != null) {
          throw const ReviewServiceException(
            'No se pudo eliminar tu reseña. Intenta de nuevo en un momento.',
          );
        }
      }
      revision.value++;
    } on ReviewServiceException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ReviewServiceException(
        translateWriteError(e, deleting: true) ??
            'No se pudo eliminar tu reseña. Intenta de nuevo en un momento.',
      );
    } on Exception {
      throw const ReviewServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// La reseña más reciente de [userId] sobre [targetId], o `null` si no
  /// tiene. Si quedan duplicados de antes de la restricción única, se queda
  /// con la última, que es la que cuenta.
  Future<String?> _findOwnReviewId(
    String userId,
    String targetId,
    String targetType,
  ) async {
    final row = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row?['id'] as String?;
  }

  /// Actualiza la reseña [reviewId]. El filtro de dueño va en la misma
  /// sentencia (ver CLAUDE.md); si ninguna fila cambia —id ajeno o policy de
  /// UPDATE ausente— se avisa en vez de fingir que se guardó.
  Future<void> _updateOwnReview(
    String userId,
    String reviewId,
    Map<String, dynamic> changes,
  ) async {
    final updated = await _client
        .from(_table)
        .update(changes)
        .eq('id', reviewId)
        .eq('user_id', userId)
        .select('id');
    if (updated.isEmpty) {
      throw const ReviewServiceException(
        'No se pudo actualizar tu reseña. Intenta de nuevo en un momento.',
      );
    }
  }

  /// Publica una reseña (o "Momento" de jornada ECO) a nombre de la sesión
  /// activa.
  ///
  /// Para negocios hay **una sola reseña por persona**: si ya tenía una, se
  /// actualiza en vez de crear otra y el resultado es
  /// [ReviewWriteOutcome.updated]. No usa `upsert` de PostgREST a propósito: la
  /// restricción única es parcial (solo `target_type = 'business'`, porque una
  /// persona sí puede compartir varios Momentos de una jornada) y
  /// `ON CONFLICT (user_id, target_id)` no puede inferir un índice parcial. Se
  /// busca la reseña propia y se actualiza, y si una carrera entre dos envíos
  /// provoca el error de unicidad se reintenta como actualización.
  ///
  /// `user_id` se estampa con `currentUser.id` y nunca con un valor recibido
  /// de la UI: es la columna de dueño de esta tabla. [mediaFiles] se sube al
  /// bucket [mediaBucket] antes de escribir; si la subida falla, no se publica
  /// una reseña a medias.
  Future<ReviewWriteOutcome> addReview({
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

    final cleanComment = sanitizeMultilineText(comment);
    final row = {
      'user_id': userId,
      'target_type': targetType,
      'target_id': targetId,
      'rating': safeRating,
      'comment': cleanComment,
      'media_urls': mediaUrls,
    };
    // Al editar solo se tocan calificación y comentario (y las fotos, si se
    // adjuntaron nuevas): mandar `media_urls: []` borraría las que ya tenía.
    Map<String, dynamic> changes() => {
      'rating': safeRating,
      'comment': cleanComment,
      if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
    };
    try {
      if (targetType == businessTargetType) {
        final existingId = await _findOwnReviewId(userId, targetId, targetType);
        if (existingId != null) {
          await _updateOwnReview(userId, existingId, changes());
          revision.value++;
          return ReviewWriteOutcome.updated;
        }
      }
      try {
        await _insertReview(row);
      } on PostgrestException catch (e) {
        if (e.code != '23505' || targetType != businessTargetType) rethrow;
        // Otro envío de la misma persona ganó la carrera: esta pasa a ser una
        // edición de esa reseña.
        final existingId = await _findOwnReviewId(userId, targetId, targetType);
        if (existingId == null) rethrow;
        await _updateOwnReview(userId, existingId, changes());
        revision.value++;
        return ReviewWriteOutcome.updated;
      }
      revision.value++;
      return ReviewWriteOutcome.created;
    } on ReviewServiceException {
      rethrow;
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
            : translateWriteError(e) ??
                  'No se pudo publicar tu reseña. Intenta de nuevo en un '
                      'momento.',
      );
    } catch (_) {
      throw const ReviewServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<void> _insertReview(Map<String, dynamic> row) async {
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
      await _client.from(_table).insert(Map.of(row)..remove('media_urls'));
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
          // Pista para quien despliega; la persona no puede hacer nada con ella.
          debugPrint(
            '[ReviewService] Falta el bucket de fotos de reseñas: corre '
            'supabase/sql/040_review_media_and_eco_target.sql en Supabase.',
          );
          throw const ReviewServiceException(
            'Por ahora no se pueden subir fotos. Intenta de nuevo más tarde.',
          );
        }
        debugPrint('[ReviewService] _uploadMedia: ${e.message}');
        throw const ReviewServiceException(
          'No se pudo subir una de las fotos. Verifica tu internet e intenta '
          'de nuevo.',
        );
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
