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

/// Un tramo de la ruta entre dos maniobras.
///
/// [instruction] describe la maniobra que se ejecuta **al inicio** del tramo
/// (así lo define la Directions API), así que mientras se recorre el paso `i`
/// la maniobra que viene es la del paso `i + 1`.
///
/// [pointIndex]/[endPointIndex] son el rango de este paso dentro de
/// [DirectionsRoute.points]. Tenerlo permite saber en qué paso va el conductor
/// proyectando su posición sobre la polilínea, en vez de adivinarlo por
/// distancia en línea recta a [startLocation] (que falla en calles paralelas y
/// en rutas que pasan dos veces cerca del mismo punto).
class DirectionsStep {
  const DirectionsStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    required this.pointIndex,
    required this.endPointIndex,
  });

  /// Texto plano, ya sin tags HTML (ver [DirectionsService._stripHtml]).
  final String instruction;

  /// Keyword de maniobra de Google; `null` si el paso no tiene maniobra especial.
  final String? maneuver;

  final int distanceMeters;

  /// Duración estimada del tramo — permite un ETA restante por suma de tramos
  /// en vez de interpolar una fracción del total.
  final int durationSeconds;

  final LatLng startLocation;
  final LatLng endLocation;

  /// Índice del primer vértice del paso en [DirectionsRoute.points].
  final int pointIndex;

  /// Índice del último vértice del paso en [DirectionsRoute.points] — es el
  /// mismo vértice donde arranca el paso siguiente.
  final int endPointIndex;
}

