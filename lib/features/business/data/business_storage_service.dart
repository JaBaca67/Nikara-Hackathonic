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

/// Persists [BusinessModel]s to Supabase's `businesses` table — the real
/// source of truth for `id`, `owner_id`, `name`, `category`, `description`,
/// `city`, `address_text`, `location` (PostGIS geography point), `phone`,
/// `instagram_handle` and `photos`.
///
/// That table has no column for `price`, `allowsReservations`, `amenities`,
/// `activities`, `facebookLink`, `socialMediaLink`, `schedules`,
/// `accessDetails`, `otherNotes` or reviews — the wizard still collects all
/// of these, so dropping them on save would silently discard what the
/// owner just typed. Those fields are cached locally (SharedPreferences,
/// keyed by business id) and merged back onto every business fetched from
/// Supabase. This is a deliberate, transparent trade-off for a partial
/// backend migration, not a bug: those fields only round-trip on the
/// device that saved them until the schema grows columns for them.
class BusinessStorageService {
  static const _localExtrasKey = 'business_local_extras_json';

  /// Bumped on every write (add/update/delete/review). Screens listen to
  /// this the same way they listen to [FavoritesService]'s notifier so
  /// e.g. ProfileScreen's "Mis Negocios" stays live without a restart.
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

  /// Only businesses whose `location` falls inside the given lng/lat box —
  /// via the `businesses_in_bounds` RPC (see
  /// supabase/sql/007_businesses_in_bounds_rpc.sql), which uses the GiST
  /// index on `location` instead of downloading and filtering the whole
  /// table. [MapScreen] calls this on every camera-idle instead of
  /// [getBusinesses] so panning/zooming only ever fetches what's actually
  /// visible.
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

  /// Subscribes to Postgres INSERT/UPDATE/DELETE on `businesses` and calls
  /// [onChange] for each one — how [MapScreen] picks up a business someone
  /// else registered without the user having to reopen the screen.
  /// [revision] covers changes made by this device; this covers the rest.
  ///
  /// The callback carries no payload on purpose: every listener re-queries
  /// through the normal path afterwards, so a row arriving here never
  /// bypasses the local-extras merge [getBusinesses] does.
  ///
  /// Silent by design if Realtime isn't enabled for the table (see
  /// supabase/sql/008_businesses_realtime.sql): the channel subscribes
  /// fine, no events ever arrive, and the app keeps working off its normal
  /// fetches.
  ///
  /// Returns the "stop listening" callback to call on dispose — a plain
  /// closure rather than the [RealtimeChannel] itself so screens never have
  /// to import Supabase types just to unsubscribe.
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

  /// Distinct `category` values across every business — deliberately not
  /// scoped to the map viewport (unlike [getBusinessesInBounds]) so the
  /// category chips stay stable as the user pans instead of changing
  /// depending on what's currently on screen. Only pulls the `category`
  /// column, so it stays cheap even as the table grows.
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

  /// Reviews have no table in Supabase yet, so this only touches the local
  /// extras cache — [business] is the caller's current in-memory copy
  /// (already has the real core fields), so no extra network round-trip is
  /// needed just to attach a review to it.
  Future<void> addReview(BusinessModel business, ReviewModel review) async {
    await _writeLocalExtra(
      business.copyWith(reviews: [...business.reviews, review]),
    );
    revision.value++;
  }

  /// `businesses.owner_id` is a Postgres uuid column — an empty string
  /// fails at the database with "invalid input syntax for type uuid: ''"
  /// instead of a readable error. Catch that here, before the request ever
  /// leaves the device.
  void _requireOwnerId(BusinessModel business) {
    if (business.ownerId.trim().isEmpty) {
      throw const BusinessServiceException(
        'No se pudo identificar al propietario del negocio. Inicia sesión '
        'de nuevo e intenta otra vez.',
      );
    }
  }

