/// Motor de navegación del Modo Viaje: toda la matemática del turn-by-turn,
/// sin Flutter, sin plugins de plataforma y sin estado de UI.
///
/// Vive fuera del widget a propósito: es lo único de la navegación que se puede
/// testear sin GPS ni dispositivo, y `map_screen.dart` (3k+ líneas) no es lugar
/// para lógica que necesita tests.
///
/// La geodesia está reimplementada aquí (haversine + proyección plana local) en
/// vez de llamar a `Geolocator.distanceBetween`: son las mismas fórmulas, pero
/// sin depender del plugin los tests corren en la VM sin bindings.
library;

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/core/services/directions_service.dart';

const double _kEarthRadiusMeters = 6378137.0;

double _toRadians(double degrees) => degrees * math.pi / 180;

double _toDegrees(double radians) => radians * 180 / math.pi;

/// Distancia en metros sobre la esfera (haversine) — misma fórmula y mismo
/// radio que usa `geolocator`, así los números coinciden con el resto de la app.
double metersBetween(LatLng a, LatLng b) {
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLng = _toRadians(b.longitude - a.longitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(a.latitude)) *
          math.cos(_toRadians(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return _kEarthRadiusMeters * 2 * math.asin(math.min(1, math.sqrt(h)));
}

/// Rumbo inicial de [from] a [to], normalizado a `[0, 360)`.
double bearingDegrees(LatLng from, LatLng to) {
  final lat1 = _toRadians(from.latitude);
  final lat2 = _toRadians(to.latitude);
  final dLng = _toRadians(to.longitude - from.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return normalizeBearing(_toDegrees(math.atan2(y, x)));
}

double normalizeBearing(double bearing) => (bearing % 360 + 360) % 360;

/// Delta angular en `[-180, 180]` por el camino corto — sin esto, animar
/// 350° -> 10° gira casi una vuelta completa en vez de cruzar el norte.
double shortestBearingDelta(double from, double to) {
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return delta;
}

/// Filtro exponencial de rumbo: acerca [current] a [target] una fracción
/// [factor]. El rumbo crudo del GPS es ruidoso a baja velocidad y hacía que la
/// cámara temblara; suavizarlo es lo que la vuelve estable.
double smoothBearing(double current, double target, double factor) {
  final clamped = factor.clamp(0.0, 1.0);
  return normalizeBearing(
    current + shortestBearingDelta(current, target) * clamped,
  );
}

/// Resultado de proyectar una posición GPS sobre la polilínea de la ruta.
///
/// Se proyecta sobre el **segmento** más cercano, no sobre el vértice más
/// cercano: con vértices cada 20-80 m, "vértice más cercano" hace que el punto
/// mostrado salte de vértice en vértice en vez de deslizarse por la calle.
class RouteProjection {
  const RouteProjection({
    required this.segmentIndex,
    required this.t,
    required this.point,
    required this.lateralMeters,
    required this.traveledMeters,
  });

  /// Índice del vértice donde empieza el segmento sobre el que se proyectó.
  final int segmentIndex;

  /// Posición dentro del segmento, `0` en su inicio y `1` en su fin.
  final double t;

  /// La posición ya pegada a la ruta ("snapped").
  final LatLng point;

  /// Distancia perpendicular a la ruta — el indicador de "me salí".
  final double lateralMeters;

  /// Metros de ruta recorridos desde el origen hasta [point].
  final double traveledMeters;
}

/// La polilínea de la ruta con sus distancias acumuladas precalculadas.
class RouteGeometry {
  RouteGeometry(List<LatLng> points)
    : points = List.unmodifiable(points),
      _cumulative = _buildCumulative(points);

  final List<LatLng> points;
  final List<double> _cumulative;

  static List<double> _buildCumulative(List<LatLng> points) {
    final cumulative = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      cumulative[i] =
          cumulative[i - 1] + metersBetween(points[i - 1], points[i]);
    }
    return cumulative;
  }

  double get totalMeters => _cumulative.isEmpty ? 0 : _cumulative.last;

  int get segmentCount => points.length <= 1 ? 0 : points.length - 1;

  /// Metros de ruta acumulados hasta el vértice [index].
  double distanceAtVertex(int index) {
    if (_cumulative.isEmpty) return 0;
    return _cumulative[index.clamp(0, _cumulative.length - 1)];
  }

  /// Ventana de búsqueda por defecto al proyectar: a 1 fix/s, ni el vehículo más
  /// rápido avanza 400 m entre fixes, así que buscar más lejos solo agrega el
  /// riesgo de saltar a un tramo posterior de la misma calle.
  static const double defaultSearchWindowMeters = 400;

  /// Proyecta [current] sobre la ruta buscando desde [fromSegment] hacia
  /// adelante.
  ///
  /// La búsqueda solo-hacia-adelante es lo que impide que el jitter del GPS
  /// haga reaparecer un tramo ya recorrido. Si dentro de la ventana no hay nada
  /// razonablemente cerca (el conductor se desvió), se amplía al resto de la
  /// ruta antes de rendirse.
  RouteProjection? project(
    LatLng current, {
    int fromSegment = 0,
    double searchWindowMeters = defaultSearchWindowMeters,
    double acceptableLateralMeters = 80,
  }) {
    if (segmentCount == 0) return null;
    final start = fromSegment.clamp(0, segmentCount - 1);
    final windowEndMeters = distanceAtVertex(start) + searchWindowMeters;

    var best = _searchSegments(current, start, windowEndMeters);
    if (best == null || best.lateralMeters > acceptableLateralMeters) {
      final wide = _searchSegments(current, start, double.infinity);
      if (wide != null &&
          (best == null || wide.lateralMeters < best.lateralMeters)) {
        best = wide;
      }
    }
    return best;
  }

  RouteProjection? _searchSegments(
    LatLng current,
    int startSegment,
    double untilMeters,
  ) {
    RouteProjection? best;
    for (var i = startSegment; i < segmentCount; i++) {
      if (_cumulative[i] > untilMeters && best != null) break;
      final candidate = _projectOnSegment(current, i);
      if (best == null || candidate.lateralMeters < best.lateralMeters) {
        best = candidate;
      }
    }
    return best;
  }

  RouteProjection _projectOnSegment(LatLng current, int segmentIndex) {
    final a = points[segmentIndex];
    final b = points[segmentIndex + 1];

    // Plano local equirectangular anclado en `a`: para segmentos de decenas de
    // metros el error es despreciable y evita trigonometría esférica por fix.
    final metersPerDegreeLat = _kEarthRadiusMeters * math.pi / 180;
    final metersPerDegreeLng =
        metersPerDegreeLat * math.cos(_toRadians(a.latitude));

    final bx = (b.longitude - a.longitude) * metersPerDegreeLng;
    final by = (b.latitude - a.latitude) * metersPerDegreeLat;
    final px = (current.longitude - a.longitude) * metersPerDegreeLng;
    final py = (current.latitude - a.latitude) * metersPerDegreeLat;

    final segmentLengthSquared = bx * bx + by * by;
    final t = segmentLengthSquared == 0
        ? 0.0
        : ((px * bx + py * by) / segmentLengthSquared).clamp(0.0, 1.0);

    final projected = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    final dx = px - bx * t;
    final dy = py - by * t;

    return RouteProjection(
      segmentIndex: segmentIndex,
      t: t,
      point: projected,
      lateralMeters: math.sqrt(dx * dx + dy * dy),
      traveledMeters:
          _cumulative[segmentIndex] + math.sqrt(segmentLengthSquared) * t,
    );
  }

  /// Punto sobre la ruta a [meters] del origen — usado para el rumbo del
  /// corredor por delante y para adelantar el objetivo de cámara.
  LatLng pointAtDistance(double meters) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (meters <= 0) return points.first;
    if (meters >= totalMeters) return points.last;
    var low = 0;
    var high = points.length - 1;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_cumulative[mid] < meters) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final index = math.max(1, low);
    final segmentStart = _cumulative[index - 1];
    final segmentLength = _cumulative[index] - segmentStart;
    final t = segmentLength <= 0
        ? 0.0
        : ((meters - segmentStart) / segmentLength).clamp(0.0, 1.0);
    final a = points[index - 1];
    final b = points[index];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  /// Lo que falta por recorrer, arrancando en la posición proyectada.
  ///
  /// El primer punto es la proyección (no la posición cruda del GPS): si fuera
  /// la cruda, la línea saldría torcida desde el vehículo hasta la calle en cada
  /// fix, que es parte del "la línea se ve irregular".
  List<LatLng> remainingPoints(RouteProjection projection) {
    final tail = points.sublist(
      math.min(projection.segmentIndex + 1, points.length),
    );
    // Con t≈1 la proyección YA es el vértice siguiente; repetirlo dejaría un
    // segmento de longitud cero al frente de la polilínea.
    if (projection.t >= 0.999 && tail.isNotEmpty) return tail;
    return [projection.point, ...tail];
  }

  /// Rumbo del corredor por delante de [projection].
  ///
  /// Es el rumbo que debe usar la cámara: el rumbo crudo entre dos fixes de GPS
  /// consecutivos es ruido puro cuando el vehículo casi no se mueve.
  double bearingAhead(
    RouteProjection projection, {
    double lookaheadMeters = 40,
  }) {
    final ahead = pointAtDistance(projection.traveledMeters + lookaheadMeters);
    if (metersBetween(projection.point, ahead) < 1) {
      final index = math.min(projection.segmentIndex, points.length - 2);
      if (index < 0) return 0;
      return bearingDegrees(points[index], points[index + 1]);
    }
    return bearingDegrees(projection.point, ahead);
  }
}

/// Un anuncio de voz pendiente para una maniobra concreta.
class ManeuverCue {
  const ManeuverCue({
    required this.stepIndex,
    required this.thresholdMeters,
    required this.distanceMeters,
  });

  /// Paso de [DirectionsRoute.steps] cuya maniobra se anuncia.
  final int stepIndex;

  /// Umbral que disparó el anuncio; `0` significa "ejecutala ahora".
  final int thresholdMeters;

  /// Distancia real al punto de maniobra en el momento del anuncio.
  final double distanceMeters;

  bool get isImmediate => thresholdMeters == 0;
}

/// Decide *cuándo* hablar, una sola vez por umbral y por maniobra.
///
/// Sin esto, cada fix de GPS dentro del radio de anuncio dispara un `speak()`
/// nuevo que corta el anterior: el motor TTS nunca llega a terminar una frase y
/// se escucha entrecortado o directamente nada.
class ManeuverAnnouncer {
  ManeuverAnnouncer({List<int>? thresholds, this.immediateMeters = 30})
    : thresholds = List.unmodifiable(
        List<int>.of(thresholds ?? const [50, 200, 500])..sort(),
      );

  /// Umbrales en metros, ascendentes. Se evalúan de menor a mayor para que a
  /// 210 m suene el de 200 y no el de 500.
  final List<int> thresholds;

  /// Distancia bajo la cual se anuncia la maniobra "ahora", sin preámbulo.
  final double immediateMeters;

  int? _stepIndex;
  final Set<int> _fired = <int>{};

  /// Devuelve el anuncio que corresponde disparar, o `null` si en este fix no
  /// hay nada nuevo que decir.
  ///
  /// [stepLengthMeters] es el largo del tramo que se está recorriendo: un
  /// umbral más largo que el tramo entero no puede sonar (el conductor todavía
  /// no había tomado la maniobra anterior), así que se descarta sin hablar.
  ManeuverCue? evaluate({
    required int stepIndex,
    required double distanceMeters,
    required double stepLengthMeters,
  }) {
    if (_stepIndex != stepIndex) {
      _stepIndex = stepIndex;
      _fired.clear();
    }

    if (!_fired.contains(0) && distanceMeters <= immediateMeters) {
      _fired
        ..add(0)
        ..addAll(thresholds);
      return ManeuverCue(
        stepIndex: stepIndex,
        thresholdMeters: 0,
        distanceMeters: distanceMeters,
      );
    }

    for (final threshold in thresholds) {
      if (_fired.contains(threshold)) continue;
      if (threshold >= stepLengthMeters) {
        _fired.add(threshold);
        continue;
      }
      if (distanceMeters <= threshold) {
        for (final other in thresholds) {
          if (other >= threshold) _fired.add(other);
        }
        return ManeuverCue(
          stepIndex: stepIndex,
          thresholdMeters: threshold,
          distanceMeters: distanceMeters,
        );
      }
    }
    return null;
  }
}

/// Todo lo que la UI necesita saber tras un fix de GPS.
class NavigationUpdate {
  const NavigationUpdate({
    required this.snappedPosition,
    required this.courseBearing,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.remainingPoints,
    required this.currentStepIndex,
    required this.upcomingStepIndex,
    required this.distanceToManeuverMeters,
    required this.lateralMeters,
    required this.offRoute,
    required this.shouldReroute,
    required this.arrived,
    required this.cue,
  });

  /// Posición pegada a la ruta — es la que se dibuja, no la cruda del GPS.
  final LatLng snappedPosition;

  /// Rumbo del corredor por delante, ya suavizado.
  final double courseBearing;

  final double remainingMeters;
  final int remainingSeconds;
  final List<LatLng> remainingPoints;

  /// Tramo que se está recorriendo.
  final int currentStepIndex;

  /// Tramo cuya maniobra viene; igual a `steps.length` cuando lo próximo es
  /// llegar al destino.
  final int upcomingStepIndex;

  final double distanceToManeuverMeters;
  final double lateralMeters;
  final bool offRoute;

  /// True una sola vez por desvío (respeta el cooldown de recálculo).
  final bool shouldReroute;

  final bool arrived;
  final ManeuverCue? cue;
}

/// Estado del viaje en curso: consume fixes de GPS y devuelve el progreso.
///
/// Una instancia por ruta. Un recálculo crea un motor nuevo, así el estado
/// monotónico (índice de segmento, umbrales ya anunciados) nunca se arrastra
/// entre dos geometrías distintas.
class NavigationEngine {
  NavigationEngine({
    required this.route,
    this.mode = TravelMode.driving,
    ManeuverAnnouncer? announcer,
  }) : geometry = RouteGeometry(route.points),
       announcer =
           announcer ??
           ManeuverAnnouncer(
             // A pie se avisa más tarde: 500 m caminando son ~6 minutos, un
             // aviso ahí no le sirve a nadie.
             thresholds: mode == TravelMode.walking
                 ? const [30, 120]
                 : const [50, 200, 500],
             immediateMeters: mode == TravelMode.walking ? 15 : 30,
           );

  final DirectionsRoute route;
  final TravelMode mode;
  final RouteGeometry geometry;
  final ManeuverAnnouncer announcer;

  /// Desvío lateral a partir del cual se considera que el usuario se salió.
  ///
  /// 45 m en auto no es arbitrario: cubre el error típico de GPS urbano (10-25 m)
  /// más el ancho de una avenida con separador, así que una calle paralela real
  /// queda fuera pero estar mal ubicado sobre la propia calle no dispara nada.
  double get offRouteMeters => mode == TravelMode.walking ? 25 : 45;

  /// Fixes consecutivos fuera del corredor antes de recalcular. Con uno solo,
  /// un único fix malo (túnel, rebote urbano) pediría ruta nueva sin motivo.
  static const int rerouteConsecutiveFixes = 3;

  /// Piso entre dos recálculos — sin esto, un desvío sostenido dispara una
  /// llamada a la Directions API por cada fix de GPS.
  static const Duration rerouteCooldown = Duration(seconds: 20);

  /// Bajo esta distancia al final de la ruta se considera llegada.
  static const double arrivalMeters = 25;

  int _segmentIndex = 0;
  double? _lastRemainingMeters;
  double? _lastTraveledMeters;
  double _smoothedBearing = 0;
  bool _hasBearing = false;
  int _consecutiveOffRouteFixes = 0;
  DateTime? _lastRerouteAt;

  double get smoothedBearing => _smoothedBearing;

  /// Rumbo inicial de la ruta, para orientar la cámara antes del primer fix.
  double get initialBearing {
    if (geometry.segmentCount == 0) return 0;
    final projection = geometry.project(geometry.points.first);
    if (projection == null) return 0;
    return geometry.bearingAhead(projection);
  }

  /// Procesa un fix de GPS. Devuelve `null` si la ruta no tiene geometría
  /// utilizable (no debería pasar, pero la UI no puede asumirlo).
  NavigationUpdate? update({
    required LatLng position,
    double? speedMps,
    DateTime? now,
  }) {
    final projection = geometry.project(position, fromSegment: _segmentIndex);
    if (projection == null) return null;

    _segmentIndex = math.max(_segmentIndex, projection.segmentIndex);

    final offRoute = projection.lateralMeters > offRouteMeters;
    _consecutiveOffRouteFixes = offRoute ? _consecutiveOffRouteFixes + 1 : 0;

    final at = now ?? DateTime.now();
    var shouldReroute = false;
    if (_consecutiveOffRouteFixes >= rerouteConsecutiveFixes &&
        (_lastRerouteAt == null ||
            at.difference(_lastRerouteAt!) >= rerouteCooldown)) {
      shouldReroute = true;
      _lastRerouteAt = at;
      _consecutiveOffRouteFixes = 0;
    }

    var remainingMeters =
        geometry.totalMeters -
        projection.traveledMeters +
        projection.lateralMeters;
    // Monotónico mientras se siga la ruta: sin esto el jitter del GPS hace que
    // el contador de kilómetros suba y baje en vez de bajar parejo.
    if (!offRoute && _lastRemainingMeters != null) {
      remainingMeters = math.min(remainingMeters, _lastRemainingMeters!);
    }
    _lastRemainingMeters = remainingMeters;

    final currentStepIndex = _stepIndexForVertex(projection.segmentIndex);
    final upcomingStepIndex = currentStepIndex + 1;

    final maneuverDistanceMeters = _distanceToManeuver(
      currentStepIndex,
      projection.traveledMeters,
      remainingMeters,
    );

    // La cámara sigue el corredor, no el vector entre dos fixes: parado en un
    // semáforo el rumbo crudo gira solo, y eso es lo que hacía "movimientos
    // extraños" al puck.
    final targetBearing = geometry.bearingAhead(projection);
    final advancedMeters =
        projection.traveledMeters -
        (_lastTraveledMeters ?? projection.traveledMeters);
    _lastTraveledMeters = projection.traveledMeters;
    // `position.speed` no es confiable en todos los dispositivos, así que el
    // avance real sobre la ruta sirve de segunda señal de movimiento.
    final moving = (speedMps ?? 0) > 1.0 || advancedMeters > 3;
    if (!_hasBearing) {
      _smoothedBearing = targetBearing;
      _hasBearing = true;
    } else if (moving) {
      _smoothedBearing = smoothBearing(_smoothedBearing, targetBearing, 0.45);
    }

    final stepLength = _stepLengthMeters(currentStepIndex);
    final cue = upcomingStepIndex < route.steps.length
        ? announcer.evaluate(
            stepIndex: upcomingStepIndex,
            distanceMeters: maneuverDistanceMeters,
            stepLengthMeters: stepLength,
          )
        : announcer.evaluate(
            // El "paso" de la llegada no existe en la API; se le da el índice
            // siguiente al último para que tenga sus propios umbrales.
            stepIndex: route.steps.length,
            distanceMeters: remainingMeters,
            stepLengthMeters: stepLength,
          );

    return NavigationUpdate(
      snappedPosition: projection.point,
      courseBearing: _smoothedBearing,
      remainingMeters: remainingMeters,
      remainingSeconds: _remainingSeconds(
        currentStepIndex,
        projection.traveledMeters,
        remainingMeters,
      ),
      remainingPoints: geometry.remainingPoints(projection),
      currentStepIndex: currentStepIndex,
      upcomingStepIndex: upcomingStepIndex,
      distanceToManeuverMeters: maneuverDistanceMeters,
      lateralMeters: projection.lateralMeters,
      offRoute: offRoute,
      shouldReroute: shouldReroute,
      arrived: remainingMeters <= arrivalMeters,
      cue: cue,
    );
  }

  /// Paso que contiene el vértice [vertexIndex] de la polilínea.
  int _stepIndexForVertex(int vertexIndex) {
    if (route.steps.isEmpty) return 0;
    for (var i = route.steps.length - 1; i >= 0; i--) {
      if (vertexIndex >= route.steps[i].pointIndex) return i;
    }
    return 0;
  }

  double _stepLengthMeters(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= route.steps.length) {
      return geometry.totalMeters;
    }
    final step = route.steps[stepIndex];
    final length =
        geometry.distanceAtVertex(step.endPointIndex) -
        geometry.distanceAtVertex(step.pointIndex);
    return length > 0 ? length : step.distanceMeters.toDouble();
  }

  /// Metros **sobre la ruta** (no en línea recta) hasta el próximo giro.
  double _distanceToManeuver(
    int currentStepIndex,
    double traveledMeters,
    double remainingMeters,
  ) {
    if (currentStepIndex >= route.steps.length - 1 || route.steps.isEmpty) {
      // Última etapa: lo que viene es llegar.
      return remainingMeters;
    }
    final endOfStep = geometry.distanceAtVertex(
      route.steps[currentStepIndex].endPointIndex,
    );
    return math.max(0, endOfStep - traveledMeters);
  }

  /// ETA restante por suma de las duraciones de los tramos que faltan, con el
  /// tramo actual prorrateado. Interpolar una fracción del total (lo anterior)
  /// asume velocidad uniforme y no distingue una autopista de un centro.
  int _remainingSeconds(
    int currentStepIndex,
    double traveledMeters,
    double remainingMeters,
  ) {
    if (route.steps.isEmpty || geometry.totalMeters <= 0) {
      final fraction = route.distanceMeters <= 0
          ? 0.0
          : (remainingMeters / route.distanceMeters).clamp(0.0, 1.0);
      return (route.durationSeconds * fraction).round();
    }

    var seconds = 0.0;
    final step = route.steps[currentStepIndex.clamp(0, route.steps.length - 1)];
    final stepStart = geometry.distanceAtVertex(step.pointIndex);
    final stepEnd = geometry.distanceAtVertex(step.endPointIndex);
    final stepLength = stepEnd - stepStart;
    final fractionLeft = stepLength <= 0
        ? 0.0
        : ((stepEnd - traveledMeters) / stepLength).clamp(0.0, 1.0);
    seconds += step.durationSeconds * fractionLeft;

    for (var i = currentStepIndex + 1; i < route.steps.length; i++) {
      seconds += route.steps[i].durationSeconds;
    }
    return seconds.round();
  }
}
