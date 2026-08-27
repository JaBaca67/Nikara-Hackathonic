import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/utils/image_upload.dart';
import 'package:nikara_app/core/utils/input_sanitizers.dart';
import 'package:nikara_app/features/business/data/review_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';

class BusinessServiceException implements Exception {
  const BusinessServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persiste [BusinessModel] en la tabla `businesses` de Supabase. Hasta la
/// migración `021_business_extras_columns.sql`, `amenities`/`activities`/
/// `ecoSealRequested`/`ecoPractices`/`accessDetails`/`otherNotes` vivían solo
/// en un cache local de `SharedPreferences` — invisibles para cualquier
/// dispositivo que no fuera el que registró el negocio. Ya son columnas
/// reales; no queda cache local que fusionar.
class BusinessStorageService {
  /// Se incrementa en cada escritura para que pantallas como "Mis Negocios" se refresquen sin reiniciar.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Bucket público con portada + galería (ver supabase/sql/022_business_photos_storage.sql).
  static const photosBucket = 'businesses';

  SupabaseClient get _client => Supabase.instance.client;

  /// Sube una foto y devuelve su URL pública — mismo patrón que
  /// `AuthService.updateAvatar` y `OrganizationService.uploadImage`. El wizard
  /// la llama una vez por foto nueva, al guardar (no al elegirla), para no
  /// dejar archivos huérfanos si el usuario abandona el formulario.
  ///
  /// Antes `businesses.photos` guardaba la ruta local de `image_picker` — una
  /// portada/galería que solo existía en el dispositivo que la subió, el
  /// mismo bug que ya se había arreglado para avatars (015) y organizations
  /// (017).
  Future<String> uploadImage(XFile image) async {
    final user = AuthService().currentAuthUser;
    if (user == null) {
      throw const BusinessServiceException(
        'Necesitas iniciar sesión para subir una foto.',
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
          .from(photosBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: format.mimeType,
              upsert: false,
            ),
          );
      return _client.storage.from(photosBucket).getPublicUrl(objectPath);
    } on StorageException catch (e) {
      // La ruta se acaba de generar, así que un 404 solo puede ser el bucket.
      if (e.statusCode == '404') {
        throw const BusinessServiceException(
          'Falta crear el almacenamiento de fotos. Corre '
          'supabase/sql/022_business_photos_storage.sql en Supabase.',
        );
      }
      throw BusinessServiceException('No se pudo subir la foto: ${e.message}');
    } catch (_) {
      throw const BusinessServiceException(
        'No se pudo subir una foto. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Listado público: solo negocios aprobados.
  ///
  /// Es un filtro de **estado**, no de dueño — no choca con la regla de que
  /// las consultas públicas nunca se filtran por `owner_id` (ver CLAUDE.md >
  /// Supabase & Security Guidelines). Un turista sigue viendo negocios que no
  /// son suyos; lo que no ve es lo que todavía nadie revisó.
  Future<List<BusinessModel>> getBusinesses() async {
    final rows = await _select();
    return _hydrate(rows);
  }

  /// Los negocios del usuario actual, **sin** filtrar por estado: el dueño
  /// tiene que ver sus propios `pendiente` y `rechazado`, que son justo los
  /// que no aparecen en [getBusinesses].
  ///
  /// Consulta "mis X": el `owner_id` sale siempre de la sesión activa, nunca
  /// de un parámetro que venga de la UI. Sin sesión devuelve vacío en vez de
  /// lanzar — quien llama es una pantalla de perfil que también se abre como
  /// invitado.
  Future<List<BusinessModel>> getMyBusinesses() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null || ownerId.isEmpty) return const [];
    return _hydrate(await _select(ownerId: ownerId));
  }

  /// Usa el RPC `businesses_in_bounds` (índice GiST) para traer solo lo visible en el mapa, sin descargar toda la tabla en cada pan/zoom.
  Future<List<BusinessModel>> getBusinessesInBounds({
    required double minLng,
    required double minLat,
    required double maxLng,
    required double maxLat,
  }) async {
    return _hydrate(
      await _selectInBounds(
        minLng: minLng,
        minLat: minLat,
        maxLng: maxLng,
        maxLat: maxLat,
      ),
    );
  }

  /// Completa las filas crudas con las reseñas, que viven en la tabla
  /// `reviews` en vez de en `businesses`.
  ///
  /// Las reseñas se piden en **una sola** consulta para todo el lote, no una
  /// por negocio. Si esa consulta falla, los negocios se devuelven sin reseñas
  /// en vez de tumbar el listado: un feed sin calificaciones sigue siendo útil,
  /// un feed vacío no.
  Future<List<BusinessModel>> _hydrate(List<Map<String, dynamic>> rows) async {
    final cores = rows.map(_fromRow).toList(growable: false);

    Map<String, List<ReviewModel>> reviews = const {};
    try {
      reviews = await ReviewService().getForBusinesses([
        for (final business in cores) business.id,
      ]);
    } on ReviewServiceException catch (e) {
      debugPrint(
        '[BusinessStorageService] _hydrate: no se pudieron cargar las reseñas '
        '— ${e.message}',
      );
      return cores;
    }
    return cores
        .map((business) => business.copyWith(reviews: reviews[business.id]))
        .toList(growable: false);
  }

  /// Notifica cambios en `businesses` hechos por otros dispositivos (complementa a [revision]); si Realtime no está habilitado en la tabla, simplemente no llegan eventos.
  Future<void> Function() subscribeToBusinessChanges(VoidCallback onChange) {
    final channel = _client
        .channel('public:businesses')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'businesses',
          callback: (_) => onChange(),
        )
        .subscribe();
    return () => _client.removeChannel(channel);
  }

