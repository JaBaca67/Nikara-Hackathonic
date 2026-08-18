import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Meters still to drive along [routePoints] from wherever [current] is —
/// what the navigation panel's "3.4 km restantes" readout shows.
///
/// Snaps [current] to the nearest vertex of the route polyline and adds up
/// the segments from there to the destination. Vertex-level (not
/// perpendicular projection onto each segment) precision is deliberate:
/// the Directions API's `overview_polyline` is already a simplified
/// geometry, so a sub-vertex-accurate distance would be false precision
/// for a readout rounded to one decimal of a kilometer.
///
/// Returns 0 when the route has fewer than two points.
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

  // Distance off-route (nearestDistance) counts too — otherwise a driver
  // who strayed 800 m from the polyline would see the same "restantes" as
  // one sitting exactly on it.
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

/// Index of the route vertex nearest to [current], never earlier than
/// [minIndex] — the monotonic building block behind [MapScreen]'s dynamic
/// route trimming (drawing the golden `Polyline` only for the stretch
/// still ahead of the vehicle). Passing the previous call's result back in
/// as [minIndex] keeps the search forward-only, so a moment of GPS jitter
/// can never snap the trim point back to an already-driven vertex and make
/// a passed stretch of the line reappear.
///
/// Returns `0` for an empty [routePoints].
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
