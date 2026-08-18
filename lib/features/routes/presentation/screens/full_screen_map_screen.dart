import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/features/map/presentation/widgets/map_style.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Mapa a pantalla completa centrado en un único punto — a donde lleva
/// tocar el ícono de mapa de una parada dentro del timeline de
/// `RouteDetailScreen`. Zoom fijo en 15.5 (nivel de calle), un marcador
/// activo y, abajo, una tarjeta flotante con el nombre del lugar y el
/// botón "Cómo llegar".
///
/// No es la pestaña Mapa de la app (esa sigue viva, sin montar, dentro de
/// `MainLayout`'s IndexedStack) — es una vista de solo lectura de un punto.
/// "Cómo llegar" es lo que realmente manda a esa pestaña y arranca la
/// previsualización de ruta, vía [MapFocusController], igual que el resto
/// de la app.
class FullScreenMapScreen extends StatefulWidget {
  const FullScreenMapScreen({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.subtitle,
    this.locationId,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final double latitude;
  final double longitude;

  /// Id estable para [MapRouteRequest.destinationId] — quien llama arma
  /// uno propio (ej. `'route-stop-${stop.id}'`) para no chocar con el de
  /// otro punto. Si no se pasa, se arma uno a partir de las coordenadas.
  final String? locationId;

  /// Chip de categoría opcional sobre la tarjeta inferior — quien llama
  /// decide qué pintar ahí (`RouteCategoryChip`, por ejemplo) para que esta
  /// pantalla no tenga que conocer el dominio de rutas/negocios/ECO.
  final Widget? badge;

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  static const _zoom = 15.5;

  BitmapDescriptor? _markerIcon;

  LatLng get _target => LatLng(widget.latitude, widget.longitude);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_markerIcon == null) unawaited(_loadMarkerIcon());
  }

  Future<void> _loadMarkerIcon() async {
    final icon = await _buildActiveMarkerBitmap(
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    if (!mounted) return;
    setState(() => _markerIcon = icon);
  }

  /// Círculo dorado con un pin blanco dentro — el "marcador activo" del
  /// requerimiento. Mismo procedimiento de canvas que los pines numerados
  /// de `RouteMiniMap` (`imagePixelRatio` incluido, para que el bitmap no
  /// salga 3x más grande en pantallas 3x).
  static Future<BitmapDescriptor> _buildActiveMarkerBitmap({
    required double devicePixelRatio,
  }) async {
    const double logicalSize = 46;
    final size = (logicalSize * devicePixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    canvas.scale(size / logicalSize);

    const center = Offset(logicalSize / 2, logicalSize / 2);
    final radius = logicalSize / 2 - 3;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.mapControlShadowSoft
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, radius, Paint()..color = AppColors.primary500);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surface100
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    final iconData = Icons.place_rounded;
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          fontSize: 22,
          color: AppColors.settingsTextDark,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2 + 1),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  void _openDirections() {
    MapFocusController().startRoutePreview(
      MapRouteRequest(
        destinationId:
            widget.locationId ?? 'point-${widget.latitude}-${widget.longitude}',
        destinationName: widget.title,
        latitude: widget.latitude,
        longitude: widget.longitude,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _markerIcon;
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _target, zoom: _zoom),
            style: nikaraMapStyle,
            markers: icon == null
                ? const {}
                : {
                    Marker(
                      markerId: const MarkerId('full-screen-map-target'),
                      position: _target,
                      icon: icon,
                      infoWindow: InfoWindow(
                        title: widget.title,
                        snippet: widget.subtitle,
                      ),
                    ),
                  },
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _BackButton(onTap: () => Navigator.of(context).maybePop()),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _PlaceCard(
                title: widget.title,
                subtitle: widget.subtitle,
                badge: widget.badge,
                onDirections: _openDirections,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface100,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadowSoft,
              offset: Offset(0, 3),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 19,
          color: AppColors.settingsTextDark,
        ),
      ),
    );
  }
}

/// Tarjeta flotante inferior — nombre del lugar, chip de categoría opcional
/// y el botón "Cómo llegar".
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onDirections,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mapControlBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapControlShadowSoft,
            offset: Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (badge != null) ...[badge!, const SizedBox(height: 8)],
          Text(
            title,
            style: AppTextStyles.detailTitle.copyWith(fontSize: 18),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onDirections,
              icon: const Icon(Icons.directions_rounded, size: 19),
              label: const Text('Cómo llegar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.settingsTextDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
