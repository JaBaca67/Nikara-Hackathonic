import 'package:geolocator/geolocator.dart';

/// Best-effort device location, shared across Home/Map so only one of them
/// ever has to prompt for permission — whichever screen asks first caches
/// the result for the other. Every failure mode (services off, permission
/// denied/forever-denied, a mid-flight error) resolves to `null` rather
/// than throwing, matching the same silent-fallback behavior MapScreen's
/// recenter button already used before this was extracted.
class LocationService {
  factory LocationService() => instance;

  LocationService._internal();

  static final LocationService instance = LocationService._internal();

  Position? _cached;

  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    if (_cached != null && !forceRefresh) return _cached;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      _cached = position;
      return position;
    } catch (_) {
      return null;
    }
  }

  /// Straight-line distance in kilometers between [from] and
  /// ([lat], [lng]) — `null` whenever any of the three is unavailable, so
  /// callers can fall back to showing just the city/department instead.
  static double? distanceKm(Position? from, double? lat, double? lng) {
    if (from == null || lat == null || lng == null) return null;
    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      lat,
      lng,
    );
    return meters / 1000;
  }
}
