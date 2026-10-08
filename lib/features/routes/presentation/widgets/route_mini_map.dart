import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nikara_app/core/services/directions_service.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_style.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/domain/route_planner.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Located stops and optional real road legs. No lines across days or unknown stops.
class RouteMiniMap extends StatefulWidget {
  const RouteMiniMap({
    super.key,
    required this.stops,
    this.height = 250,
    this.interactive = false,
    this.onExpand,
  });
  final List<RouteStopModel> stops;
  final double height;
  final bool interactive;
  final VoidCallback? onExpand;
  @override
  State<RouteMiniMap> createState() => _RouteMiniMapState();
}

class _RouteMiniMapState extends State<RouteMiniMap> {
  GoogleMapController? _controller;
  Set<Marker> _markers = const {};
  final Map<TravelMode, Map<String, DirectionsRoute>> _cache = {};
  Set<Polyline> _roads = const {};
  TravelMode _mode = TravelMode.driving;
  bool _loading = false;
  String? _message;
  int _version = 0;
  int _markerVersion = 0;
  List<RouteStopModel> get _mappable =>
      widget.stops.where((s) => s.hasCoordinates).toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_buildMarkers());
  }

  @override
  void didUpdateWidget(RouteMiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.stops, widget.stops)) {
      _version++;
      _roads = const {};
      _message = null;
      _loading = false;
      unawaited(_buildMarkers());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_fitToStops());
      });
    }
  }

  @override
  void dispose() {
    _version++;
    _markerVersion++;
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _buildMarkers() async {
    final version = ++_markerVersion;
    final stops = _mappable;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final markers = <Marker>{};
    for (final stop in stops) {
      final icon = await _buildStopLabel(stop: stop, devicePixelRatio: ratio);
      if (!mounted || version != _markerVersion) return;
      markers.add(
        Marker(
          markerId: MarkerId(stop.visitKey),
          position: LatLng(stop.latitude!, stop.longitude!),
          anchor: const Offset(.5, .96),
          zIndexInt: 2,
          icon: icon,
          infoWindow: InfoWindow(
            title: stop.title,
            snippet: 'Día ${stop.dayNumber} · ${stop.subtitle}',
          ),
        ),
      );
    }
    if (mounted && version == _markerVersion) {
      setState(() => _markers = markers);
    }
  }

  Future<void> _calculateRoads() async {
    if (_loading) return;
    final version = ++_version;
    final mode = _mode;
    final legs = RoutePlanner.legs(widget.stops);
    if (legs.isEmpty) return;
    setState(() {
      _loading = true;
      _roads = {};
      _message = null;
    });
    final roads = <Polyline>{};
    var failures = 0;
    var meters = 0;
    var seconds = 0;
    // Sequential requests limit API pressure; cache only successful legs.
    for (final (from, to) in legs) {
      if (!mounted || version != _version) return;
      final key =
          '${from.sourceKey}:${from.latitude}:${from.longitude}>'
          '${to.sourceKey}:${to.latitude}:${to.longitude}';
      try {
        final cache = _cache.putIfAbsent(mode, () => {});
        final route =
            cache[key] ??
            await DirectionsService().getRoute(
              origin: LatLng(from.latitude!, from.longitude!),
              destination: LatLng(to.latitude!, to.longitude!),
              mode: mode,
            );
        if (!mounted || version != _version) return;
        cache[key] = route;
        meters += route.distanceMeters;
        seconds += route.durationSeconds;
        roads.add(
          Polyline(
            polylineId: PolylineId(key),
            points: route.points,
            color: AppColors.oliveText,
            width: 4,
            zIndex: 0,
          ),
        );
      } on DirectionsServiceException {
        failures++;
      }
    }
    if (!mounted || version != _version) return;
    setState(() {
      _roads = roads;
      _loading = false;
      final totals =
          '${(meters / 1000).toStringAsFixed(1)} km · '
          '${DirectionsRoute.formatDuration(seconds)} de traslado';
      _message = failures > 0
          ? '${roads.isEmpty ? 'Sin trayectos disponibles' : 'Trayectos parciales: $totals'}. '
                '$failures sin calcular; puedes reintentar.'
          : totals;
    });
    unawaited(_fitToStops());
  }

  static Future<BitmapDescriptor> _buildStopLabel({
    required RouteStopModel stop,
    required double devicePixelRatio,
  }) async {
    const width = 176.0;
    const height = 56.0;
    final pixelWidth = (width * devicePixelRatio).round();
    final pixelHeight = (height * devicePixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()),
    )..scale(devicePixelRatio);

    final pill = RRect.fromLTRBR(
      2,
      2,
      width - 2,
      45,
      const Radius.circular(16),
    );
    canvas.drawRRect(
      pill.shift(const Offset(0, 2)),
      Paint()
        ..color = AppColors.mapControlShadowSoft
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(pill, Paint()..color = AppColors.surface100);
    canvas.drawRRect(
      pill,
      Paint()
        ..color = AppColors.mapControlBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final tail = Path()
      ..moveTo(width / 2 - 7, 42)
      ..lineTo(width / 2, height - 2)
      ..lineTo(width / 2 + 7, 42)
      ..close();
    canvas.drawPath(tail, Paint()..color = AppColors.surface100);

    const avatar = Rect.fromLTWH(9, 8, 32, 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(avatar, const Radius.circular(10)),
      Paint()..color = AppColors.detailActivityIconBg,
    );
    final profile = await _loadMarkerImage(stop.imagePath, devicePixelRatio);
    if (profile == null) {
      final icon = _fallbackIcon(stop);
      final painter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 19,
            color: AppColors.oliveText,
          ),
        )
        ..layout();
      painter.paint(
        canvas,
        avatar.center - Offset(painter.width / 2, painter.height / 2),
      );
    } else {
      final cropSize = profile.width < profile.height
          ? profile.width
          : profile.height;
      final source = Rect.fromLTWH(
        (profile.width - cropSize) / 2,
        (profile.height - cropSize) / 2,
        cropSize.toDouble(),
        cropSize.toDouble(),
      );
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(avatar, const Radius.circular(10)),
      );
      canvas.drawImageRect(
        profile,
        source,
        avatar,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
      profile.dispose();
    }

    final title =
        TextPainter(
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          )
          ..text = TextSpan(
            text: stop.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          )
          ..layout(maxWidth: 124);
    title.paint(canvas, const Offset(48, 9));
    final subtitle = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: stop.category.label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 10,
          color: AppColors.settingsTextMuted,
        ),
      )
      ..layout(maxWidth: 120);
    subtitle.paint(canvas, const Offset(48, 25));

    final picture = recorder.endRecording();
    final image = await picture.toImage(pixelWidth, pixelHeight);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
    image.dispose();
    picture.dispose();
    return descriptor;
  }

  static IconData _fallbackIcon(RouteStopModel stop) {
    if (stop.kind == RouteStopKind.ecoActivity) return Icons.eco_rounded;
    if (stop.category == RouteStopCategory.gastronomico) {
      return Icons.restaurant_rounded;
    }
    if (stop.kind == RouteStopKind.business) return Icons.storefront_rounded;
    return Icons.place_rounded;
  }

  static Future<ui.Image?> _loadMarkerImage(
    String? path,
    double devicePixelRatio,
  ) async {
    if (path == null || path.isEmpty) return null;
    final ImageProvider provider;
    if (path.startsWith('https://') || path.startsWith('http://')) {
      provider = NetworkImage(path);
    } else if (path.startsWith('assets/')) {
      provider = AssetImage(path);
    } else {
      return null;
    }
    final stream = provider.resolve(
      ImageConfiguration(devicePixelRatio: devicePixelRatio),
    );
    final completer = Completer<ui.Image?>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(info.image.clone());
      },
      onError: (Object _, StackTrace? __) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
  }

  Future<void> _fitToStops() async {
    final controller = _controller;
    final stops = _mappable;
    if (controller == null || stops.isEmpty) return;
    final points = [
      for (final stop in stops) LatLng(stop.latitude!, stop.longitude!),
      for (final road in _roads) ...road.points,
    ];
    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    if (maxLat - minLat < .0001 && maxLng - minLng < .0001) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
    } else {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          48,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = _mappable;
    final missing = widget.stops.length - stops.length;
    final hasLegs = RoutePlanner.legs(widget.stops).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: widget.height,
            child: stops.isEmpty
                ? Container(
                    color: AppColors.detailMapBg,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Estas paradas aún no tienen ubicación. Puedes organizar el itinerario y registrar tus visitas.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.settingsSubtitle,
                    ),
                  )
                : Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            stops.first.latitude!,
                            stops.first.longitude!,
                          ),
                          zoom: 11,
                        ),
                        style: nikaraMapStyle,
                        markers: _markers,
                        polylines: _roads,
                        onMapCreated: (controller) {
                          _controller = controller;
                          unawaited(_fitToStops());
                        },
                        scrollGesturesEnabled: widget.interactive,
                        zoomGesturesEnabled: widget.interactive,
                        rotateGesturesEnabled: widget.interactive,
                        tiltGesturesEnabled: false,
                        gestureRecognizers: widget.interactive
                            ? {
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              }
                            : {},
                        zoomControlsEnabled: widget.interactive,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: AppColors.surface100,
                          borderRadius: BorderRadius.circular(14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Ver todas las paradas',
                                icon: const Icon(Icons.center_focus_strong),
                                onPressed: _fitToStops,
                              ),
                              if (widget.onExpand != null)
                                IconButton(
                                  tooltip: 'Ampliar mapa',
                                  icon: const Icon(Icons.fullscreen_rounded),
                                  onPressed: widget.onExpand,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (missing > 0)
          Text(
            '$missing ${missing == 1 ? 'parada sin' : 'paradas sin'} ubicación para navegar.',
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
          ),
        if (hasLegs) ...[
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final mode in TravelMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: _mode == mode,
                  onSelected: _loading
                      ? null
                      : (_) => setState(() {
                          _mode = mode;
                          _version++;
                          _roads = {};
                          _message = null;
                        }),
                ),
              TextButton.icon(
                onPressed: _loading ? null : _calculateRoads,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.alt_route_rounded, size: 18),
                label: Text(_loading ? 'Calculando…' : 'Calcular trayectos'),
              ),
            ],
          ),
          Text(
            _message ??
                'Calcula el recorrido por calles. El tiempo no incluye visitas ni descansos.',
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
          ),
        ],
      ],
    );
  }
}
