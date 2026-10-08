import 'package:geolocator/geolocator.dart';

/// Ubicación del dispositivo, cacheada entre Home/Map para que solo una pantalla pida permiso; cualquier falla resuelve a `null` en vez de lanzar.
class LocationService {
  factory LocationService() => instance;

  LocationService._internal();

  static final LocationService instance = LocationService._internal();

  Position? _cached;
  DateTime? _cachedAt;
  Future<Position?>? _pending;
  static const cacheLifetime = Duration(minutes: 2);

  Future<Position?> getCurrentPosition({
    bool forceRefresh = false,
    bool requestPermission = true,
  }) async {
    if (_pending case final pending?) return pending;
    final pending = _getPosition(
      forceRefresh: forceRefresh,
      requestPermission: requestPermission,
    );
    _pending = pending;
    try {
      return await pending;
    } finally {
      _pending = null;
    }
  }

  Future<Position?> _getPosition({
    required bool forceRefresh,
    required bool requestPermission,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _cached = null;
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _cached = null;
        return null;
      }

      if (!forceRefresh &&
          _cached != null &&
          _cachedAt != null &&
          DateTime.now().difference(_cachedAt!) < cacheLifetime &&
          isUsablePosition(_cached!)) {
        return _cached;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!isUsablePosition(position)) {
        _cached = null;
        return null;
      }
      _cached = position;
      _cachedAt = DateTime.now();
      return position;
    } catch (_) {
      _cached = null;
      return null;
    }
  }

  /// Distancia en línea recta en km; `null` si falta algún dato, para que el caller muestre solo ciudad/departamento.
  static double? distanceKm(Position? from, double? lat, double? lng) {
    if (from == null ||
        lat == null ||
        lng == null ||
        !validCoordinates(from.latitude, from.longitude) ||
        !validCoordinates(lat, lng)) {
      return null;
    }
    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      lat,
      lng,
    );
    return meters / 1000;
  }

  static bool validCoordinates(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;

  static bool isUsablePosition(Position position) =>
      validCoordinates(position.latitude, position.longitude) &&
      position.accuracy.isFinite &&
      position.accuracy >= 0 &&
      position.accuracy <= 1000 &&
      DateTime.now().difference(position.timestamp).abs() <= cacheLifetime;
}
