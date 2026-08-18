import 'package:geolocator/geolocator.dart';

/// Ubicación del dispositivo, cacheada entre Home/Map para que solo una pantalla pida permiso; cualquier falla resuelve a `null` en vez de lanzar.
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

  /// Distancia en línea recta en km; `null` si falta algún dato, para que el caller muestre solo ciudad/departamento.
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
