import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/features/map/domain/navigation_engine.dart';

/// Arrival is measured against the destination, never a shortened polyline.
/// A stale or inaccurate GPS fix must not award a destination's postcard.
class TripArrivalTracker {
  TripArrivalTracker({required this.destination, required this.startedAt});

  final LatLng destination;
  final DateTime startedAt;
  static const arrivalRadiusMeters = 75.0;
  static const maximumAccuracyMeters = 50.0;
  static const maximumFixAge = Duration(seconds: 30);
  bool _closed = false;

  DateTime? update(Position position, {required DateTime now}) {
    if (_closed ||
        position.isMocked ||
        now.isBefore(startedAt) ||
        position.timestamp.isBefore(startedAt) ||
        now.difference(position.timestamp) > maximumFixAge ||
        position.timestamp.difference(now) > const Duration(seconds: 5) ||
        !position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > maximumAccuracyMeters ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      return null;
    }
    final distance = metersBetween(
      destination,
      LatLng(position.latitude, position.longitude),
    );
    if (distance > arrivalRadiusMeters) return null;
    _closed = true;
    return now.toUtc();
  }

  void cancel() => _closed = true;
}
