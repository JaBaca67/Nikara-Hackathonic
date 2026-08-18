import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/features/map/presentation/widgets/map_style.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Mini-mapa del detalle de una ruta: un marcador numerado por parada, en
/// orden de recorrido, unidos por la polilínea del trayecto.
///
/// Solo entran las paradas con coordenadas — los puntos turísticos del
/// Inicio todavía no tienen lat/lng —, y si no queda ninguna se dibuja el
/// panel vacío en vez de un mapa centrado en cualquier parte.
class RouteMiniMap extends StatefulWidget {
  const RouteMiniMap({super.key, required this.stops, this.height = 190});

  /// Paradas ya ordenadas por día y posición; las que no tengan coordenadas
  /// se ignoran acá.
  final List<RouteStopModel> stops;

  final double height;

  @override
  State<RouteMiniMap> createState() => _RouteMiniMapState();
}

class _RouteMiniMapState extends State<RouteMiniMap> {
  GoogleMapController? _controller;
  Set<Marker> _markers = const {};
  bool _buildingMarkers = false;

  List<RouteStopModel> get _mappable =>
      widget.stops.where((s) => s.hasCoordinates).toList(growable: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_buildMarkers());
  }

  @override
  void didUpdateWidget(RouteMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stops.length != widget.stops.length) {
      unawaited(_buildMarkers());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _buildMarkers() async {
    final stops = _mappable;
    if (stops.isEmpty || _buildingMarkers) return;
    _buildingMarkers = true;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final markers = <Marker>{};
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      markers.add(
        Marker(
          markerId: MarkerId('route-stop-${stop.id ?? i}'),
          position: LatLng(stop.latitude!, stop.longitude!),
          icon: await _buildNumberedPin(number: i + 1, devicePixelRatio: ratio),
          infoWindow: InfoWindow(title: stop.title, snippet: stop.subtitle),
        ),
      );
    }
    _buildingMarkers = false;
    if (!mounted) return;
    setState(() => _markers = markers);
  }

  /// Círculo olivo con el número de la parada — mismo procedimiento que los
  /// pines de cluster de `MapScreen` (`imagePixelRatio` incluido, sin él la
  /// plataforma dibujaría el bitmap 3x más grande en pantallas 3x).
  static Future<BitmapDescriptor> _buildNumberedPin({
    required int number,
    required double devicePixelRatio,
  }) async {
    const double logicalSize = 34;
    final size = (logicalSize * devicePixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    canvas.scale(size / logicalSize);

    const center = Offset(logicalSize / 2, logicalSize / 2);
    final radius = logicalSize / 2 - 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.mapControlShadowSoft
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, radius, Paint()..color = AppColors.ecoActive);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surface100
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final label = '$number';
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Leelawadee',
          fontWeight: FontWeight.w700,
          fontSize: label.length > 1 ? 12 : 14,
          color: AppColors.surface100,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  Future<void> _fitToStops() async {
    final controller = _controller;
    final stops = _mappable;
    if (controller == null || stops.isEmpty) return;
    if (stops.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(stops.first.latitude!, stops.first.longitude!),
          13,
        ),
      );
      return;
    }
    var minLat = stops.first.latitude!;
    var maxLat = minLat;
    var minLng = stops.first.longitude!;
    var maxLng = minLng;
    for (final stop in stops) {
      minLat = stop.latitude! < minLat ? stop.latitude! : minLat;
      maxLat = stop.latitude! > maxLat ? stop.latitude! : maxLat;
      minLng = stop.longitude! < minLng ? stop.longitude! : minLng;
      maxLng = stop.longitude! > maxLng ? stop.longitude! : maxLng;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = _mappable;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: stops.isEmpty
            ? const _EmptyMiniMap()
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(stops.first.latitude!, stops.first.longitude!),
                  zoom: 11,
                ),
                style: nikaraMapStyle,
                markers: _markers,
                polylines: {
                  if (stops.length > 1)
                    Polyline(
                      polylineId: const PolylineId('route-trail'),
                      points: [
                        for (final stop in stops)
                          LatLng(stop.latitude!, stop.longitude!),
                      ],
                      color: AppColors.ecoActive,
                      width: 4,
                      // Guiones: el trayecto entre paradas es el orden del
                      // itinerario, no una ruta manejable calculada — la
                      // línea punteada evita leerlo como un trazo de
                      // navegación real.
                      patterns: [PatternItem.dash(18), PatternItem.gap(10)],
                    ),
                },
                onMapCreated: (controller) {
                  _controller = controller;
                  unawaited(_fitToStops());
                },
                // Un mapa chico dentro de una pantalla que scrollea: se deja
                // el zoom por gestos y se quitan los controles que no caben.
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                liteModeEnabled: false,
              ),
      ),
    );
  }
}

class _EmptyMiniMap extends StatelessWidget {
  const _EmptyMiniMap();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.detailMapBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 28,
            color: AppColors.settingsTextMuted,
          ),
          const SizedBox(height: 8),
          Text(
            'Las paradas de esta ruta todavía no tienen ubicación en el mapa.',
            textAlign: TextAlign.center,
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