/// Ruta auto/a pie entre dos puntos.
///
/// [points] es la geometría de **resolución completa**: la concatenación de la
/// polilínea de cada `step`, no el `overview_polyline`. Esa distinción no es
/// cosmética — el `overview_polyline` viene simplificado con una tolerancia
/// agresiva (Google lo publica para dibujar una miniatura del viaje), así que
/// una recta real llega con vértices corridos varios metros. Navegar sobre esa
/// geometría degradada produce exactamente los tres síntomas reportados: línea
/// "distorsionada", flecha que salta al hacer snapping, y kilómetros restantes
/// que no bajan de forma pareja.
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
    if (minutes < 1) return 'menos de 1 min';
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
        // Unidades métricas explícitas: sin esto Google puede responder en
        // millas según la región de la key, y el texto de la maniobra
        // ("En 0.2 mi") se lee tal cual por TTS.
        'units': 'metric',
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

      final parsed = _parseRoute(route);
      debugPrint(
        '[DirectionsService] OK: ${parsed.points.length} points '
        '(resolución completa por steps), ${parsed.steps.length} steps, '
        '${(parsed.distanceMeters / 1000).toStringAsFixed(1)} km, '
        '${parsed.durationSeconds}s',
      );
      return parsed;
    } on DirectionsServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[DirectionsService] Unexpected response shape: $e');
      throw const DirectionsServiceException(
        'No se pudo calcular la ruta en este momento.',
      );
    }
  }

  /// Construye la ruta concatenando la polilínea de cada `step`.
  ///
  /// Expuesto (aunque privado al servicio) como paso separado para que el
  /// parseo se pueda razonar sin la parte de red; el `overview_polyline` solo
  /// se usa como último recurso, si la respuesta viniera sin `steps`.
  static DirectionsRoute _parseRoute(Map<String, dynamic> route) {
    final legs = route['legs'] as List<dynamic>? ?? const [];
    var distanceMeters = 0;
    var durationSeconds = 0;
    final steps = <DirectionsStep>[];
    final points = <LatLng>[];

    for (final leg in legs.cast<Map<String, dynamic>>()) {
      distanceMeters += (leg['distance']?['value'] as num?)?.toInt() ?? 0;
      durationSeconds += (leg['duration']?['value'] as num?)?.toInt() ?? 0;
      final legSteps = leg['steps'] as List<dynamic>? ?? const [];
      for (final rawStep in legSteps.cast<Map<String, dynamic>>()) {
        final start = _latLngOrNull(
          rawStep['start_location'] as Map<String, dynamic>?,
        );
        final end = _latLngOrNull(
          rawStep['end_location'] as Map<String, dynamic>?,
        );
        if (start == null || end == null) continue;

        final encodedStep =
            (rawStep['polyline'] as Map<String, dynamic>?)?['points']
                as String?;
        var decoded = encodedStep == null
            ? const <LatLng>[]
            : decodePolyline(encodedStep);
        // Un step sin polilínea utilizable todavía tiene que ocupar su rango de
        // índices, si no el mapeo paso -> vértice se corre para todos los demás.
        if (decoded.length < 2) decoded = [start, end];

        final int stepStartIndex;
        if (points.isEmpty) {
          stepStartIndex = 0;
          points.addAll(decoded);
        } else if (_sameCoordinate(points.last, decoded.first)) {
          // El último vértice de un step y el primero del siguiente son el
          // mismo punto: se comparte en vez de duplicarse (un vértice repetido
          // deja un segmento de longitud cero que rompe la proyección).
          stepStartIndex = points.length - 1;
          points.addAll(decoded.skip(1));
        } else {
          stepStartIndex = points.length;
          points.addAll(decoded);
        }

        steps.add(
          DirectionsStep(
            instruction: _stripHtml(
              rawStep['html_instructions'] as String? ?? '',
            ),
            maneuver: rawStep['maneuver'] as String?,
            distanceMeters:
                (rawStep['distance']?['value'] as num?)?.toInt() ?? 0,
            durationSeconds:
                (rawStep['duration']?['value'] as num?)?.toInt() ?? 0,
            startLocation: start,
            endLocation: end,
            pointIndex: stepStartIndex,
            endPointIndex: points.length - 1,
          ),
        );
      }
    }

    // Solo si la respuesta no traía steps utilizables: la geometría simplificada
    // sirve para dibujar, no para navegar, pero es mejor que no tener ruta.
    if (points.length < 2) {
      final encoded =
          (route['overview_polyline'] as Map<String, dynamic>?)?['points']
              as String?;
      if (encoded == null) {
        throw const DirectionsServiceException(
          'No se pudo calcular la ruta en este momento.',
        );
      }
      points
        ..clear()
        ..addAll(decodePolyline(encoded));
      if (points.length < 2) {
        throw const DirectionsServiceException(
          'No se pudo calcular la ruta en este momento.',
        );
      }
    }

    return DirectionsRoute(
      points: List.unmodifiable(points),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      steps: List.unmodifiable(steps),
    );
  }

  static LatLng? _latLngOrNull(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final lat = raw['lat'] as num?;
    final lng = raw['lng'] as num?;
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  /// ~0.11 m de tolerancia: la codificación de polyline redondea a 1e-5 grados,
  /// así que el vértice compartido entre dos steps puede diferir en el último dígito.
  static bool _sameCoordinate(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 1e-6 &&
        (a.longitude - b.longitude).abs() < 1e-6;
  }

  /// Quita los tags HTML de `html_instructions`; ni el banner ni el TTS renderizan HTML.
  static String _stripHtml(String html) {
    return html
        // Google separa dos frases con <div> sin espacio alrededor; sin este
        // paso quedan pegadas ("a la derechaDestino a la izquierda").
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '. ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([,.])'), r'$1')
        .replaceAll(RegExp(r'\.\s*\.'), '.')
        .trim();
  }

  /// Decoder del algoritmo estándar de polyline de Google, implementado a mano por ser ~30 líneas (no amerita un paquete).
  ///
  /// Público y estático para poder testearlo sin red y para decodificar la
  /// polilínea de cada `step` desde [_parseRoute].
  static List<LatLng> decodePolyline(String encoded) {
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
      } while (b >= 0x20 && index < encoded.length);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
