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
    return rows.map((row) {
      final core = _fromRow(row);
      final cached = localExtras[core.id];
      return cached == null ? core : _mergeExtras(core, cached);
    }).toList(growable: false);
  }

  Future<void> addBusiness(BusinessModel business) async {
    try {
      await _client.from('businesses').insert(_toRow(business, includeId: true));
    } on PostgrestException catch (e) {
      throw BusinessServiceException('No se pudo guardar el negocio: ${e.message}');
    } catch (_) {
      throw const BusinessServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    await _writeLocalExtra(business);
    revision.value++;
  }

  Future<void> updateBusiness(BusinessModel business) async {
    try {
      await _client
          .from('businesses')
          .update(_toRow(business, includeId: false))
          .eq('id', business.id);
    } on PostgrestException catch (e) {
      throw BusinessServiceException(
        'No se pudo actualizar el negocio: ${e.message}',
      );
    } catch (_) {
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

  Future<List<Map<String, dynamic>>> _select() async {
    try {
      final rows = await _client.from('businesses').select().order('created_at');
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
      // column. Only sent when the wizard actually collected coordinates;
      // never a fabricated point.
      if (b.latitude != null && b.longitude != null)
        'location': 'SRID=4326;POINT(${b.longitude} ${b.latitude})',
      'phone': b.contactPhone,
      'instagram_handle': b.instagramLink,
      'photos': b.localImagePaths,
    };
  }

  BusinessModel _fromRow(Map<String, dynamic> row) {
    final point = _parseLocation(row['location']);
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
      // No column for these — real defaults, not placeholders; the local
      // extras merge (see getBusinesses) fills them back in when available.
      allowsReservations: false,
      hostName: '',
    );
  }

  /// Best-effort GeoJSON point parser for the `location` geography column
  /// — `{"type":"Point","coordinates":[lng,lat]}` is Supabase/PostgREST's
  /// common wire format for PostGIS geography. Falls back to null
  /// coordinates (never fabricated) if the shape doesn't match, since this
  /// project's exact PostgREST config can't be verified from here — it may
  /// return raw EWKB hex instead, which would need a real WKB parser.
  (double, double)? _parseLocation(dynamic raw) {
    if (raw is Map) {
      final coordinates = raw['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        final lng = (coordinates[0] as num?)?.toDouble();
        final lat = (coordinates[1] as num?)?.toDouble();
        if (lng != null && lat != null) return (lat, lng);
      }
    }
    return null;
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