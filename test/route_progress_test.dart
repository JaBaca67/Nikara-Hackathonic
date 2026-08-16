import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/features/map/domain/route_progress.dart';

/// Pure math, no Supabase/SharedPreferences bootstrap needed — this is the
/// "3,4 km restantes" readout in the map's navigation panel (Estado 19c).
void main() {
  // ~1.11 km per 0.01° of latitude at the equator; Nicaragua is close
  // enough to it that these stay accurate within a few meters.
  const start = LatLng(12.10, -86.25);
  const middle = LatLng(12.11, -86.25);
  const end = LatLng(12.12, -86.25);
  const route = [start, middle, end];

  test('al inicio de la ruta falta prácticamente toda la distancia', () {
    final meters = remainingRouteMeters(routePoints: route, current: start);
    expect(meters, closeTo(2212, 30));
  });

  test('a mitad de camino falta aproximadamente la mitad', () {
    final meters = remainingRouteMeters(routePoints: route, current: middle);
    expect(meters, closeTo(1106, 30));
  });

  test('en el destino no falta nada', () {
    final meters = remainingRouteMeters(routePoints: route, current: end);
    expect(meters, closeTo(0, 1));
  });

  test('la distancia fuera de la ruta también cuenta', () {
    // Same latitude as the destination, but ~1 km off to the side.
    const strayed = LatLng(12.12, -86.24);
    final meters = remainingRouteMeters(routePoints: route, current: strayed);
    expect(meters, greaterThan(900));
  });

  test('una ruta sin tramos devuelve cero en vez de fallar', () {
    expect(remainingRouteMeters(routePoints: const [], current: start), 0);
    expect(remainingRouteMeters(routePoints: const [start], current: start), 0);
  });
}
