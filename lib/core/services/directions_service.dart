import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:nikara_app/core/config/maps_config.dart';

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

  /// Always resolves — falls back to [_straightLineRoute] instead of
  /// throwing whenever a real driving route can't be fetched (no Directions
  /// API key configured, no network, or the API itself failing), so "Cómo
  /// llegar" always has a route to draw and never has to bounce the user
  /// out to an error message.
  Future<DirectionsRoute> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (MapsConfig.directionsApiKey.isEmpty) {
      return _straightLineRoute(origin, destination);
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
      return _straightLineRoute(origin, destination);
    }

    if (response.statusCode != 200) {
      return _straightLineRoute(origin, destination);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status != 'OK') {
      return _straightLineRoute(origin, destination);
    }

    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      return _straightLineRoute(origin, destination);
    }
    final route = routes.first as Map<String, dynamic>;
    final overviewPolyline =
        route['overview_polyline'] as Map<String, dynamic>?;
    final encoded = overviewPolyline?['points'] as String?;
    if (encoded == null) {
      return _straightLineRoute(origin, destination);
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

  /// Direct-line route between [origin] and [destination] — the fallback
  /// [getRoute] returns whenever a real driving route isn't available.
  /// Duration is estimated from a conservative in-town average speed since
  /// there's no real road geometry to time.
  static DirectionsRoute _straightLineRoute(LatLng origin, LatLng destination) {
    final meters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    const averageSpeedMetersPerSecond = 30 * 1000 / 3600; // 30 km/h
    return DirectionsRoute(
      points: [origin, destination],
      distanceMeters: meters.round(),
      durationSeconds: (meters / averageSpeedMetersPerSecond).round(),
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
