import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Metros restantes por recorrer en [routePoints] desde [current], para el "X km restantes" del panel de navegación.
///
/// Ajusta [current] al vértice más cercano de la polilínea (no proyección perpendicular por segmento) porque el `overview_polyline` de la Directions API ya es una geometría simplificada, así que mayor precisión sería falsa.
///
/// Devuelve 0 si la ruta tiene menos de dos puntos.
double remainingRouteMeters({
  required List<LatLng> routePoints,
  required LatLng current,
}) {
  if (routePoints.length < 2) return 0;

  var nearestIndex = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < routePoints.length; i++) {
    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      routePoints[i].latitude,
      routePoints[i].longitude,
    );
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = i;
    }
  }

  // La distancia fuera de ruta (nearestDistance) también cuenta, si no un conductor desviado 800 m vería el mismo "restantes" que uno sobre la polilínea.
  var meters = nearestDistance;
  for (var i = nearestIndex; i < routePoints.length - 1; i++) {
    meters += Geolocator.distanceBetween(
      routePoints[i].latitude,
      routePoints[i].longitude,
      routePoints[i + 1].latitude,
      routePoints[i + 1].longitude,
    );
  }
  return meters;
}

/// Índice del vértice de ruta más cercano a [current], nunca antes de [minIndex]: pasar el resultado de la llamada anterior como [minIndex] hace la búsqueda solo-hacia-adelante, para que el GPS jitter no retroceda el recorte de la polilínea a un tramo ya recorrido.
///
/// Devuelve `0` si [routePoints] está vacío.
int nearestRouteIndex({
  required List<LatLng> routePoints,
  required LatLng current,
  int minIndex = 0,
}) {
  if (routePoints.isEmpty) return 0;
  final start = minIndex.clamp(0, routePoints.length - 1);
  var nearestIndex = start;
  var nearestDistance = double.infinity;
  for (var i = start; i < routePoints.length; i++) {
    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      routePoints[i].latitude,
      routePoints[i].longitude,
    );
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = i;
    }
  }
  return nearestIndex;
}
