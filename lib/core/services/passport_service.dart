import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nikara_app/core/services/remote_user_data_service.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';

class PassportServiceException implements Exception {
  const PassportServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

@immutable
class CompletedPassportTrip {
  const CompletedPassportTrip({
    required this.id,
    required this.startedAt,
    required this.postcard,
  });
  final String id;
  final DateTime startedAt;
  final TravelPostcard postcard;

  Map<String, dynamic> toJson() => {
    'id': id,
    'started_at': startedAt.toUtc().toIso8601String(),
    'postcard': postcard.toJson(),
  };

  factory CompletedPassportTrip.fromJson(Map<String, dynamic> json) =>
      CompletedPassportTrip(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        postcard: TravelPostcard.fromJson(
          json['postcard'] as Map<String, dynamic>,
        ),
      );
}

@immutable
class PassportCollection {
  const PassportCollection(this.trips);
  final List<CompletedPassportTrip> trips;

  List<Map<String, dynamic>> get notificationTrips => [
    for (final trip in trips)
      {
        'trip_id': trip.id,
        'business_id': trip.postcard.id,
        'started_at': trip.startedAt.toUtc().toIso8601String(),
        'completed_at': trip.postcard.sealedAt!.toUtc().toIso8601String(),
      },
  ];

  /// Repeated visits count as trips but preserve the first seal of a business.
  List<TravelPostcard> get postcards {
    final byBusiness = <String, TravelPostcard>{};
    for (final trip in trips) {
      final existing = byBusiness[trip.postcard.id];
      if (existing == null ||
          trip.postcard.sealedAt!.isBefore(existing.sealedAt!)) {
        byBusiness[trip.postcard.id] = trip.postcard;
      }
    }
    return byBusiness.values.toList()
      ..sort((a, b) => b.sealedAt!.compareTo(a.sealedAt!));
  }
}

/// Completed trips and postcard snapshots are private rows in Supabase.
class PassportService {
  factory PassportService() => instance;
  PassportService._internal()
    : _remote = RemoteUserDataService(),
      _currentUserId = (() => AuthService().currentAuthUser?.id),
      _onProgress = null;
  @visibleForTesting
  PassportService.forTesting(
    this._currentUserId, [
    this._onProgress,
    SupabaseClient? client,
  ]) : _remote = RemoteUserDataService(client: client);

  static final instance = PassportService._internal();
  static final revision = ValueNotifier<int>(0);
  static final openRequested = ValueNotifier<bool>(false);
  final String? Function() _currentUserId;
  final RemoteUserDataService _remote;
  final Future<void> Function(String, PassportCollection)? _onProgress;
  Future<void> _writeQueue = Future.value();

  Future<PassportCollection> getCollection() async {
    final ownerId = _currentUserId();
    if (ownerId == null) return const PassportCollection([]);
    try {
      final rows = await _remote.client
          .from('passport_trips')
          .select('trip_id,started_at,postcard')
          .eq('user_id', ownerId)
          .order('completed_at');
      final collection = PassportCollection(
        List.unmodifiable(
          rows.map(
            (row) => CompletedPassportTrip.fromJson({
              'id': row['trip_id'],
              'started_at': row['started_at'],
              'postcard': row['postcard'],
            }),
          ),
        ),
      );
      // An account switch during the read must not expose the prior collection.
      return _currentUserId() == ownerId
          ? collection
          : const PassportCollection([]);
    } catch (_) {
      throw const PassportServiceException(
        'No se pudo leer tu pasaporte. Intenta de nuevo.',
      );
    }
  }

  Future<TravelPostcard> recordCompletedTrip({
    required String tripId,
    required String ownerId,
    required BusinessModel business,
    required DateTime startedAt,
    required DateTime completedAt,
  }) {
    final write = _writeQueue.then(
      (_) => _record(
        tripId: tripId,
        ownerId: ownerId,
        business: business,
        startedAt: startedAt,
        completedAt: completedAt,
      ),
    );
    // The caller receives write errors; only the serialization queue recovers.
    _writeQueue = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return write;
  }

  Future<TravelPostcard> _record({
    required String tripId,
    required String ownerId,
    required BusinessModel business,
    required DateTime startedAt,
    required DateTime completedAt,
  }) async {
    if (_currentUserId() != ownerId || ownerId.isEmpty) {
      throw const PassportServiceException(
        'La cuenta del viaje cambió. No se pudo sellar la postal.',
      );
    }
    if (tripId.isEmpty ||
        completedAt.isBefore(startedAt) ||
        business.latitude == null ||
        business.longitude == null ||
        business.reviewStatus != ReviewStatus.aprobado) {
      throw const PassportServiceException(
        'No se pudo confirmar el destino de este viaje.',
      );
    }
    try {
      final inserted = await _remote.client.rpc(
        'record_passport_trip',
        params: {
          'p_trip_id': tripId,
          'p_business_id': business.id,
          'p_started_at': startedAt.toUtc().toIso8601String(),
          'p_completed_at': completedAt.toUtc().toIso8601String(),
        },
      );
      if (_currentUserId() != ownerId) {
        throw const PassportServiceException('La cuenta del viaje cambió.');
      }
      final updated = await getCollection();
      revision.value++;
      if (inserted == true) unawaited(_publishProgress(ownerId, updated));
      return updated.postcards.firstWhere((card) => card.id == business.id);
    } on PassportServiceException {
      rethrow;
    } catch (_) {
      throw const PassportServiceException(
        'No se pudo guardar la postal. Intenta de nuevo.',
      );
    }
  }

  Future<void> _publishProgress(
    String ownerId,
    PassportCollection collection,
  ) async {
    if (_currentUserId() != ownerId) return;
    try {
      await _onProgress?.call(ownerId, collection);
    } catch (e) {
      debugPrint(
        '[PassportService] No se pudieron enviar los avisos del viaje: $e',
      );
    }
  }
}
