import 'package:flutter/foundation.dart';

import 'package:nikara_app/shared/services/main_tab_controller.dart';

/// A "abre el mapa centrado en este negocio" request — the lat/lng/name
/// payload `MapScreen` accepts from outside itself (today: the "Cómo
/// llegar" card in `BusinessDetailScreen`).
///
/// [businessId] is what lets the map select the real pin and its carousel
/// card; the coordinates are the fallback for a business the map hasn't
/// loaded yet (it still flies there, just without a selected card).
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

/// Cross-screen channel for the map, in the same spirit as
/// [MainTabController]: a screen pushed on top of `MainLayout` can ask the
/// map (which lives alive-but-offstage inside `MainLayout`'s IndexedStack)
/// to focus a business, and the map can tell `MainLayout` to get out of the
/// way while a route is being followed — neither needs a `BuildContext`
/// reference to the other's State.
class MapFocusController {
  factory MapFocusController() => instance;

  MapFocusController._internal();

  static final MapFocusController instance = MapFocusController._internal();

  /// Index of the "Mapa" tab inside `MainLayout`.
  static const int mapTabIndex = 1;

  /// `MapScreen` listens to this and resets it back to null once consumed —
  /// null means "no pending request".
  final ValueNotifier<MapFocusRequest?> pendingFocus = ValueNotifier(null);

  /// True while the map is in live navigation (Estado 19c). `MainLayout`
  /// listens to it to hide the bottom navigation bar, so the floating
  /// navigation panel owns the bottom of the screen.
  final ValueNotifier<bool> navigationActive = ValueNotifier(false);

  /// Switches to the map tab and asks it to focus [request].
  void focusOnBusiness(MapFocusRequest request) {
    pendingFocus.value = request;
    MainTabController().switchTo(mapTabIndex);
  }
}
