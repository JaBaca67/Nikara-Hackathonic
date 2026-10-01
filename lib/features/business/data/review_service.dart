import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/utils/input_sanitizers.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';

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
/// **Lo que se pierde en el viaje**: `ReviewModel.mediaPaths` (las fotos que se
/// adjuntaban en "Escribir una reseña") no tiene columna en la tabla ni bucket
/// en Storage, así que no se persiste. Tampoco se perdía nada usable: eran
/// rutas del sistema de archivos del autor, ilegibles desde cualquier otro
/// teléfono.
class ReviewService {
  factory ReviewService() => instance;

  ReviewService._internal();

  static final ReviewService instance = ReviewService._internal();

  /// Sube en cada escritura para que las pantallas se refresquen sin
  /// pull-to-refresh, igual que `BusinessStorageService.revision`.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const _table = 'reviews';

  /// `reviews.target_id` apunta a `businesses.id` o a `eco_activities.id`
  /// según `target_type`; hoy la app solo escribe reseñas de negocios.
  static const _targetType = 'business';

  SupabaseClient get _client => Supabase.instance.client;

  /// El nombre del autor no es columna: sale del embed a `profiles`, así la
  /// reseña muestra el nombre actual de quien la escribió y no una copia
  /// congelada del día que la publicó.
  static const _columns =
      'id, user_id, target_id, rating, comment, created_at, '
      'profiles(full_name)';

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
  ) async {
    if (businessIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from(_table)
          .select(_columns)
          .eq('target_type', _targetType)
          .inFilter('target_id', businessIds)
          .order('created_at', ascending: false);
      final grouped = <String, List<ReviewModel>>{};
      for (final row in (rows as List<dynamic>).cast<Map<String, dynamic>>()) {
        final targetId = row['target_id'] as String? ?? '';
        if (targetId.isEmpty) continue;
        (grouped[targetId] ??= []).add(_fromRow(row));
      }
      return grouped;
    } on PostgrestException catch (e) {
      // 42P01 = migración 013 sin correr. El negocio se sigue mostrando sin
      // reseñas en vez de romper el feed entero por una tabla ausente.
      if (e.code == '42P01') {
        debugPrint(
          '[ReviewService] getForBusinesses: falta la tabla `reviews` '
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

  /// Publica una reseña a nombre de la sesión activa.
  ///
  /// `user_id` se estampa con `currentUser.id` y nunca con un valor recibido de
  /// la UI: es la columna de dueño de esta tabla.
  Future<void> addReview({
    required String businessId,
    required double rating,
    required String comment,
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
    try {
      await _client.from(_table).insert({
        'user_id': userId,
        'target_type': _targetType,
        'target_id': businessId,
        'rating': safeRating,
        'comment': sanitizeMultilineText(comment),
      });
      revision.value++;
    } on PostgrestException catch (e) {
      throw ReviewServiceException(
        'No se pudo publicar tu reseña: ${e.message}',
      );
    } catch (_) {
      throw const ReviewServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  ReviewModel _fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final name = (profile?['full_name'] as String? ?? '').trim();
    return ReviewModel(
      id: row['id'] as String,
      authorId: row['user_id'] as String? ?? '',
      authorName: name.isEmpty ? 'Viajero' : name,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      comment: row['comment'] as String? ?? '',
      date:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      // Sin columna ni bucket: ver la nota de la clase.
      mediaPaths: const [],
    );
  }
}
