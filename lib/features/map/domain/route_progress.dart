/// Cálculos sueltos de progreso sobre una polilínea.
///
/// La navegación en vivo NO pasa por acá: usa [NavigationEngine], que mantiene
/// estado entre fixes (índice monotónico, umbrales de voz, ETA por tramos).
/// Esto queda como utilidad sin estado para cualquier caller que solo necesite
/// "cuánto falta desde este punto" sin montar un motor completo.
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/features/map/domain/navigation_engine.dart';

/// Metros restantes por recorrer en [routePoints] desde [current].
///
/// Proyecta sobre el **segmento** más cercano, no sobre el vértice más cercano.
/// La versión anterior usaba el vértice y lo justificaba con que la geometría
/// venía del `overview_polyline` simplificado — hoy la ruta llega en resolución
/// completa (ver [DirectionsRoute.points]), así que la proyección real sí aporta
/// precisión en vez de fingirla.
///
/// Devuelve 0 si la ruta tiene menos de dos puntos.
double remainingRouteMeters({
  required List<LatLng> routePoints,
  required LatLng current,
}) {
  if (routePoints.length < 2) return 0;
  final geometry = RouteGeometry(routePoints);
  final projection = geometry.project(current);
  if (projection == null) return 0;
  // La distancia fuera de ruta también cuenta: un conductor desviado 800 m no
  // debería ver el mismo "restantes" que uno parado sobre la polilínea.
  return geometry.totalMeters -
      projection.traveledMeters +
      projection.lateralMeters;
}

/// Índice del vértice de ruta más cercano a [current], nunca antes de
/// [minIndex] — búsqueda solo-hacia-adelante para que el jitter del GPS no
/// retroceda el recorte de la polilínea a un tramo ya recorrido.
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
    final distance = metersBetween(current, routePoints[i]);
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = i;
    }
  }
  return nearestIndex;
}
