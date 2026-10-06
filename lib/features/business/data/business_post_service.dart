import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/utils/input_sanitizers.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_post_model.dart';

class BusinessPostServiceException implements Exception {
  const BusinessPostServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lee y escribe `business_posts` (supabase/sql/037_...sql) — el canal de
/// anuncios manual de cada negocio ("promo del día", un pase de día puntual,
/// un evento, un aviso de cierre). Mismo patrón singleton que
/// [ReviewService]/[EcoService].
class BusinessPostService {
  factory BusinessPostService() => instance;

  BusinessPostService._internal();

  static final BusinessPostService instance = BusinessPostService._internal();

  static const _table = 'business_posts';

  SupabaseClient get _client => Supabase.instance.client;

  /// Los anuncios de un negocio, del más nuevo al más viejo.
  ///
  /// Lectura pública deliberada: cualquiera ve los anuncios de cualquier
  /// negocio, igual que el resto del detalle público (ver CLAUDE.md >
  /// Supabase & Security Guidelines), así que no lleva filtro de dueño.
  Future<List<BusinessPostModel>> getPostsForBusiness(String businessId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(BusinessPostModel.fromRow)
          .toList();
    } on PostgrestException catch (e) {
      // 42P01 = migración 037 sin correr. El negocio se sigue mostrando sin
      // anuncios en vez de romper el detalle entero por una tabla ausente.
      if (e.code == '42P01') return const [];
      throw BusinessPostServiceException(
        'No se pudieron cargar los anuncios: ${e.message}',
      );
    } catch (_) {
      throw const BusinessPostServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Publica un anuncio a nombre de la sesión activa, dueña del negocio.
  ///
  /// `owner_id` se estampa con `currentUser.id` y nunca con un valor recibido
  /// de la UI; la policy de insert además valida que ese mismo usuario sea
  /// el dueño de `businessId` (ver migración 037).
  Future<void> createPost({
    required String businessId,
    required String body,
    XFile? image,
  }) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const BusinessPostServiceException(
        'Inicia sesión para publicar un anuncio.',
      );
    }
    final trimmedBody = sanitizeMultilineText(body);
    if (trimmedBody.isEmpty) {
      throw const BusinessPostServiceException(
        'Escribe algo antes de publicar el anuncio.',
      );
    }
    try {
      // Reusa el mismo bucket/flujo de subida que las fotos del negocio —
      // ver BusinessStorageService.uploadImage.
      final imageUrl = image == null
          ? null
          : await BusinessStorageService().uploadImage(image);
      await _client.from(_table).insert({
        'business_id': businessId,
        'owner_id': userId,
        'body': trimmedBody,
        'image_url': imageUrl,
      });
    } on BusinessServiceException catch (e) {
      // uploadImage lanza su propia excepción (subida de foto) — se traduce
      // a la de este servicio para que la UI capture un solo tipo.
      throw BusinessPostServiceException(e.message);
    } on PostgrestException catch (e) {
      throw BusinessPostServiceException(
        'No se pudo publicar el anuncio: ${e.message}',
      );
    } catch (_) {
      throw const BusinessPostServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// `.eq('owner_id', ...)` va en la misma sentencia que el `delete` —
  /// mismo motivo que `BusinessStorageService._updateRow` (ver su comentario):
  /// es lo que impide borrar el anuncio de otro negocio conociendo su id.
  Future<void> deletePost(String postId) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const BusinessPostServiceException(
        'Inicia sesión para administrar tus anuncios.',
      );
    }
    try {
      await _client
          .from(_table)
          .delete()
          .eq('id', postId)
          .eq('owner_id', userId);
    } on PostgrestException catch (e) {
      throw BusinessPostServiceException(
        'No se pudo borrar el anuncio: ${e.message}',
      );
    } catch (_) {
      throw const BusinessPostServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }
}
