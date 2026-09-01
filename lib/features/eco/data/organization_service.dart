import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/utils/image_upload.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';

class OrganizationServiceException implements Exception {
  const OrganizationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Lee y escribe `public.organizations` (supabase/sql/010_organizations.sql); mismo patrón singleton que [EcoService]/[AuthService].
class OrganizationService {
  factory OrganizationService() => OrganizationService.instance;

  OrganizationService._internal();

  static final OrganizationService instance = OrganizationService._internal();

  /// Sube en cada escritura local, igual que `EcoService.revision`, para refrescar sin pull-to-refresh.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  /// Lista vacía si no hay sesión o si la migración 010 no se ha corrido (la tabla no existe aún).
  Future<List<OrganizationModel>> getMyOrganizations() async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) return const [];
    return getOrganizationsByOwner(userId);
  }

  Future<List<OrganizationModel>> getOrganizationsByOwner(
    String ownerId,
  ) async {
    try {
      final rows = await _client
          .from('organizations')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at');
      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(OrganizationModel.fromRow)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      // 42P01 = migración 010 sin correr; se degrada a "no tienes fundaciones" en vez de bloquear el formulario.
      if (e.code == '42P01') return const [];
      throw OrganizationServiceException(
        'No se pudieron cargar tus fundaciones: ${e.message}',
      );
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<OrganizationModel?> getById(String id) async {
    try {
      final row = await _client
          .from('organizations')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : OrganizationModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw OrganizationServiceException(
        'No se pudo cargar la fundación: ${e.message}',
      );
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// `is_verified` queda en su default de columna; el cliente nunca lo envía, igual que `businesses.is_verified`.
  Future<OrganizationModel> createOrganization({
    required String name,
    required String handle,
    String description = '',
    String? logoUrl,
    String? bannerUrl,
  }) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const OrganizationServiceException(
        'Necesitas iniciar sesión para registrar una fundación.',
      );
    }
    final normalizedHandle = OrganizationModel.normalizeHandle(handle);
    if (normalizedHandle.isEmpty) {
      throw const OrganizationServiceException(
        'El handle solo puede tener letras, números, puntos o guiones bajos.',
      );
    }
    try {
      final row = await _client
          .from('organizations')
          .insert({
            'name': name,
            'handle': normalizedHandle,
            'description': description,
            'logo_url': logoUrl,
            'banner_url': bannerUrl,
            'owner_id': userId,
          })
          .select()
          .single();
      revision.value++;
      unawaited(
        NotificationService().notifyAdminsOfPendingReview(
          title: 'Fundación nueva por revisar',
          body: '"$name" está esperando tu revisión.',
        ),
      );
      return OrganizationModel.fromRow(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw OrganizationServiceException(
          'El handle "@$normalizedHandle" ya está en uso. Elige otro.',
        );
      }
      if (e.code == '42P01') {
        throw const OrganizationServiceException(
          'Falta correr la migración de fundaciones en Supabase '
          '(supabase/sql/010_organizations.sql).',
        );
      }
      throw OrganizationServiceException(
        'No se pudo registrar la fundación: ${e.message}',
      );
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// RLS está deshabilitada en `organizations` (ver 010), así que la
  /// pertenencia se valida acá: sin este chequeo cualquier cliente podría
  /// editar la fundación de otra persona conociendo su id.
  Future<void> _assertOwnership(String id) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const OrganizationServiceException(
        'Necesitas iniciar sesión para gestionar tus fundaciones.',
      );
    }
    final row = await _client
        .from('organizations')
        .select('owner_id')
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const OrganizationServiceException('Esa fundación ya no existe.');
    }
    if (row['owner_id'] != userId) {
      throw const OrganizationServiceException(
        'Solo quien registró la fundación puede modificarla.',
      );
    }
  }

  /// Contraparte de [createOrganization] para editar. [logoUrl]/[bannerUrl]
  /// con valor reemplazan la imagen y `null` la deja como está; para quitarla
  /// están [clearLogo]/[clearBanner] — tres estados que un solo parámetro
  /// nullable no puede distinguir.
  ///
  /// `owner_id` e `is_verified` nunca se envían: el dueño no cambia y la
  /// verificación no la decide el cliente, igual que en [createOrganization].
  Future<OrganizationModel> updateOrganization({
    required String id,
    required String name,
    required String handle,
    String description = '',
    String? logoUrl,
    bool clearLogo = false,
    String? bannerUrl,
    bool clearBanner = false,
  }) async {
    final normalizedHandle = OrganizationModel.normalizeHandle(handle);
    if (normalizedHandle.isEmpty) {
      throw const OrganizationServiceException(
        'El handle solo puede tener letras, números, puntos o guiones bajos.',
      );
    }
    try {
      await _assertOwnership(id);
      final patch = <String, dynamic>{
        'name': name,
        'handle': normalizedHandle,
        'description': description,
      };
      if (clearLogo) {
        patch['logo_url'] = null;
      } else if (logoUrl != null) {
        patch['logo_url'] = logoUrl;
      }
      if (clearBanner) {
        patch['banner_url'] = null;
      } else if (bannerUrl != null) {
        patch['banner_url'] = bannerUrl;
      }

      final row = await _client
          .from('organizations')
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      revision.value++;
      return OrganizationModel.fromRow(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw OrganizationServiceException(
          'El handle "@$normalizedHandle" ya está en uso. Elige otro.',
        );
      }
      throw OrganizationServiceException(
        'No se pudieron guardar los cambios: ${e.message}',
      );
    } on OrganizationServiceException {
      rethrow;
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Devuelve a la cola de revisión una fundación que fue rechazada.
  ///
  /// Contraparte de `EcoService.resubmitActivity` para `organizations`: el
  /// dueño toca su propia fila, así que va por `update` con el filtro de
  /// dueño y el de estado en la misma sentencia, no por el RPC de admin.
  Future<void> resubmitOrganization(String id) async {
    final userId = AuthService().currentAuthUser?.id;
    if (userId == null) {
      throw const OrganizationServiceException(
        'Necesitas iniciar sesión para gestionar tus fundaciones.',
      );
    }
    try {
      final updated = await _client
          .from('organizations')
          .update({
            'status': ReviewStatus.pendiente.wireValue,
            'rejection_reason': null,
          })
          .eq('id', id)
          .eq('owner_id', userId)
          .eq('status', ReviewStatus.rechazado.wireValue)
          .select('id');
      if ((updated as List<dynamic>).isEmpty) {
        throw const OrganizationServiceException(
          'No se pudo reenviar la fundación: ya no existe, no es tuya o no '
          'está rechazada.',
        );
      }
      revision.value++;
    } on PostgrestException catch (e) {
      throw OrganizationServiceException(
        'No se pudo reenviar la fundación: ${e.message}',
      );
    } on OrganizationServiceException {
      rethrow;
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Las jornadas publicadas a su nombre NO se borran: `organization_id` es
  /// `on delete set null` (010), así que pasan a figurar como publicaciones
  /// personales de quien las creó. Quien llama debe advertirlo.
  Future<void> deleteOrganization(String id) async {
    try {
      await _assertOwnership(id);
      await _client.from('organizations').delete().eq('id', id);
      revision.value++;
    } on PostgrestException catch (e) {
      throw OrganizationServiceException(
        'No se pudo eliminar la fundación: ${e.message}',
      );
    } on OrganizationServiceException {
      rethrow;
    } catch (_) {
      throw const OrganizationServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Bucket público con los logos y banners (ver supabase/sql/017_organization_assets.sql).
  static const imageBucket = 'organizations';

  /// Sube un logo o banner y devuelve su URL pública, la que se guarda en
  /// `logo_url`/`banner_url`.
  ///
  /// Antes esas columnas guardaban la ruta local de `image_picker`, así que la
  /// imagen solo existía en el dispositivo que la eligió — inútil para un
  /// perfil que es público por definición.
  Future<String> uploadImage(XFile image) async {
    final user = AuthService().currentAuthUser;
    if (user == null) {
      throw const OrganizationServiceException(
        'Necesitas iniciar sesión para subir una imagen.',
      );
    }
    final format = resolveImageUploadFormat(
      image.name,
      reportedMimeType: image.mimeType,
    );
    final objectPath = '${user.id}/${const Uuid().v4()}.${format.extension}';
    try {
      // readAsBytes y no File: en web `XFile.path` es un `blob:`, no una ruta.
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
      // La ruta se acaba de generar, así que un 404 solo puede ser el bucket.
      if (e.statusCode == '404') {
        throw const OrganizationServiceException(
          'Falta crear el almacenamiento de fundaciones. Corre '
          'supabase/sql/017_organization_assets.sql en Supabase.',
        );
      }
      throw OrganizationServiceException(
        'No se pudo subir la imagen: ${e.message}',
      );
    } catch (_) {
      throw const OrganizationServiceException(
        'No se pudo subir la imagen. Verifica tu internet e intenta de nuevo.',
      );
    }
  }
}