  /// `businesses.location` is a NOT NULL `geography(Point,4326)` column with
  /// no default — omitting it (which happened whenever the wizard's
  /// lat/lng fields were left blank) fails at the database with "null
  /// value in column 'location' ... violates not-null constraint". The
  /// wizard now requires real coordinates before it lets the user finish,
  /// but this check guards the invariant here too, independent of the UI.
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
      // EWKT text — PostGIS parses this directly for a geography(Point,4326)
      // column. Always present by this point: _requireLocation already
      // rejected the call above if either coordinate was missing.
      'location': 'SRID=4326;POINT(${b.longitude} ${b.latitude})',
      'phone': b.contactPhone,
      'instagram_handle': b.instagramLink,
      'photos': b.localImagePaths,
    };
  }

  /// Parses a raw `businesses` row into a [BusinessModel] — public so other
  /// services can reuse it when Supabase returns a nested `businesses`
  /// object via a foreign-table join, instead of duplicating this parsing
  /// logic.
  BusinessModel businessFromRow(Map<String, dynamic> row) => _fromRow(row);

  BusinessModel _fromRow(Map<String, dynamic> row) {
    final rawLocation = row['location'];
    final point = _parseLocation(rawLocation);
    if (rawLocation != null && point == null) {
      // Never silently drop a pin — this is exactly what makes a saved
      // business fail to show up on the map with no visible error, so it's
      // worth a log even outside the addBusiness/updateBusiness path.
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
      // No column for these — real defaults, not placeholders; the local
      // extras merge (see getBusinesses) fills them back in when available.
      allowsReservations: false,
      hostName: '',
    );
  }

  /// Regex for `POINT(lng lat)`, with or without a leading `SRID=4326;`
  /// prefix — matches both `SRID=4326;POINT(-86.2513 12.1363)` (EWKT) and
  /// plain `POINT(-86.2513 12.1363)` (WKT).
  static final RegExp _wktPointPattern = RegExp(
    r'POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)',
    caseSensitive: false,
  );

  /// Parses the `location` geography column into (lat, lng) — accepts
  /// every shape Postgres/PostgREST can plausibly hand back for a
  /// `geography(Point,4326)` column, since which one actually shows up
  /// depends on how the value round-trips through Postgres' own output
  /// function, not on anything this app controls:
  ///
  ///  - GeoJSON (`{"type":"Point","coordinates":[lng,lat]}`) — what a
  ///    `select` wrapping the column in `ST_AsGeoJSON` would return.
  ///  - EWKT/WKT text (`SRID=4326;POINT(lng lat)` or plain `POINT(lng lat)`)
  ///    — what this app's own `_toRow` writes, and what some PostgREST
  ///    setups also read back.
  ///  - Hex-encoded (E)WKB (e.g. `0101000020E6100000...`) — PostGIS's
  ///    *default* text output for `geometry`/`geography` columns
  ///    (`geography_out`) is actually hex EWKB, not WKT, so a plain
  ///    `select location` with no `ST_AsText`/`ST_AsGeoJSON` wrapper comes
  ///    back in this form. Any business whose pin silently never appeared
  ///    on the map despite saving without error was almost certainly hitting
  ///    this exact case — the two branches above simply had nothing to
  ///    match against.
  ///
  /// Falls back to null coordinates (never fabricated) if none of the three
  /// shapes matches — see [_fromRow]'s log right before this is called.
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

  /// Decodes a hex-encoded WKB/EWKB `POINT` — the raw binary format PostGIS
  /// writes to over the wire, given as ASCII hex text (2 chars/byte) by
  /// PostgREST. Layout (see the OGC WKB spec + PostGIS's EWKB extension):
  ///
  ///   [1 byte byte-order][4 bytes type+flags][4 bytes SRID if flagged]
  ///   [8 bytes X][8 bytes Y]
  ///
  /// `type & 0xFF` is the base geometry type (1 == Point); bit `0x20000000`
  /// on the type flags whether an SRID follows. Only 2D points are handled
  /// (Z/M points never come out of this column — see `_toRow`) — anything
  /// else, or a string that isn't valid hex, returns null rather than
  /// guessing.
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
    // Byte order + type/flags + (optional) SRID + X + Y.
    if (bytes.length < 1 + 4 + 16) return null;

    final buffer = ByteData.sublistView(bytes);
    var offset = 0;
    final endian = bytes[offset] == 0 ? Endian.big : Endian.little;
    offset += 1;

    final typeAndFlags = buffer.getUint32(offset, endian);
    offset += 4;
    const wkbSridFlag = 0x20000000;
    if (typeAndFlags & 0xFF != 1) return null; // Not a Point.
    if (typeAndFlags & wkbSridFlag != 0) {
      if (bytes.length < offset + 4 + 16) return null;
      offset += 4; // SRID itself is unused — this column is always 4326.
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