  /// No se limita al viewport del mapa (a diferencia de [getBusinessesInBounds]) para que los chips de categoría no cambien al hacer pan.
  Future<List<String>> getAllCategories() async {
    try {
      final rows = await _client
          .from('businesses')
          .select('category')
          .eq('status', ReviewStatus.aprobado.wireValue);
      final categories = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => row['category'] as String? ?? '')
          .where((category) => category.isNotEmpty)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    } on PostgrestException catch (e) {
      throw BusinessServiceException(
        'No se pudieron cargar las categorías: ${e.message}',
      );
    } catch (_) {
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<void> addBusiness(BusinessModel rawBusiness) async {
    final ownerId = _requireCurrentUserId();
    final business = _sanitized(rawBusiness);
    _requireLocation(business);
    // El dueño se estampa desde la sesión, nunca desde el modelo que llegó de
    // la UI: es la única fuente que una pantalla no puede falsificar.
    final row = {'id': business.id, 'owner_id': ownerId, ..._toRow(business)};
    debugPrint(
      '[BusinessStorageService] addBusiness("${business.name}") '
      'lat=${business.latitude} lng=${business.longitude} '
      'location="${row['location']}"',
    );
    try {
      await _insertRow(row);
      debugPrint(
        '[BusinessStorageService] addBusiness("${business.name}") -> OK',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '[BusinessStorageService] addBusiness("${business.name}") -> '
        'PostgrestException code=${e.code} message=${e.message} '
        'details=${e.details} hint=${e.hint}',
      );
      throw BusinessServiceException(
        'No se pudo guardar el negocio: ${e.message}',
      );
    } catch (e) {
      debugPrint(
        '[BusinessStorageService] addBusiness("${business.name}") -> '
        'unexpected error: $e',
      );
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    revision.value++;
  }

  Future<void> updateBusiness(BusinessModel rawBusiness) async {
    final ownerId = _requireCurrentUserId();
    final business = _sanitized(rawBusiness);
    _requireLocation(business);
    // `owner_id` no viaja en el update: el dueño de un negocio no cambia, y
    // enviarlo abriría la puerta a "regalarle" una fila a otra cuenta.
    final row = _toRow(business);
    debugPrint(
      '[BusinessStorageService] updateBusiness("${business.name}", '
      'id=${business.id}) lat=${business.latitude} lng=${business.longitude} '
      'location="${row['location']}"',
    );
    try {
      await _updateRow(business.id, ownerId, row);
      debugPrint(
        '[BusinessStorageService] updateBusiness("${business.name}") -> OK',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '[BusinessStorageService] updateBusiness("${business.name}") -> '
        'PostgrestException code=${e.code} message=${e.message} '
        'details=${e.details} hint=${e.hint}',
      );
      throw BusinessServiceException(
        'No se pudo actualizar el negocio: ${e.message}',
      );
    } on BusinessServiceException {
      rethrow;
    } catch (e) {
      debugPrint(
        '[BusinessStorageService] updateBusiness("${business.name}") -> '
        'unexpected error: $e',
      );
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    revision.value++;
  }

  /// Devuelve a la cola de revisión un negocio que fue rechazado.
  ///
  /// No pasa por el RPC `review_business`: ése valida rol admin/auditor y
  /// existe para **aprobar o rechazar**. Esto es el dueño tocando su propia
  /// fila para volver a pedir revisión, así que es un `update` normal con el
  /// filtro de dueño en la misma sentencia, igual que [updateBusiness].
  ///
  /// El `.eq('status', rechazado)` también va adentro del `update` a
  /// propósito: sin él, un negocio ya aprobado podría volver a `pendiente` por
  /// un doble toque y desaparecería del feed público hasta que alguien lo
  /// revisara otra vez.
  Future<void> resubmitBusiness(String id) async {
    final ownerId = _requireCurrentUserId();
    try {
      final updated = await _client
          .from('businesses')
          .update({
            'status': ReviewStatus.pendiente.wireValue,
            'rejection_reason': null,
          })
          .eq('id', id)
          .eq('owner_id', ownerId)
          .eq('status', ReviewStatus.rechazado.wireValue)
          .select('id');
      if ((updated as List<dynamic>).isEmpty) {
        throw const BusinessServiceException(
          'No se pudo reenviar el negocio: ya no existe, no es tuyo o no '
          'está rechazado.',
        );
      }
    } on PostgrestException catch (e) {
      throw BusinessServiceException(
        'No se pudo reenviar el negocio: ${e.message}',
      );
    } on BusinessServiceException {
      rethrow;
    } catch (_) {
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    revision.value++;
  }

  Future<void> deleteBusiness(String id) async {
    final ownerId = _requireCurrentUserId();
    try {
      // El filtro de dueño va en la misma sentencia del delete, no en un
      // `select` previo: entre leer y borrar hay una ventana en la que la
      // fila puede cambiar de manos, y el borrado no la vería.
      final deleted = await _client
          .from('businesses')
          .delete()
          .eq('id', id)
          .eq('owner_id', ownerId)
          .select('id');
      if ((deleted as List<dynamic>).isEmpty) {
        throw const BusinessServiceException(
          'No se pudo eliminar el negocio: ya no existe o no es tuyo.',
        );
      }
    } on PostgrestException catch (e) {
      throw BusinessServiceException(
        'No se pudo eliminar el negocio: ${e.message}',
      );
    } on BusinessServiceException {
      rethrow;
    } catch (_) {
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    revision.value++;
  }

  /// Delega en [ReviewService]: las reseñas viven en la tabla `reviews` desde
  /// que se conectó ese servicio, no en el cache local del dispositivo.
  ///
  /// Sigue viviendo acá para no cambiar a quien ya la llamaba, pero no escribe
  /// nada de `businesses`. `mediaPaths` no viaja — ver la nota de
  /// [ReviewService].
  Future<void> addReview(BusinessModel business, ReviewModel review) async {
    await ReviewService().addReview(
      businessId: business.id,
      rating: review.rating,
      comment: review.comment,
    );
    revision.value++;
  }

  /// Ninguna mutación sale sin sesión: `owner_id` es uuid NOT NULL en Postgres
  /// y un string vacío falla con un error críptico en la base. Además es el
  /// valor con el que se filtra la pertenencia, así que sin él no hay forma de
  /// saber qué filas puede tocar quien está usando la app.
  String _requireCurrentUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const BusinessServiceException(
        'No se pudo identificar al propietario del negocio. Inicia sesión '
        'de nuevo e intenta otra vez.',
      );
    }
    return userId;
  }

  /// Normaliza todo el texto del negocio en un solo lugar, antes de que salga
  /// hacia Supabase **y** antes de guardarlo en el cache local de extras: si
  /// solo se saneara la fila, el cache devolvería la versión sucia al leer
  /// (ver [_mergeExtras]) y el dato quedaría distinto según de dónde se lea.
  BusinessModel _sanitized(BusinessModel b) {
    return b.copyWith(
      name: sanitizeText(b.name, maxLength: InputLimits.name),
      category: sanitizeText(b.category, maxLength: InputLimits.shortLabel),
      description: sanitizeMultilineText(b.description),
      city: sanitizeText(b.city, maxLength: InputLimits.shortLabel),
      locationText: sanitizeText(
        b.locationText,
        maxLength: InputLimits.address,
      ),
      contactPhone: sanitizePhone(b.contactPhone),
      instagramLink: sanitizeInstagramHandle(b.instagramLink),
      facebookLink: sanitizeFacebookHandle(b.facebookLink),
      tiktokLink: sanitizeTiktokHandle(b.tiktokLink),
      schedules: sanitizeText(b.schedules, maxLength: InputLimits.mediumText),
      accessDetails: sanitizeMultilineText(b.accessDetails),
      otherNotes: sanitizeMultilineText(b.otherNotes),
      amenities: sanitizeTextList(b.amenities),
      activities: sanitizeTextList(b.activities),
      ecoPractices: sanitizeTextList(b.ecoPractices),
      hostName: sanitizeProperName(b.hostName),
      localImagePaths: _sanitizePhotos(b.localImagePaths),
    );
  }

  /// Las fotos son rutas locales *o* URLs de Storage, así que solo se recortan
  /// y se deduplican: colapsar espacios como en el texto libre rompería una
  /// ruta de archivo que los tenga.
  static List<String> _sanitizePhotos(List<String> photos) {
    final seen = <String>{};
    final result = <String>[];
    for (final photo in photos) {
      final value = photo.trim();
      if (value.isEmpty || !seen.add(value)) continue;
      result.add(value);
      if (result.length >= 20) break;
    }
    return List<String>.unmodifiable(result);
  }

  /// `location` es NOT NULL sin default; se valida aquí también (no solo en el wizard) para no depender únicamente de la UI.
  void _requireLocation(BusinessModel business) {
    if (business.latitude == null || business.longitude == null) {
      throw const BusinessServiceException(
        'Ingresa la latitud y longitud del negocio antes de guardar.',
      );
    }
  }

  /// Con [ownerId] es la lectura "mis negocios" (todos los estados); sin él
  /// es la lectura pública y solo devuelve aprobados.
  Future<List<Map<String, dynamic>>> _select({String? ownerId}) async {
    try {
      var query = _client.from('businesses').select();
      query = ownerId == null
          ? query.eq('status', ReviewStatus.aprobado.wireValue)
          : query.eq('owner_id', ownerId);
      final rows = await query.order('created_at');
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw BusinessServiceException(
        'No se pudieron cargar los negocios: ${e.message}',
      );
    } catch (_) {
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _selectInBounds({
    required double minLng,
    required double minLat,
    required double maxLng,
    required double maxLat,
  }) async {
    try {
      // `businesses_in_bounds` devuelve `setof public.businesses`, así que
      // PostgREST acepta filtros encadenados sobre su resultado igual que
      // sobre una tabla — el estado se filtra sin tocar la función SQL.
      final rows = await _client
          .rpc(
            'businesses_in_bounds',
            params: {
              'min_lng': minLng,
              'min_lat': minLat,
              'max_lng': maxLng,
              'max_lat': maxLat,
            },
          )
          .eq('status', ReviewStatus.aprobado.wireValue);
      return (rows as List<dynamic>).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw BusinessServiceException(
        'No se pudieron cargar los negocios: ${e.message}',
      );
    } catch (_) {
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
  }

  /// Columnas que pueden no existir todavía según qué migraciones ya corrió
  /// cada entorno: `schedules`/`facebook_handle` (018) y el lote de
  /// `021_business_extras_columns.sql` (amenities/activities/eco_*/
  /// access_details/other_notes/tiktok_handle). Se reintenta sin esas claves
  /// en vez de impedir que se registre un negocio: el resto de los datos sí
  /// se puede guardar.
  static const _softColumns = [
    'schedules',
    'facebook_handle',
    'amenities',
    'activities',
    'eco_seal_requested',
    'eco_practices',
    'access_details',
    'other_notes',
    'tiktok_handle',
  ];

  static bool _isMissingSoftColumn(PostgrestException e) =>
      (e.code == 'PGRST204' || e.code == '42703') &&
      _softColumns.any(e.message.contains);

  Future<void> _insertRow(Map<String, dynamic> row) async {
    try {
      await _client.from('businesses').insert(row);
    } on PostgrestException catch (e) {
      if (!_isMissingSoftColumn(e)) rethrow;
      await _client.from('businesses').insert(_withoutSoftColumns(row));
    }
  }

  /// El `.eq('owner_id', ...)` va en la misma sentencia que el `update`: es lo
  /// que impide editar el negocio de otra persona conociendo su id, y a
  /// diferencia de un `select` previo no deja ventana entre el chequeo y la
  /// escritura. `.select('id')` está para distinguir "no era tuyo" de "salió
  /// bien": sin él, PostgREST responde 200 aunque no haya tocado ninguna fila.
  Future<void> _updateRow(
    String id,
    String ownerId,
    Map<String, dynamic> row,
  ) async {
    List<dynamic> updated;
    try {
      updated = await _client
          .from('businesses')
          .update(row)
          .eq('id', id)
          .eq('owner_id', ownerId)
          .select('id');
    } on PostgrestException catch (e) {
      if (!_isMissingSoftColumn(e)) rethrow;
      updated = await _client
          .from('businesses')
          .update(_withoutSoftColumns(row))
          .eq('id', id)
          .eq('owner_id', ownerId)
          .select('id');
    }
    if (updated.isEmpty) {
      throw const BusinessServiceException(
        'No se pudo actualizar el negocio: ya no existe o no es tuyo.',
      );
    }
  }

  static Map<String, dynamic> _withoutSoftColumns(Map<String, dynamic> row) {
    final trimmed = Map<String, dynamic>.of(row);
    for (final column in _softColumns) {
      trimmed.remove(column);
    }
    return trimmed;
  }

  /// Solo las columnas de contenido: `id` y `owner_id` los agrega quien
  /// inserta, para que un update no pueda reescribirlos por accidente. El
  /// texto ya viene normalizado por [_sanitized].
  Map<String, dynamic> _toRow(BusinessModel b) {
    return {
      'name': b.name,
      'category': b.category,
      'description': b.description,
      'city': b.city,
      'address_text': b.locationText,
      // Formato EWKT que PostGIS interpreta directo; las coordenadas ya están garantizadas por _requireLocation.
      'location': 'SRID=4326;POINT(${b.longitude} ${b.latitude})',
      'phone': b.contactPhone,
      'instagram_handle': b.instagramLink,
      'facebook_handle': b.facebookLink,
      'tiktok_handle': b.tiktokLink,
      'schedules': b.schedules,
      'photos': b.localImagePaths,
      'amenities': b.amenities,
      'activities': b.activities,
      'eco_seal_requested': b.ecoSealRequested,
      'eco_practices': b.ecoPractices,
      'access_details': b.accessDetails,
      'other_notes': b.otherNotes,
      'logo_url': b.logoUrl,
      'show_host': b.showHost,
    };
  }

  /// Público para que otros servicios lo reutilicen con joins anidados de `businesses`, sin duplicar el parseo.
  BusinessModel businessFromRow(Map<String, dynamic> row) => _fromRow(row);

  BusinessModel _fromRow(Map<String, dynamic> row) {
    final rawLocation = row['location'];
    final point = _parseLocation(rawLocation);
    if (rawLocation != null && point == null) {
      // Se loguea porque un pin no parseado desaparece del mapa sin ningún error visible.
      debugPrint(
        '[BusinessStorageService] _fromRow("${row['name']}", '
        'id=${row['id']}): could not parse location, got '
        '${rawLocation.runtimeType}: $rawLocation',
      );
    }
    return BusinessModel(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      category: row['category'] as String? ?? '',
      description: row['description'] as String? ?? '',
      city: row['city'] as String? ?? '',
      locationText: row['address_text'] as String? ?? '',
      latitude: point?.$1,
      longitude: point?.$2,
      contactPhone: row['phone'] as String? ?? '',
      instagramLink: row['instagram_handle'] as String? ?? '',
      // Ausentes (no vacías) mientras no haya corrido la migración 018/021.
      facebookLink: row['facebook_handle'] as String? ?? '',
      tiktokLink: row['tiktok_handle'] as String? ?? '',
      schedules: row['schedules'] as String? ?? '',
      amenities:
          (row['amenities'] as List<dynamic>?)?.cast<String>() ?? const [],
      activities:
          (row['activities'] as List<dynamic>?)?.cast<String>() ?? const [],
      ecoSealRequested: row['eco_seal_requested'] as bool? ?? false,
      ecoPractices:
          (row['eco_practices'] as List<dynamic>?)?.cast<String>() ?? const [],
      accessDetails: row['access_details'] as String? ?? '',
      otherNotes: row['other_notes'] as String? ?? '',
      logoUrl: row['logo_url'] as String?,
      showHost: row['show_host'] as bool? ?? true,
      localImagePaths:
          (row['photos'] as List<dynamic>?)?.cast<String>() ?? const [],
      isVerified: row['is_verified'] as bool? ?? false,
      reviewStatus: ReviewStatus.fromWire(row['status']),
      rejectionReason: row['rejection_reason'] as String?,
      reviewedAt: DateTime.tryParse(row['reviewed_at'] as String? ?? ''),
      reviewedBy: row['reviewed_by'] as String?,
      // Sin columna aún (ver "Identidad del negocio" en la bóveda).
      hostName: '',
    );
  }

  /// Coincide con `POINT(lng lat)` en formato EWKT (con prefijo SRID) o WKT plano.
  static final RegExp _wktPointPattern = RegExp(
    r'POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)',
    caseSensitive: false,
  );

  /// Acepta GeoJSON, EWKT/WKT o hex WKB porque el formato de salida de `geography` en Postgres/PostgREST varía; el hex WKB es el default real de PostGIS y explica pines que se guardaban pero no aparecían en el mapa. Nunca fabrica coordenadas: si nada matchea, devuelve null.
  (double, double)? _parseLocation(dynamic raw) {
    if (raw is Map) {
      final coordinates = raw['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        final lng = (coordinates[0] as num?)?.toDouble();
        final lat = (coordinates[1] as num?)?.toDouble();
        if (lng != null && lat != null) return (lat, lng);
      }
      return null;
    }
    if (raw is String) {
      final match = _wktPointPattern.firstMatch(raw);
      if (match != null) {
        final lng = double.tryParse(match.group(1)!);
        final lat = double.tryParse(match.group(2)!);
        if (lng != null && lat != null) return (lat, lng);
      }
      return _parseWkbHexPoint(raw);
    }
    return null;
  }

  /// Decodifica WKB/EWKB hex (formato binario de PostGIS servido como texto ASCII por PostgREST): 1 byte orden + 4 bytes tipo/flags + SRID opcional + 8+8 bytes X/Y. Solo maneja puntos 2D; cualquier otra cosa devuelve null en vez de adivinar.
  (double, double)? _parseWkbHexPoint(String hex) {
    final trimmed = hex.trim();
    if (trimmed.isEmpty ||
        trimmed.length % 2 != 0 ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
      return null;
    }

    final bytes = Uint8List(trimmed.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      final byte = int.tryParse(trimmed.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      bytes[i] = byte;
    }
    if (bytes.length < 1 + 4 + 16) return null;

    final buffer = ByteData.sublistView(bytes);
    var offset = 0;
    final endian = bytes[offset] == 0 ? Endian.big : Endian.little;
    offset += 1;

    final typeAndFlags = buffer.getUint32(offset, endian);
    offset += 4;
    const wkbSridFlag = 0x20000000;
    if (typeAndFlags & 0xFF != 1) return null;
    if (typeAndFlags & wkbSridFlag != 0) {
      if (bytes.length < offset + 4 + 16) return null;
      offset += 4; // El SRID no se usa: esta columna siempre es 4326.
    }

    final lng = buffer.getFloat64(offset, endian);
    final lat = buffer.getFloat64(offset + 8, endian);
    return (lat, lng);
  }
}
