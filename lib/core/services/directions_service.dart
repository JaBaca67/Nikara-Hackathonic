import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:nikara_app/core/config/maps_config.dart';

class DirectionsServiceException implements Exception {
  const DirectionsServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A driving route between two points, decoded from the Google Directions
/// API's `overview_polyline` — enough for [MapScreen]'s "Cómo llegar" to
/// draw a real route (not just a straight line) and show an ETA/distance.
class DirectionsRoute {
  const DirectionsRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  double get distanceKm => distanceMeters / 1000;

  String get formattedDuration => formatDuration(durationSeconds);

  /// Static so the live navigation panel can format a *remaining* ETA
  /// (recomputed from how much of the route is left) with the exact same
  /// "12 min" / "1 h 5 min" shape as this route's total.
  static String formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }
}

/// Calls the Google Directions API directly from the client using
/// [MapsConfig.directionsApiKey] — see that class's doc comment for the
/// setup this needs (a Cloud Console key with Directions API enabled,
/// passed in via `--dart-define`, separate from the Maps SDK key).
class DirectionsService {
  factory DirectionsService() => instance;

  DirectionsService._internal();

  static final DirectionsService instance = DirectionsService._internal();

  static const _endpoint =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetches a *real* driving route following the street network — never a
  /// straight line. Throws [DirectionsServiceException] (message already in
  /// Spanish, ready for a snackbar) whenever the Directions API can't
  /// return real road waypoints: no API key configured, no network, a
  /// non-OK API status, or a response missing its `overview_polyline`.
  /// [MapScreen] is expected to notify the user and stay on the
  /// exploration map rather than drawing anything fabricated.
  Future<DirectionsRoute> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (MapsConfig.directionsApiKey.isEmpty) {
      throw const DirectionsServiceException(
        'La ruta en la app no está configurada todavía.',
      );
    }
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': MapsConfig.directionsApiKey,
      },
    );

    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 12));
    } catch (_) {
      throw const DirectionsServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }

    if (response.statusCode != 200) {
      throw const DirectionsServiceException(
        'No se pudo calcular la ruta en este momento.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status != 'OK') {
      throw DirectionsServiceException(
        status == 'ZERO_RESULTS'
            ? 'No se encontró una ruta en carretera hasta este lugar.'
            : 'No se pudo calcular la ruta en este momento.',
      );
    }

    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw const DirectionsServiceException(
        'No se encontró una ruta en carretera hasta este lugar.',
      );
    }
    final route = routes.first as Map<String, dynamic>;
    final overviewPolyline =
        route['overview_polyline'] as Map<String, dynamic>?;
    final encoded = overviewPolyline?['points'] as String?;
    if (encoded == null) {
      throw const DirectionsServiceException(
        'No se pudo calcular la ruta en este momento.',
      );
    }

    final legs = route['legs'] as List<dynamic>? ?? const [];
    var distanceMeters = 0;
    var durationSeconds = 0;
    for (final leg in legs.cast<Map<String, dynamic>>()) {
      distanceMeters += (leg['distance']?['value'] as num?)?.toInt() ?? 0;
      durationSeconds += (leg['duration']?['value'] as num?)?.toInt() ?? 0;
    }

    return DirectionsRoute(
      points: _decodePolyline(encoded),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  /// Standard Google encoded-polyline algorithm decoder — see
  /// https://developers.google.com/maps/documentation/utilities/polylinealgorithm.
  /// Implemented by hand rather than pulling in a package for this one
  /// ~30-line algorithm.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
