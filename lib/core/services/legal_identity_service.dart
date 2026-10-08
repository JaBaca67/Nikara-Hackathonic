import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/legal_identity_model.dart';
import 'package:nikara_app/core/utils/image_upload.dart';
import 'package:nikara_app/core/utils/input_sanitizers.dart';

class LegalIdentityServiceException implements Exception {
  const LegalIdentityServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Identidad legal (RUC/cédula) de quien registra un negocio, fundación o
/// jornada ECO — `legal_identities`, una fila por usuario
/// (`supabase/sql/023_legal_identities.sql` + `024_legal_identity_back_photo.sql`).
///
/// Sin RLS, mismo criterio que el resto del proyecto (ver CLAUDE.md >
/// Supabase & Security Guidelines): el cliente filtra por `auth.uid()`.
class LegalIdentityService {
  factory LegalIdentityService() => _instance;
  LegalIdentityService._internal();
  static final LegalIdentityService _instance =
      LegalIdentityService._internal();

  static const documentsBucket = 'legal_identities';

  SupabaseClient get _client => Supabase.instance.client;

  String _requireCurrentUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const LegalIdentityServiceException(
        'Necesitas iniciar sesión para continuar.',
      );
    }
    return userId;
  }

  /// La identidad de la cuenta activa, o `null` si todavía no cargó una — el
  /// gate se salta cuando esto no es nulo.
  Future<LegalIdentityModel?> getMine() async {
    final userId = _requireCurrentUserId();
    try {
      final row = await _client
          .from('legal_identities')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? null : LegalIdentityModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw LegalIdentityServiceException(
        'No se pudo verificar tu identidad legal: ${e.message}',
      );
    } catch (_) {
      throw const LegalIdentityServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Para el panel admin: la identidad de OTRO usuario, la del dueño de lo que
  /// se está revisando. `null` si esa cuenta nunca cargó una (negocios de
  /// antes de esta fase, o datos de prueba).
  Future<LegalIdentityModel?> getForUser(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final row = await _client
          .from('legal_identities')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row == null ? null : LegalIdentityModel.fromRow(row);
    } on PostgrestException catch (e) {
      throw LegalIdentityServiceException(
        'No se pudo cargar la identidad legal: ${e.message}',
      );
    } catch (_) {
      throw const LegalIdentityServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Sube una foto de documento al bucket privado y devuelve su **path**, no
  /// una URL: a diferencia de avatars/organizations/businesses (públicos,
  /// `getPublicUrl` nunca vence), este bucket es privado y una URL firmada
  /// vence. Guardar el path y firmar recién al mostrarla (ver [signedUrlFor])
  /// evita que la columna quede con un enlace roto un año después.
  Future<String> uploadDocumentPhoto(XFile image) async {
    final userId = _requireCurrentUserId();
    final format = resolveImageUploadFormat(
      image.name,
      reportedMimeType: image.mimeType,
    );
    final objectPath = '$userId/${const Uuid().v4()}.${format.extension}';
    try {
      final bytes = await image.readAsBytes();
      await _client.storage
          .from(documentsBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: format.mimeType,
              upsert: false,
            ),
          );
      return objectPath;
    } on StorageException catch (e) {
      if (e.statusCode == '404') {
        throw const LegalIdentityServiceException(
          'Falta crear el almacenamiento de documentos. Corre '
          'supabase/sql/023_legal_identities.sql en Supabase.',
        );
      }
      throw LegalIdentityServiceException(
        'No se pudo subir la foto del documento: ${e.message}',
      );
    } catch (_) {
      throw const LegalIdentityServiceException(
        'No se pudo subir la foto del documento. Verifica tu internet e '
        'intenta de nuevo.',
      );
    }
  }

  /// URL firmada de corta duración para mostrar una foto de documento — se
  /// llama al momento de renderizar (el propio dueño en su gate, o un
  /// admin/auditor en revisión), nunca se guarda.
  Future<String> signedUrlFor(String objectPath) async {
    try {
      return await _client.storage
          .from(documentsBucket)
          .createSignedUrl(objectPath, 300);
    } on StorageException catch (e) {
      throw LegalIdentityServiceException(
        'No se pudo abrir la foto del documento: ${e.message}',
      );
    }
  }

  /// Guarda (o actualiza, por el `unique(user_id)`) la identidad de la cuenta
  /// activa. [documentNumber] se normaliza acá — no confiar en que la
  /// pantalla ya lo haya hecho.
  Future<void> save({
    required LegalIdentityKind kind,
    required String documentNumber,
    required String documentPhotoUrl,
    String? documentPhotoBackUrl,
  }) async {
    final userId = _requireCurrentUserId();
    final normalizedNumber = sanitizeLegalDocumentNumber(documentNumber);
    final isValid = kind == LegalIdentityKind.juridica
        ? rucPattern.hasMatch(normalizedNumber)
        : cedulaPattern.hasMatch(normalizedNumber) ||
              cedulaSinDocumentoPattern.hasMatch(normalizedNumber);
    if (!isValid) {
      throw LegalIdentityServiceException(
        kind == LegalIdentityKind.juridica
            ? 'El RUC no tiene el formato válido (J + 13 dígitos).'
            : 'El documento no tiene un formato válido (cédula '
                  '001-201208-1009S, o N + 13 dígitos si no tenés cédula).',
      );
    }
    final row = {
      'user_id': userId,
      'kind': kind.wireValue,
      'document_number': normalizedNumber,
      'document_photo_url': documentPhotoUrl,
      'document_photo_back_url': documentPhotoBackUrl,
    };
    try {
      try {
        await _client
            .from('legal_identities')
            .upsert(row, onConflict: 'user_id');
      } on PostgrestException catch (e) {
        // `document_photo_back_url` es de 024, corrida aparte de la 023 que
        // crea la tabla — si todavía no corrió, se reintenta sin esa
        // columna en vez de bloquear a toda persona natural.
        final missingBackColumn =
            (e.code == 'PGRST204' || e.code == '42703') &&
            e.message.contains('document_photo_back_url');
        if (!missingBackColumn) rethrow;
        await _client
            .from('legal_identities')
            .upsert(
              row..remove('document_photo_back_url'),
              onConflict: 'user_id',
            );
      }
    } on PostgrestException catch (e) {
      throw LegalIdentityServiceException(
        'No se pudo guardar tu identidad legal: ${e.message}',
      );
    } catch (_) {
      throw const LegalIdentityServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }
}
