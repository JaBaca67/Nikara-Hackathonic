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

/// Auto vs. a pie — valor enviado como `mode` a la Directions API; el mapeo a íconos vive en la capa de presentación.
enum TravelMode {
  driving('driving', 'Auto'),
  walking('walking', 'A pie');

  const TravelMode(this.apiValue, this.label);

  final String apiValue;

  final String label;
}

/// Una instrucción de giro; [MapScreen] la anuncia por TTS al acercarse a [startLocation].
class DirectionsStep {
  const DirectionsStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.startLocation,
  });

  /// Texto plano, ya sin tags HTML (ver [DirectionsService._stripHtml]).
  final String instruction;

  /// Keyword de maniobra de Google; `null` si el paso no tiene maniobra especial.
  final String? maneuver;

  final int distanceMeters;

  final LatLng startLocation;
}

/// Ruta auto/a pie entre dos puntos, decodificada del `overview_polyline` de la Directions API.
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

  final List<DirectionsStep> steps;

  double get distanceKm => distanceMeters / 1000;

  String get formattedDuration => formatDuration(durationSeconds);

  /// Estático para que el panel de navegación formatee un ETA restante con el mismo formato que el total de la ruta.
  static String formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }
}

/// Llama a la Google Directions API directamente desde el cliente usando [MapsConfig.directionsApiKey].
class DirectionsService {
  factory DirectionsService() => instance;

  DirectionsService._internal();

  static final DirectionsService instance = DirectionsService._internal();

  static const _endpoint =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Trae una ruta real sobre calles para [mode]; lanza [DirectionsServiceException] (mensaje en español) si la API no puede devolver waypoints reales, en vez de dibujar algo inventado.
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
        // Sin esto la API responde en inglés por defecto.
        'language': 'es',
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

    // Todo el parseo va envuelto porque no controlamos la forma exacta de la respuesta de Google.
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String?;
      if (status != 'OK') {
        // error_message trae la razón real (útil para depurar REQUEST_DENIED por key restringida), aunque el mensaje al usuario se queda genérico.
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

  /// Quita los tags HTML de `html_instructions`; ni el banner ni el TTS renderizan HTML.
  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Decoder del algoritmo estándar de polyline de Google, implementado a mano por ser ~30 líneas (no amerita un paquete).
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
