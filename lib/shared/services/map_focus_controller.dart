import 'package:flutter/foundation.dart';

import 'package:nikara_app/shared/services/main_tab_controller.dart';

/// Payload para "abre el mapa centrado en este negocio"; [businessId] selecciona el pin real, las coordenadas son el fallback si el mapa aún no lo cargó.
@immutable
class MapFocusRequest {
  const MapFocusRequest({
    required this.businessId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String businessId;
  final String name;
  final double latitude;
  final double longitude;
}

/// A diferencia de [MapFocusRequest] (solo centra/selecciona), esto arranca de inmediato el preview de ruta; lo usa [EcoDetailScreen] porque una actividad eco no es un `BusinessModel`.
@immutable
class MapRouteRequest {
  const MapRouteRequest({
    required this.destinationId,
    required this.destinationName,
    required this.latitude,
    required this.longitude,
  });

  final String destinationId;
  final String destinationName;
  final double latitude;
  final double longitude;
}

/// Canal entre pantallas para el mapa, mismo espíritu que [MainTabController]: evita que el mapa y `MainLayout` necesiten un `BuildContext` mutuo.
class MapFocusController {
  factory MapFocusController() => instance;

  MapFocusController._internal();

  static final MapFocusController instance = MapFocusController._internal();

  static const int mapTabIndex = 1;

  final ValueNotifier<MapFocusRequest?> pendingFocus = ValueNotifier(null);

  final ValueNotifier<MapRouteRequest?> pendingRoute = ValueNotifier(null);

  /// True durante navegación en vivo (Estado 19c); `MainLayout` lo usa para ocultar el bottom-nav.
  final ValueNotifier<bool> navigationActive = ValueNotifier(false);

  void focusOnBusiness(MapFocusRequest request) {
    pendingFocus.value = request;
    MainTabController().switchTo(mapTabIndex);
  }

  void startRoutePreview(MapRouteRequest request) {
    pendingRoute.value = request;
    MainTabController().switchTo(mapTabIndex);
  }
}
