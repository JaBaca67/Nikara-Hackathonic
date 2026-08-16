import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:nikara_app/core/config/maps_config.dart';

class DirectionsServiceException implements Exception {
  const DirectionsServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Driving vs. walking — sent as the Directions API's `mode` query
/// parameter (see [DirectionsService.getRoute]) and offered as the two
/// icons in [MapScreen]'s route-preview mode selector (Fase 1). Icon
/// mapping lives in the presentation layer (`map_screen.dart`), not here —
/// this is a plain data/service-layer enum.
enum TravelMode {
  driving('driving', 'Auto'),
  walking('walking', 'A pie');

  const TravelMode(this.apiValue, this.label);

  /// Google Directions API's `mode` parameter value.
  final String apiValue;

  /// Short label for the mode-selector chip.
  final String label;
}

/// One turn-by-turn instruction from a leg's `steps` — [MapScreen]'s live
/// navigation banner shows [instruction] with an icon derived from
/// [maneuver], and announces it via TTS once the vehicle is within
/// range of [startLocation] (see `_MapScreenState._onPositionUpdate`).
class DirectionsStep {
  const DirectionsStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.startLocation,
  });

  /// Plain text, HTML tags already stripped from the API's
  /// `html_instructions` (see [DirectionsService._stripHtml]).
  final String instruction;

  /// Google's maneuver keyword (`turn-left`, `roundabout-right`,
  /// `merge`, ...) — `null` for a step with no special maneuver (typically
  /// the very first "head on X street" step of a route).
  final String? maneuver;

  final int distanceMeters;

  /// Where this step's maneuver happens — the point [MapScreen] measures
  /// the vehicle's distance to for the "En 80 m" countdown and the TTS
  /// announcement trigger.
  final LatLng startLocation;
}

/// A driving/walking route between two points, decoded from the Google
/// Directions API's `overview_polyline` — enough for [MapScreen]'s "Cómo
/// llegar" to draw a real route (not just a straight line), show an
/// ETA/distance, and (via [steps]) narrate turn-by-turn instructions.
class DirectionsRoute {
  const DirectionsRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  /// Turn-by-turn steps in travel order, flattened across every leg (a
  /// simple origin -> destination request always has exactly one).
  final List<DirectionsStep> steps;

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
/// passed in via `--dart-define-from-file`, separate from the Maps SDK
/// key).
class DirectionsService {
  factory DirectionsService() => instance;

  DirectionsService._internal();

  static final DirectionsService instance = DirectionsService._internal();

  static const _endpoint =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetches a *real* route following the street network for [mode] —
  /// never a straight line. Throws [DirectionsServiceException] (message
  /// already in Spanish, ready for a snackbar) whenever the Directions API
  /// can't return real road waypoints: no API key configured, no network,
  /// a non-OK API status, or a response missing its `overview_polyline`.
  /// [MapScreen] is expected to notify the user and stay on the
  /// exploration map rather than drawing anything fabricated.
  ///
  /// Every branch — success or failure — logs a `[DirectionsService]` line
  /// via [debugPrint] (never the raw key itself) so a failure while testing
  /// on a real device shows up in `flutter run`'s attached console instead
  /// of just looking like the button "does nothing".
  Future<DirectionsRoute> getRoute({
    required LatLng origin,
    required LatLng destination,
    TravelMode mode = TravelMode.driving,
  }) async {
    final key = MapsConfig.directionsApiKey;
    debugPrint(
      '[DirectionsService] key configured: ${key.isNotEmpty} '
      '(length=${key.length}), mode=${mode.apiValue}',
    );
    if (key.isEmpty) {
      throw const DirectionsServiceException(
        'La ruta en la app no está configurada todavía.',
      );
    }
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': mode.apiValue,
        'key': key,
      },
    );

    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('[DirectionsService] HTTP request failed: $e');
      throw const DirectionsServiceException(
        'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
      );
    }
    debugPrint('[DirectionsService] HTTP ${response.statusCode}');

    if (response.statusCode != 200) {
      throw const DirectionsServiceException(
        'No se pudo calcular la ruta en este momento.',
      );
    }

    // Anything from here on parses a response we don't control the shape
    // of — wrapped as a whole so a malformed/unexpected body (a captive
    // portal's HTML login page instead of JSON, a field Google renamed)
    // turns into the same friendly Spanish message instead of an unhandled
    // exception that would make the button silently do nothing.
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status != 'OK') {
        // error_message carries the actual reason (e.g. "This API key is
        // not authorized to use this service or API" for REQUEST_DENIED,
        // the #1 real-device gotcha: a key that's fine for the Maps SDK
        // but restricted against plain HTTP calls like this one) — log it
        // even though the user-facing message stays generic/friendly.
        final errorMessage = body['error_message'] as String?;
        debugPrint(
          '[DirectionsService] API status=$status'
          '${errorMessage != null ? ' error_message="$errorMessage"' : ''}',
        );
        throw DirectionsServiceException(switch (status) {
          'ZERO_RESULTS' => 'No se encontró una ruta hasta este lugar.',
          'REQUEST_DENIED' =>
            'La app no tiene permiso para calcular rutas todavía (revisa la configuración de la API key).',
          'OVER_QUERY_LIMIT' =>
            'Se alcanzó el límite de solicitudes de rutas. Intenta de nuevo más tarde.',
          _ => 'No se pudo calcular la ruta en este momento.',
        });
      }

      final routes = body['routes'] as List<dynamic>? ?? const [];
      if (routes.isEmpty) {
        throw const DirectionsServiceException(
          'No se encontró una ruta hasta este lugar.',
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
      final steps = <DirectionsStep>[];
      for (final leg in legs.cast<Map<String, dynamic>>()) {
        distanceMeters += (leg['distance']?['value'] as num?)?.toInt() ?? 0;
        durationSeconds += (leg['duration']?['value'] as num?)?.toInt() ?? 0;
        final legSteps = leg['steps'] as List<dynamic>? ?? const [];
        for (final rawStep in legSteps.cast<Map<String, dynamic>>()) {
          final startLocation =
              rawStep['start_location'] as Map<String, dynamic>?;
          if (startLocation == null) continue;
          steps.add(
            DirectionsStep(
              instruction: _stripHtml(
                rawStep['html_instructions'] as String? ?? '',
              ),
              maneuver: rawStep['maneuver'] as String?,
              distanceMeters:
                  (rawStep['distance']?['value'] as num?)?.toInt() ?? 0,
              startLocation: LatLng(
                (startLocation['lat'] as num).toDouble(),
                (startLocation['lng'] as num).toDouble(),
              ),
            ),
          );
        }
      }

      final points = _decodePolyline(encoded);
      debugPrint(
        '[DirectionsService] OK: ${points.length} points, '
        '${steps.length} steps, '
        '${(distanceMeters / 1000).toStringAsFixed(1)} km, '
        '${durationSeconds}s',
      );
      return DirectionsRoute(
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        steps: steps,
      );
    } on DirectionsServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[DirectionsService] Unexpected response shape: $e');
      throw const DirectionsServiceException(
        'No se pudo calcular la ruta en este momento.',
      );
    }
  }

  /// Google's `html_instructions` are plain text with a handful of basic
  /// tags (`<b>`, `<div>`) for emphasis/line breaks — stripped down to
  /// plain text since neither the maneuver banner nor TTS render HTML.
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
