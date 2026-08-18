import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';

class BusinessServiceException implements Exception {
  const BusinessServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Persiste [BusinessModel] en la tabla `businesses` de Supabase.
///
/// La tabla aún no tiene columnas para price/amenities/activities/schedules/
/// etc.; esos campos se cachean en SharedPreferences y se fusionan al leer —
/// trade-off deliberado de una migración parcial de backend, no un bug.
class BusinessStorageService {
  static const _localExtrasKey = 'business_local_extras_json';

  /// Se incrementa en cada escritura para que pantallas como "Mis Negocios" se refresquen sin reiniciar.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<BusinessModel>> getBusinesses() async {
    final rows = await _select();
    final localExtras = await _readLocalExtras();
    return rows
        .map((row) {
          final core = _fromRow(row);
          final cached = localExtras[core.id];
          return cached == null ? core : _mergeExtras(core, cached);
        })
        .toList(growable: false);
  }

  /// Usa el RPC `businesses_in_bounds` (índice GiST) para traer solo lo visible en el mapa, sin descargar toda la tabla en cada pan/zoom.
  Future<List<BusinessModel>> getBusinessesInBounds({
    required double minLng,
    required double minLat,
    required double maxLng,
    required double maxLat,
  }) async {
    final rows = await _selectInBounds(
      minLng: minLng,
      minLat: minLat,
      maxLng: maxLng,
      maxLat: maxLat,
    );
    final localExtras = await _readLocalExtras();
    return rows
        .map((row) {
          final core = _fromRow(row);
          final cached = localExtras[core.id];
          return cached == null ? core : _mergeExtras(core, cached);
        })
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
      final rows = await _client.from('businesses').select('category');
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

  Future<void> addBusiness(BusinessModel business) async {
    _requireOwnerId(business);
    _requireLocation(business);
    final row = _toRow(business, includeId: true);
    debugPrint(
      '[BusinessStorageService] addBusiness("${business.name}") '
      'lat=${business.latitude} lng=${business.longitude} '
      'location="${row['location']}"',
    );
    try {
      await _client.from('businesses').insert(row);
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
    await _writeLocalExtra(business);
    revision.value++;
  }

  Future<void> updateBusiness(BusinessModel business) async {
    _requireOwnerId(business);
    _requireLocation(business);
    final row = _toRow(business, includeId: false);
    debugPrint(
      '[BusinessStorageService] updateBusiness("${business.name}", '
      'id=${business.id}) lat=${business.latitude} lng=${business.longitude} '
      'location="${row['location']}"',
    );
    try {
      await _client.from('businesses').update(row).eq('id', business.id);
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
    } catch (e) {
      debugPrint(
        '[BusinessStorageService] updateBusiness("${business.name}") -> '
        'unexpected error: $e',
      );
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    await _writeLocalExtra(business);
    revision.value++;
  }

  Future<void> deleteBusiness(String id) async {
    try {
      await _client.from('businesses').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw BusinessServiceException(
        'No se pudo eliminar el negocio: ${e.message}',
      );
    } catch (_) {
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    await _removeLocalExtra(id);
    revision.value++;
  }

  /// Las reseñas no tienen tabla en Supabase todavía; solo se guardan en el cache local de extras.
  Future<void> addReview(BusinessModel business, ReviewModel review) async {
    await _writeLocalExtra(
      business.copyWith(reviews: [...business.reviews, review]),
    );
    revision.value++;
  }

  /// `owner_id` es uuid en Postgres; un string vacío falla con un error críptico en la base, así que se valida antes de enviar la petición.
  void _requireOwnerId(BusinessModel business) {
    if (business.ownerId.trim().isEmpty) {
      throw const BusinessServiceException(
        'No se pudo identificar al propietario del negocio. Inicia sesión '
        'de nuevo e intenta otra vez.',
      );
    }
  }

  /// `location` es NOT NULL sin default; se valida aquí también (no solo en el wizard) para no depender únicamente de la UI.
  void _requireLocation(BusinessModel business) {
    if (business.latitude == null || business.longitude == null) {
      throw const BusinessServiceException(
        'Ingresa la latitud y longitud del negocio antes de guardar.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _select() async {
    try {
      final rows = await _client
          .from('businesses')
          .select()
          .order('created_at');
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
      final rows = await _client.rpc(
        'businesses_in_bounds',
        params: {
          'min_lng': minLng,
          'min_lat': minLat,
          'max_lng': maxLng,
          'max_lat': maxLat,
        },
      );
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

  BusinessModel _mergeExtras(BusinessModel core, BusinessModel cached) {
    return core.copyWith(
      allowsReservations: cached.allowsReservations,
      price: cached.price,
      amenities: cached.amenities,
      activities: cached.activities,
      ecoSealRequested: cached.ecoSealRequested,
      ecoPractices: cached.ecoPractices,
      facebookLink: cached.facebookLink,
      socialMediaLink: cached.socialMediaLink,
      schedules: cached.schedules,
      accessDetails: cached.accessDetails,
      otherNotes: cached.otherNotes,
      reviews: cached.reviews,
    );
  }

  Map<String, dynamic> _toRow(BusinessModel b, {required bool includeId}) {
    return {
      if (includeId) 'id': b.id,
      'owner_id': b.ownerId,
      'name': b.name,
      'category': b.category,
      'description': b.description,
      'city': b.city,
      'address_text': b.locationText,
      // Formato EWKT que PostGIS interpreta directo; las coordenadas ya están garantizadas por _requireLocation.
      'location': 'SRID=4326;POINT(${b.longitude} ${b.latitude})',
      'phone': b.contactPhone,
      'instagram_handle': b.instagramLink,
      'photos': b.localImagePaths,
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
      localImagePaths:
          (row['photos'] as List<dynamic>?)?.cast<String>() ?? const [],
      isVerified: row['is_verified'] as bool? ?? false,
      // Sin columna aún; son defaults reales que el merge de extras locales sobrescribe si hay cache.
      allowsReservations: false,
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

  Future<Map<String, BusinessModel>> _readLocalExtras() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localExtrasKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as List<dynamic>;
    final list = decoded
        .map((e) => BusinessModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return {for (final b in list) b.id: b};
  }

  Future<void> _writeLocalExtra(BusinessModel business) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await _readLocalExtras();
    cache[business.id] = business;
    await prefs.setString(
      _localExtrasKey,
      jsonEncode(cache.values.map((b) => b.toJson()).toList()),
    );
  }

  Future<void> _removeLocalExtra(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await _readLocalExtras();
    cache.remove(id);
    await prefs.setString(
      _localExtrasKey,
      jsonEncode(cache.values.map((b) => b.toJson()).toList()),
    );
  }
}
