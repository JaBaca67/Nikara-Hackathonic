import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';

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

/// Completed GPS trips, stored on this device in a separate key per account.
/// Snapshots preserve the postcard and its original seal after business edits.
class PassportService {
  factory PassportService() => instance;
  PassportService._internal()
    : _currentUserId = (() => AuthService().currentAuthUser?.id),
      _onProgress = ((ownerId, collection) =>
          NotificationService().syncPassportProgress(
            ownerId: ownerId,
            trips: collection.notificationTrips,
          ));
  @visibleForTesting
  PassportService.forTesting(this._currentUserId, [this._onProgress]);

  static final instance = PassportService._internal();
  static final revision = ValueNotifier<int>(0);
  static final openRequested = ValueNotifier<bool>(false);
  final String? Function() _currentUserId;
  final Future<void> Function(String, PassportCollection)? _onProgress;
  Future<void> _writeQueue = Future.value();
  static String _key(String ownerId) => 'completed_business_trips_v1_$ownerId';

  Future<PassportCollection> getCollection() async {
    final ownerId = _currentUserId();
    if (ownerId == null) return const PassportCollection([]);
    try {
      final prefs = await SharedPreferences.getInstance();
      final collection = _read(prefs, ownerId);
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

  PassportCollection _read(SharedPreferences prefs, String ownerId) {
    final raw = prefs.getString(_key(ownerId));
    if (raw == null) return const PassportCollection([]);
    final rows = jsonDecode(raw) as List<dynamic>;
    return PassportCollection(
      List.unmodifiable(
        rows.map(
          (row) => CompletedPassportTrip.fromJson(row as Map<String, dynamic>),
        ),
      ),
    );
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
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId() != ownerId) {
        throw const PassportServiceException('La cuenta del viaje cambió.');
      }
      final current = _read(prefs, ownerId);
      final previous = current.trips
          .where((trip) => trip.id == tripId)
          .firstOrNull;
      if (previous != null) {
        return current.postcards.firstWhere(
          (card) => card.id == previous.postcard.id,
        );
      }
      final trip = CompletedPassportTrip(
        id: tripId,
        startedAt: startedAt,
        postcard: TravelPostcard.fromBusiness(business, sealedAt: completedAt),
      );
      final updated = PassportCollection([...current.trips, trip]);
      final saved = await prefs.setString(
        _key(ownerId),
        jsonEncode(updated.trips.map((t) => t.toJson()).toList()),
      );
      if (!saved) {
        throw const PassportServiceException(
          'No se pudo guardar la postal. Intenta de nuevo.',
        );
      }
      revision.value++;
      unawaited(_publishProgress(ownerId, updated));
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
