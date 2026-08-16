import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/core/services/directions_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/map/domain/marker_clustering.dart';
import 'package:nikara_app/features/map/domain/route_progress.dart';
import 'package:nikara_app/features/map/presentation/widgets/map_style.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Fallback map center when geolocation isn't available (permission denied,
/// location services off, or any lookup failure) — Managua, Nicaragua's
/// capital — the same fallback used by the "Registra tu negocio" wizard's
/// map picker.
const LatLng _kDefaultMapCenter = LatLng(12.1363, -86.2513);

/// Keeps the camera from panning out into the ocean beyond Nicaragua and its
/// Central American neighbors.
final LatLngBounds _kMapBounds = LatLngBounds(
  southwest: const LatLng(7.0, -92.0),
  northeast: const LatLng(18.5, -77.0),
);

const String _kAllCategories = 'Todos';

/// How much wider/taller than the exact visible viewport
/// [_MapScreenState._loadBusinessesInViewport] queries — see
/// [_MapScreenState._paddedBounds].
const double _kViewportPadding = 0.3;

/// Mapa de exploración principal — real, live map (`google_maps_flutter`)
/// showing only real businesses persisted in Supabase's `businesses` table,
/// no mock destinations. Visual chrome (floating search bar, category
/// chips, active/inactive pins, no-price preview card) ports the Claude
/// Design project "Rediseño de Níkara Home y Mapa", Pantalla 2b — exact
/// colors, radii and shadows, not the older Figma pass.
///
/// "Cómo llegar" fetches a real driving route via [DirectionsService] and
/// switches this screen into a live GPS navigation mode (route polyline,
/// rotating vehicle puck tracking [Geolocator.getPositionStream]) —
/// entirely in-app, never handing off to the external Google Maps app —
/// see [_MapScreenState._startNavigation].
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialFocus});

  /// Business (id, name, lat/lng) to center and select as soon as the map
  /// finishes loading — set when the map is opened *at* a business instead
  /// of for free exploration. `MainLayout` builds this screen without
  /// arguments, so that path arrives through [MapFocusController] instead
  /// (see [_MapScreenState._onFocusRequested]); this constructor parameter
  /// is for pushing a focused map as its own route.
  final MapFocusRequest? initialFocus;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _businessStorageService = BusinessStorageService();
  GoogleMapController? _mapController;

  /// Unselected pin bitmap per [MapPinCategory] bucket (Estado 19a) — see
  /// [_loadMarkerIcons]. A category whose bitmap isn't ready yet (still
  /// loading) or that somehow isn't in the map falls back to
  /// [MapPinCategory.general]'s, so a marker never has no icon at all.
  final Map<MapPinCategory, BitmapDescriptor> _pinIcons = {};

  /// Selected pin bitmap per [MapPinCategory] bucket (Estado 19b) — same
  /// gold fill for every category, only the glyph inside varies (see
  /// [_buildPinBitmap]).
  final Map<MapPinCategory, BitmapDescriptor> _pinIconsSelected = {};
  BitmapDescriptor? _vehicleIcon;

  /// Cluster badge bitmaps, keyed by count — 2..9 individually, 10 stands
  /// in for "9+" (see [_clusterIconKey]). Built once alongside the pin
  /// icons in [_loadMarkerIcons], same reasoning as those: a marker's
  /// `icon` has to be a ready [BitmapDescriptor], not something built
  /// on-demand inside the synchronous [build]/[_buildMarkers] pass.
  final Map<int, BitmapDescriptor> _clusterIcons = {};

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _carouselController = PageController(viewportFraction: 0.88);

  bool _locatingUser = false;
  bool _isLoading = true;
  bool _myLocationEnabled = false;
  String _searchQuery = '';
  String _selectedCategory = _kAllCategories;
  String? _loadError;
  String? _selectedBusinessId;
  Position? _userPosition;
  List<BusinessModel> _businesses = const [];

  /// Pending "center the map on this business" request — from
  /// [MapScreen.initialFocus] or [MapFocusController], applied by
  /// [_consumePendingFocus] once there are businesses to match it against.
  MapFocusRequest? _pendingFocus;

  /// Cancels the live `businesses` row-change subscription (another device
  /// registering a business, an admin edit) — see
  /// [BusinessStorageService.subscribeToBusinessChanges].
  Future<void> Function()? _unsubscribeBusinessChanges;

  /// Collapses a burst of realtime events (a multi-row edit fires one per
  /// row) into a single reload.
  Timer? _realtimeReloadDebounce;

  /// Every distinct category across the whole table — deliberately not
  /// scoped to the current viewport (see
  /// [BusinessStorageService.getAllCategories]) so the chip row doesn't
  /// change as the user pans.
  List<String> _categories = const [];

  /// Current camera zoom, tracked from [GoogleMap.onCameraMove] (no
  /// `setState` there — see that callback) so it's up to date by the time
  /// [GoogleMap.onCameraIdle] re-clusters once the gesture settles.
  double _currentZoom = 13;

  // --- Live navigation mode (see _startNavigation) ---
  bool _isNavigating = false;
  BusinessModel? _navigationTarget;
  DirectionsRoute? _navigationRoute;

  /// Meters left along the route from the vehicle's current position,
  /// recomputed on every GPS fix (see [remainingRouteMeters]) — the
  /// "3,4 km restantes" readout in [_NavigationPanel]. Null until the first
  /// fix arrives, when the route's own total distance stands in.
  double? _remainingMeters;

  /// Voice guidance toggle in [_NavigationPanel]. Spoken turn-by-turn
  /// prompts need a TTS engine this app doesn't ship yet, so today this
  /// only records (and shows) the preference — the button is not faked as
  /// working.
  bool _voiceGuidanceEnabled = false;
  StreamSubscription<Position>? _positionSub;
  late final AnimationController _vehicleLerpController;
  LatLng? _vehicleLerpFrom;
  LatLng? _vehicleLerpTo;
  double _vehicleLerpFromBearing = 0;
  double _vehicleLerpToBearingDelta = 0;
  LatLng? _vehicleDisplayPosition;
  double _vehicleDisplayBearing = 0;

  Set<Polyline> get _polylines {
    final route = _navigationRoute;
    if (!_isNavigating || route == null) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('__route__'),
        points: route.points,
        color: AppColors.primary500,
        width: 5,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    // Read before subscribing below so consuming the request here doesn't
    // immediately re-fire _onFocusRequested with what we already took.
    _pendingFocus =
        widget.initialFocus ?? MapFocusController().pendingFocus.value;
    MapFocusController().pendingFocus.value = null;
    MapFocusController().pendingFocus.addListener(_onFocusRequested);
    // Businesses created/edited/deleted on THIS device (the wizard bumps
    // this on save) — so coming back from "Registra tu negocio" shows the
    // new pin without reopening the map.
    BusinessStorageService.revision.addListener(_onBusinessesChanged);
    // The realtime subscription for changes made *elsewhere* is opened
    // after the first successful load instead of here — see
    // _loadAllBusinessesAndFitCamera.
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _vehicleLerpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(_onVehicleLerpTick);
    _loadMarkerIcons();
    _locateUser();
    _loadCategories();
    // The first business fetch happens once the map reports its initial
    // visible region — see onMapCreated in build().
  }

  @override
  void dispose() {
    MapFocusController().pendingFocus.removeListener(_onFocusRequested);
    MapFocusController().navigationActive.value = false;
    BusinessStorageService.revision.removeListener(_onBusinessesChanged);
    _realtimeReloadDebounce?.cancel();
    unawaited(_unsubscribeBusinessChanges?.call() ?? Future<void>.value());
    _searchController.dispose();
    _searchFocusNode.dispose();
    _carouselController.dispose();
    _positionSub?.cancel();
    _vehicleLerpController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// A business was added/edited/deleted from this device — reload the full
  /// set and refit the camera so the change is visible right away. Skipped
  /// mid-navigation: yanking the camera away from a route the user is
  /// actively following would be worse than showing a stale pin, and
  /// [_stopNavigation] reloads on the way out anyway.
  void _onBusinessesChanged() {
    if (_isNavigating) return;
    unawaited(_loadAllBusinessesAndFitCamera());
  }

  void _onRemoteBusinessesChanged() {
    _realtimeReloadDebounce?.cancel();
    _realtimeReloadDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _onBusinessesChanged();
    });
  }

  /// Another screen (today: "Cómo llegar" in `BusinessDetailScreen`) asked
  /// the map to focus a business.
  void _onFocusRequested() {
    final request = MapFocusController().pendingFocus.value;
    if (request == null) return;
    // Clearing it here also re-enters this listener with null, which the
    // guard above drops.
    MapFocusController().pendingFocus.value = null;
    _pendingFocus = request;
    // Mid-load, _loadAllBusinessesAndFitCamera consumes it when it lands.
    if (!_isLoading) unawaited(_consumePendingFocus());
  }

  /// Centers and selects [_pendingFocus]'s business — the pin turns gold
  /// and its carousel card slides in, exactly like a pin tap. Falls back to
  /// just flying to the coordinates when the business isn't in the loaded
  /// set (e.g. it was deleted between screens).
  Future<void> _consumePendingFocus() async {
    final request = _pendingFocus;
    if (request == null || _mapController == null) return;
    _pendingFocus = null;

    // A leftover category/search filter could hide the very business we
    // were asked to show, so the focus request resets both.
    if (_searchQuery.isNotEmpty) _searchController.clear();
    if (_selectedCategory != _kAllCategories) {
      setState(() => _selectedCategory = _kAllCategories);
    }

    final match = _businessById(request.businessId);
    if (match != null) {
      await _selectBusiness(match);
      return;
    }
    await _animateCameraTo(LatLng(request.latitude, request.longitude));
  }

  BusinessModel? _businessById(String id) {
    for (final business in _businesses) {
      if (business.id == id) return business;
    }
    return null;
  }

  /// The carousel's current target height — expanded (Estado 19b) while a
  /// card is selected, compact (Estado 19a) otherwise. Drives both the
  /// carousel's own [AnimatedContainer] and the recenter button's
  /// [AnimatedPositioned] offset in build(), so neither snaps when a
  /// selection toggles on or off.
  double get _carouselHeight => _selectedBusinessId == null
      ? _kCarouselCompactHeight
      : _kCarouselExpandedHeight;

  List<BusinessModel> get _filteredBusinesses {
    return _businesses
        .where((b) {
          final matchesCategory =
              _selectedCategory == _kAllCategories ||
              b.category == _selectedCategory;
          final matchesSearch =
              _searchQuery.isEmpty ||
              b.name.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
  }

  /// Renders every pin state — both selected/unselected AND all
  /// [MapPinCategory] buckets — once as bitmaps — `google_maps_flutter`
  /// markers can't embed a live Flutter widget like `flutter_map`'s
  /// `Marker.child` could, so each badge from Pantalla 2b is drawn to a
  /// canvas instead, matching the same colors/sizes.
  Future<void> _loadMarkerIcons() async {
    final dpr =
        WidgetsBinding
            .instance
            .platformDispatcher
            .implicitView
            ?.devicePixelRatio ??
        2.0;
    final clusterKeys = [2, 3, 4, 5, 6, 7, 8, 9, _clusterOverflowKey];
    final pinCategories = MapPinCategory.values;
    final results = await Future.wait([
      for (final category in pinCategories)
        _buildPinBitmap(
          selected: false,
          category: category,
          devicePixelRatio: dpr,
        ),
      for (final category in pinCategories)
        _buildPinBitmap(
          selected: true,
          category: category,
          devicePixelRatio: dpr,
        ),
      _buildVehicleBitmap(devicePixelRatio: dpr),
      for (final key in clusterKeys)
        _buildClusterBitmap(count: key, devicePixelRatio: dpr),
    ]);
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < pinCategories.length; i++) {
        _pinIcons[pinCategories[i]] = results[i];
      }
      for (var i = 0; i < pinCategories.length; i++) {
        _pinIconsSelected[pinCategories[i]] = results[pinCategories.length + i];
      }
      _vehicleIcon = results[pinCategories.length * 2];
      final clusterStart = pinCategories.length * 2 + 1;
      for (var i = 0; i < clusterKeys.length; i++) {
        _clusterIcons[clusterKeys[i]] = results[clusterStart + i];
      }
    });
  }

  /// Bitmap for [category] in the given [selected] state — [_pinIcons]/
  /// [_pinIconsSelected] falling back to [MapPinCategory.general] if the
  /// exact bucket somehow isn't ready yet, so a marker is never left
  /// without an icon while bitmaps are still loading.
  BitmapDescriptor? _pinBitmapFor(
    MapPinCategory category, {
    required bool selected,
  }) {
    final byCategory = selected ? _pinIconsSelected : _pinIcons;
    return byCategory[category] ?? byCategory[MapPinCategory.general];
  }

  /// 9+ is folded into one shared bitmap ([_clusterOverflowKey]) instead of
  /// generating one per exact count — Nikara's business density has no
  /// realistic scenario with dozens of listings inside one cluster cell,
  /// so an exact "47" badge isn't worth the extra bitmap generation.
  static const _clusterOverflowKey = 10;

  static int _clusterIconKey(int count) =>
      count >= _clusterOverflowKey ? _clusterOverflowKey : count;

  static Future<BitmapDescriptor> _buildClusterBitmap({
    required int count,
    required double devicePixelRatio,
  }) async {
    const double logicalSize = 40;
    final size = (logicalSize * devicePixelRatio).round();
    final scale = size / logicalSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    canvas.scale(scale);
    final center = const Offset(logicalSize / 2, logicalSize / 2);
    final radius = logicalSize / 2 - 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.mapPinShadowActive
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, radius, Paint()..color = AppColors.primary500);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surface100
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final label = count >= _clusterOverflowKey ? '9+' : '$count';
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Leelawadee',
          fontWeight: FontWeight.w700,
          fontSize: label.length > 1 ? 13 : 15,
          color: AppColors.settingsTextDark,
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
    // Without imagePixelRatio the platform treats the bitmap as 1:1 device
    // pixels, so a pin rendered at 3x for sharpness would also draw 3x too
    // big — this is what keeps the logical sizes above the real on-screen
    // sizes on every density.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  /// A small gold navigation "puck" — circle + upward chevron — drawn
  /// pointing north by default so [Marker.rotation] (bearing, clockwise
  /// degrees from north) rotates it to match the phone's real heading of
  /// travel during [_startNavigation]'s live tracking.
  static Future<BitmapDescriptor> _buildVehicleBitmap({
    required double devicePixelRatio,
  }) async {
    const double logicalSize = 30;
    final size = (logicalSize * devicePixelRatio).round();
    final scale = size / logicalSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    canvas.scale(scale);
    final center = const Offset(logicalSize / 2, logicalSize / 2);
    final radius = logicalSize / 2 - 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.mapPinShadowActive
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, radius, Paint()..color = AppColors.primary500);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surface100
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final arrow = Path()
      ..moveTo(logicalSize / 2, logicalSize * 0.28)
      ..lineTo(logicalSize * 0.68, logicalSize * 0.62)
      ..lineTo(logicalSize * 0.5, logicalSize * 0.52)
      ..lineTo(logicalSize * 0.32, logicalSize * 0.62)
      ..close();
    canvas.drawPath(arrow, Paint()..color = AppColors.settingsTextDark);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    // Without imagePixelRatio the platform treats the bitmap as 1:1 device
    // pixels, so a pin rendered at 3x for sharpness would also draw 3x too
    // big — this is what keeps the logical sizes above the real on-screen
    // sizes on every density.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  /// Inactive pin (Estado 19a): a white circle ringed and glyphed in the
  /// business's [MapPinCategory] accent color (see [mapPinColor]).
  static const double _kPinDiameter = 34;

  /// Selected pin (Estado 19b): a bigger gold circle plus a pointer tail,
  /// so the active business reads as a real "pin" planted on its exact
  /// coordinate instead of just a recolored dot.
  static const double _kSelectedPinDiameter = 42;
  static const double _kSelectedPinTail = 11;
  static const double _kSelectedPinHeight =
      _kSelectedPinDiameter + _kSelectedPinTail;

  /// Anchors the selected pin by its tail tip (the tail ends 1.5 logical px
  /// above the bitmap's bottom edge, leaving room for its blur).
  static const Offset _kSelectedPinAnchor = Offset(
    0.5,
    (_kSelectedPinHeight - 1.5) / _kSelectedPinHeight,
  );

  static Future<BitmapDescriptor> _buildPinBitmap({
    required bool selected,
    required MapPinCategory category,
    required double devicePixelRatio,
  }) async {
    final icon = mapPinIcon(category);
    final accentColor = mapPinColor(category);
    final logicalWidth = selected ? _kSelectedPinDiameter : _kPinDiameter;
    final logicalHeight = selected ? _kSelectedPinHeight : _kPinDiameter;
    final width = (logicalWidth * devicePixelRatio).round();
    final height = (logicalHeight * devicePixelRatio).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.scale(devicePixelRatio);
    final center = Offset(logicalWidth / 2, logicalWidth / 2);
    final radius = logicalWidth / 2 - 2.5;

    if (selected) {
      // Drawn before the circle so the circle covers where the two meet.
      final tail = Path()
        ..moveTo(center.dx - radius * 0.46, center.dy + radius * 0.7)
        ..lineTo(center.dx, logicalHeight - 1.5)
        ..lineTo(center.dx + radius * 0.46, center.dy + radius * 0.7)
        ..close();
      canvas.drawPath(
        tail,
        Paint()
          ..color = AppColors.mapPinShadowActive
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(tail, Paint()..color = AppColors.primary500);
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = selected
            ? AppColors.mapPinShadowActive
            : AppColors.mapPinShadowInactive
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = selected ? AppColors.primary500 : AppColors.surface100,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        // Selected pins keep a neutral gold-on-cream ring regardless of
        // category — gold fill already reads as "selected" on its own.
        // Unselected pins ring in the category's own accent color, so its
        // color is legible even before the tiny glyph inside is.
        ..color = selected ? AppColors.surface100 : accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final iconPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: selected ? 20 : 16,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: selected ? AppColors.settingsTextDark : accentColor,
        ),
      )
      ..layout();
    iconPainter.paint(
      canvas,
      center - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    // Without imagePixelRatio the platform treats the bitmap as 1:1 device
    // pixels, so a pin rendered at 3x for sharpness would also draw 3x too
    // big — this is what keeps the logical sizes above the real on-screen
    // sizes on every density.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  /// Smoothly flies the camera to [target].
  Future<void> _animateCameraTo(LatLng target, {double zoom = 16}) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  /// Best-effort: centers the map on the device's current position and
  /// records it for the "a X km" distance shown in [_BusinessPreviewSheet].
  /// Any failure along the way (location services off, permission denied,
  /// timeout) is swallowed silently — the map just stays on the Managua
  /// fallback, exactly like before. Goes through [LocationService] so Home
  /// and Map share one cached position instead of each prompting for
  /// permission separately.
  Future<void> _locateUser({bool animate = false}) async {
    setState(() => _locatingUser = true);
    try {
      final position = await LocationService().getCurrentPosition(
        forceRefresh: animate,
      );
      if (!mounted || position == null) return;
      setState(() {
        _userPosition = position;
        // While navigating, the vehicle puck IS the user marker — turning
        // Google's blue dot back on here would draw a second one.
        _myLocationEnabled = !_isNavigating;
      });
      final here = LatLng(position.latitude, position.longitude);
      if (animate) {
        await _animateCameraTo(here, zoom: 14);
      } else {
        await _mapController?.moveCamera(CameraUpdate.newLatLngZoom(here, 14));
      }
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  /// Fetched once, independent of the viewport — see
  /// [BusinessStorageService.getAllCategories]'s doc comment for why.
  Future<void> _loadCategories() async {
    try {
      final categories = await _businessStorageService.getAllCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } on BusinessServiceException {
      // Non-fatal — the chip row just falls back to only "Todos" until the
      // next successful load; _loadBusinessesInViewport below is what
      // surfaces a real error overlay/retry for actual connectivity issues.
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _loadAllBusinessesAndFitCamera();
  }

  /// Fetches only what's inside the current camera viewport (padded by
  /// [_kViewportPadding] so a small pan doesn't immediately show empty
  /// edges) via [BusinessStorageService.getBusinessesInBounds] — called on
  /// every [GoogleMap.onCameraIdle] (see build()), so panning/zooming only
  /// ever downloads what's actually near what's on screen instead of the
  /// whole `businesses` table.
  ///
  /// Results are *merged* into [_businesses] rather than replacing it: a
  /// viewport fetch is an incremental "load what's new here", so zooming
  /// into one pin must not make every other pin (and its carousel card)
  /// disappear. [_loadAllBusinessesAndFitCamera] is the one that replaces
  /// the set outright, which is also what drops businesses deleted
  /// elsewhere. It's likewise silent — no full-screen spinner and no error
  /// overlay for a background top-up that leaves the current pins intact.
  Future<void> _loadBusinessesInViewport() async {
    final controller = _mapController;
    if (controller == null) return;
    final region = await controller.getVisibleRegion();
    final padded = _paddedBounds(region, factor: _kViewportPadding);

    try {
      final businesses = await _businessStorageService.getBusinessesInBounds(
        minLng: padded.southwest.longitude,
        minLat: padded.southwest.latitude,
        maxLng: padded.northeast.longitude,
        maxLat: padded.northeast.latitude,
      );
      if (!mounted) return;
      final merged = {
        for (final business in _businesses) business.id: business,
      };
      for (final business in businesses) {
        // A business without coordinates can't be pinned — defensive only,
        // since `businesses.location` is a NOT NULL column.
        if (business.latitude == null || business.longitude == null) continue;
        merged[business.id] = business;
      }
      setState(() {
        _businesses = merged.values.toList(growable: false);
        _loadError = null;
      });
    } on BusinessServiceException catch (e) {
      if (!mounted || _businesses.isNotEmpty) return;
      setState(() => _loadError = e.message);
    }
  }

  /// Expands a bounds box by [factor] on every side (e.g. 0.3 = 30% wider
  /// and taller) so businesses just outside the exact visible edge are
  /// already loaded by the time a small pan reveals them, instead of every
  /// pan needing its own round-trip before pins appear.
  static LatLngBounds _paddedBounds(
    LatLngBounds bounds, {
    double factor = 0.3,
  }) {
    final latPad =
        (bounds.northeast.latitude - bounds.southwest.latitude) * factor;
    final lngPad =
        (bounds.northeast.longitude - bounds.southwest.longitude) * factor;
    return LatLngBounds(
      southwest: LatLng(
        bounds.southwest.latitude - latPad,
        bounds.southwest.longitude - lngPad,
      ),
      northeast: LatLng(
        bounds.northeast.latitude + latPad,
        bounds.northeast.longitude + lngPad,
      ),
    );
  }

  /// Selects [business] — highlights its pin, flies the camera to it, and
  /// pages the carousel to its "Recomendaciones destacadas" card, which
  /// expands into this business's floating info card (Estado 19b). The
  /// single entry point for every "focus this business" trigger: a marker
  /// tap (via [_onMarkerTapped]), a direct carousel card tap (via
  /// [_onCarouselCardTapped]), or submitting a search. Deliberately NOT
  /// triggered by just scrolling the carousel — swiping through cards
  /// browses them without moving the map, only tapping one commits to it.
  Future<void> _selectBusiness(BusinessModel business) async {
    setState(() => _selectedBusinessId = business.id);
    unawaited(
      _animateCameraTo(LatLng(business.latitude!, business.longitude!)),
    );
    final index = _filteredBusinesses.indexWhere((b) => b.id == business.id);
    if (index == -1) return;
    // The carousel isn't attached yet on the very first frames — the case
    // an external focus request (see [_consumePendingFocus]) lands in. Jump
    // to the card as soon as it exists instead of leaving it on the first
    // business while a different pin shows as selected.
    if (!_carouselController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final laterIndex = _filteredBusinesses.indexWhere(
          (b) => b.id == business.id,
        );
        if (laterIndex != -1) _jumpCarouselTo(laterIndex);
      });
      return;
    }
    await _carouselController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// Direct pin tap (as opposed to a carousel card tap or search): syncs
  /// the selection like any other trigger, AND additionally opens a
  /// Google-Maps-style bottom sheet with that business's full details —
  /// the behavior split Estado 19b asks for: tapping a card just moves the
  /// camera and expands its own floating card, but tapping a pin on the
  /// map opens a dedicated detail panel. Tapping the pin that's *already*
  /// selected instead toggles it back off — same deselect this mirrors in
  /// [_onCarouselCardTapped] — rather than reopening the sheet on top of
  /// itself.
  Future<void> _onMarkerTapped(BusinessModel business) async {
    if (business.id == _selectedBusinessId) {
      setState(() => _selectedBusinessId = null);
      return;
    }
    await _selectBusiness(business);
    if (!mounted) return;
    await _showBusinessSheet(business);
  }

  /// Tapping the carousel's expanded (already-selected) card, or any
  /// compact one, toggles that business's selection — the mirror of
  /// [_onMarkerTapped]'s pin-tap toggle. Selecting flies the camera and
  /// expands the card (Estado 19b); re-tapping the same card deselects it,
  /// collapsing every card in the carousel back to Estado 19a without
  /// moving the camera or the current scroll position.
  void _onCarouselCardTapped(BusinessModel business) {
    if (business.id == _selectedBusinessId) {
      setState(() => _selectedBusinessId = null);
      return;
    }
    unawaited(_selectBusiness(business));
  }

  /// The sheet itself reuses [_BusinessCarouselCard] unchanged — it already
  /// renders exactly what's asked for (foto, nombre, rating, badges, "Cómo
  /// llegar", "Ver perfil") — wrapped in [_PinDetailSheetChrome]'s rounded
  /// top + drag handle instead of duplicating that layout.
  Future<void> _showBusinessSheet(BusinessModel business) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _PinDetailSheetChrome(
        child: _BusinessCarouselCard(
          business: business,
          distanceKm: LocationService.distanceKm(
            _userPosition,
            business.latitude,
            business.longitude,
          ),
          onNavigate: () {
            Navigator.of(sheetContext).pop();
            _startNavigation(business);
          },
          onViewProfile: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BusinessDetailScreen(business: business),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Pages the carousel to [index] without moving the camera — used to
  /// reset scroll position (e.g. [_onCategorySelected]) or to catch up to
  /// a selection made before the carousel existed (see [_selectBusiness]).
  void _jumpCarouselTo(int index) {
    if (!_carouselController.hasClients) return;
    _carouselController.jumpToPage(index);
  }

  void _onSearchSubmitted(String value) {
    _searchFocusNode.unfocus();
    final matches = _filteredBusinesses;
    if (matches.isEmpty) return;
    _selectBusiness(matches.first);
  }

  /// Chip row (Estado 19a) — filters the pins *and* the carousel, then
  /// refits the camera to whatever is left so the new selection is framed
  /// on screen instead of leaving the user zoomed in on a filtered-out area.
  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      // A business the new filter hides can't stay the selected pin.
      final stillVisible = _filteredBusinesses.any(
        (b) => b.id == _selectedBusinessId,
      );
      if (!stillVisible) _selectedBusinessId = null;
    });
    // The carousel now holds a different (usually shorter) list, so its
    // current page would point at an unrelated business.
    _jumpCarouselTo(0);
    unawaited(_fitCameraToBusinesses(_filteredBusinesses));
  }

  /// Initial load (and reload on map creation): fetches every business
  /// within [_kMapBounds] — the same hard limit the camera itself can
  /// never pan past — rather than just the freshly-created map's tiny
  /// initial viewport, so [_fitCameraToBusinesses] below has the complete
  /// set to fit the camera to. At real scale (hundreds+ of businesses)
  /// this should narrow to something like "nearby cities only" instead of
  /// literally all of Nicaragua; today's business count doesn't justify
  /// that complexity yet. [_loadBusinessesInViewport] takes back over for
  /// every pan/zoom after this first fit.
  Future<void> _loadAllBusinessesAndFitCamera() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final businesses = await _businessStorageService.getBusinessesInBounds(
        minLng: _kMapBounds.southwest.longitude,
        minLat: _kMapBounds.southwest.latitude,
        maxLng: _kMapBounds.northeast.longitude,
        maxLat: _kMapBounds.northeast.latitude,
      );
      if (!mounted) return;
      setState(() {
        _businesses = businesses
            .where((b) => b.latitude != null && b.longitude != null)
            .toList(growable: false);
        // A business that disappeared from the table can't stay selected.
        if (_businessById(_selectedBusinessId ?? '') == null) {
          _selectedBusinessId = null;
        }
        _isLoading = false;
      });
      // Only once the map has really talked to Supabase — no point holding
      // a realtime socket open for a screen that never managed to load
      // (and it keeps widget tests, which never reach this code, free of a
      // live connection they'd have to tear down).
      _unsubscribeBusinessChanges ??= _businessStorageService
          .subscribeToBusinessChanges(_onRemoteBusinessesChanged);
      // A pending "open the map at this business" request wins over the
      // fit-everything framing — otherwise the camera would fit all pins
      // and then immediately fly off to the requested one.
      if (_pendingFocus != null) {
        await _consumePendingFocus();
        return;
      }
      await _fitCameraToBusinesses(_filteredBusinesses);
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  /// Animates the camera so every business in [businesses] is on screen —
  /// via [_boundsForPoints], the same bounds-fit helper navigation and
  /// cluster taps already use — called after the initial load and
  /// whenever the category filter changes. Falls back to the default
  /// Managua view when there's nothing to fit (e.g. an empty category).
  Future<void> _fitCameraToBusinesses(List<BusinessModel> businesses) async {
    final controller = _mapController;
    if (controller == null) return;
    if (businesses.isEmpty) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_kDefaultMapCenter, 13),
      );
      return;
    }
    if (businesses.length == 1) {
      final business = businesses.first;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(business.latitude!, business.longitude!),
          14,
        ),
      );
      return;
    }
    final points = [
      for (final business in businesses)
        LatLng(business.latitude!, business.longitude!),
    ];
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsForPoints(points), 72),
    );
  }

  /// "Cómo llegar" — fetches a real driving route (following the actual
  /// street network, never a straight line) from the device's current
  /// position to [business] via [DirectionsService], draws it, and switches
  /// the screen into live GPS navigation (see [_onPositionUpdate]) —
  /// entirely in-app, never handing off to the external Google Maps app.
  /// If a real route can't be fetched (no Directions key configured, no
  /// network, no result), this shows the specific reason in a snackbar and
  /// stays on the exploration map instead of ever drawing a fabricated
  /// route.
  Future<void> _startNavigation(BusinessModel business) async {
    debugPrint('[MapScreen] "Cómo llegar" tapped for ${business.name}');
    final lat = business.latitude;
    final lng = business.longitude;
    if (lat == null || lng == null) {
      debugPrint('[MapScreen] aborted: business has no coordinates');
      return;
    }
    final destination = LatLng(lat, lng);

    final position = await LocationService().getCurrentPosition(
      forceRefresh: true,
    );
    if (!mounted) return;
    if (position == null) {
      debugPrint(
        '[MapScreen] aborted: could not get current position '
        '(location permission/services?)',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener tu ubicación actual.'),
        ),
      );
      return;
    }
    final origin = LatLng(position.latitude, position.longitude);

    final DirectionsRoute route;
    try {
      route = await DirectionsService().getRoute(
        origin: origin,
        destination: destination,
      );
    } on DirectionsServiceException catch (e) {
      debugPrint('[MapScreen] route failed: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;

    setState(() {
      _isNavigating = true;
      _navigationTarget = business;
      _navigationRoute = route;
      _remainingMeters = route.distanceMeters.toDouble();
      _vehicleDisplayPosition = origin;
      _vehicleDisplayBearing = 0;
      // The custom vehicle puck below replaces Google's own blue dot —
      // both on at once would show two overlapping user markers.
      _myLocationEnabled = false;
      _selectedBusinessId = business.id;
    });
    // Hides MainLayout's bottom navigation bar (Estado 19c) — the carousel
    // and the top search chrome hide themselves off `_isNavigating` in
    // build(), so the floating panel is the only chrome left.
    MapFocusController().navigationActive.value = true;

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsForPoints(route.points), 64),
    );

    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  /// "Cancelar viaje" — clears the route and drops back to Estado 19a/19b
  /// with the destination still selected, so the user lands back on that
  /// business's card instead of on a blank map.
  Future<void> _stopNavigation() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _vehicleLerpController.stop();
    MapFocusController().navigationActive.value = false;
    if (!mounted) return;
    final target = _navigationTarget;
    setState(() {
      _isNavigating = false;
      _navigationTarget = null;
      _navigationRoute = null;
      _remainingMeters = null;
      _vehicleDisplayPosition = null;
      _myLocationEnabled = _userPosition != null;
    });
    if (target != null) await _selectBusiness(target);
  }

  static LatLngBounds _boundsForPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Fires on every raw GPS fix while navigating — computes the real
  /// movement bearing (not the phone's compass heading, which drifts and
  /// jumps a lot more) from the last displayed position, then animates
  /// [_vehicleDisplayPosition]/[_vehicleDisplayBearing] toward the new fix
  /// over [_vehicleLerpController]'s duration instead of snapping straight
  /// to it, so the puck glides smoothly between updates like a real
  /// turn-by-turn app instead of jittering.
  void _onPositionUpdate(Position position) {
    final newPos = LatLng(position.latitude, position.longitude);
    final previous = _vehicleDisplayPosition;
    var targetBearing = _vehicleDisplayBearing;
    if (previous != null) {
      final movedMeters = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        newPos.latitude,
        newPos.longitude,
      );
      // Below this, GPS noise makes the bearing meaningless — keep facing
      // whichever way the puck was already facing instead of jittering.
      if (movedMeters > 3) {
        final raw = Geolocator.bearingBetween(
          previous.latitude,
          previous.longitude,
          newPos.latitude,
          newPos.longitude,
        );
        targetBearing = (raw + 360) % 360;
      }
    }

    _vehicleLerpFrom = previous ?? newPos;
    _vehicleLerpTo = newPos;
    _vehicleLerpFromBearing = _vehicleDisplayBearing;
    _vehicleLerpToBearingDelta = _shortestBearingDelta(
      _vehicleDisplayBearing,
      targetBearing,
    );
    _vehicleLerpController
      ..stop()
      ..reset()
      ..forward();

    final route = _navigationRoute;
    if (route != null && mounted) {
      setState(() {
        _remainingMeters = remainingRouteMeters(
          routePoints: route.points,
          current: newPos,
        );
      });
    }

    // Follows the vehicle with the map turned in the direction of travel
    // and tilted, the way a turn-by-turn view reads — not the flat
    // north-up frame the exploration states use.
    unawaited(
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: newPos,
            zoom: 16.5,
            tilt: 45,
            bearing: targetBearing,
          ),
        ),
      ),
    );
  }

  /// ETA for what's *left* of the trip: the route's total duration scaled
  /// by the fraction of its distance still ahead. Deliberately derived from
  /// the one Directions call made when navigation started — a truly live
  /// ETA would mean re-requesting a route on every GPS fix, far past what
  /// this MVP's single-call approach covers.
  String get _remainingEtaLabel {
    final route = _navigationRoute;
    if (route == null) return '';
    final remaining = _remainingMeters;
    if (remaining == null || route.distanceMeters <= 0) {
      return route.formattedDuration;
    }
    final fraction = (remaining / route.distanceMeters).clamp(0.0, 1.0);
    return DirectionsRoute.formatDuration(
      (route.durationSeconds * fraction).round(),
    );
  }

  String get _remainingDistanceLabel {
    final route = _navigationRoute;
    if (route == null) return '';
    final km = (_remainingMeters ?? route.distanceMeters.toDouble()) / 1000;
    return km < 1
        ? '${(km * 1000).round()} m restantes'
        : '${km.toStringAsFixed(1)} km restantes';
  }

  void _onVehicleLerpTick() {
    final from = _vehicleLerpFrom;
    final to = _vehicleLerpTo;
    if (from == null || to == null || !mounted) return;
    final t = Curves.linear.transform(_vehicleLerpController.value);
    setState(() {
      _vehicleDisplayPosition = LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
      _vehicleDisplayBearing =
          (_vehicleLerpFromBearing + _vehicleLerpToBearingDelta * t) % 360;
    });
  }

  /// Angular delta (in [-180, 180]) to rotate [from] by to reach [to] the
  /// short way around the compass — without this, animating e.g. 350° ->
  /// 10° would spin the puck almost all the way around instead of just
  /// past north.
  static double _shortestBearingDelta(double from, double to) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }

  Set<Marker> _buildMarkers(List<BusinessModel> businesses) {
    // Bitmaps for MapPinCategory.general (the fallback every other bucket
    // also falls back to — see _pinBitmapFor) haven't loaded yet.
    if (_pinIcons[MapPinCategory.general] == null ||
        _pinIconsSelected[MapPinCategory.general] == null) {
      return const {};
    }

    final markers = <Marker>{};

    // Decluttered while navigating — only the destination pin (plus the
    // vehicle puck below) stays on screen, matching a real turn-by-turn
    // view. No clustering needed either: it's always exactly one pin.
    final target = _navigationTarget;
    if (_isNavigating && target != null) {
      final icon = _pinBitmapFor(
        mapPinCategoryFor(target.category),
        selected: true,
      );
      if (icon != null) {
        markers.add(
          Marker(
            markerId: MarkerId(target.id),
            position: LatLng(target.latitude!, target.longitude!),
            icon: icon,
            anchor: _kSelectedPinAnchor,
          ),
        );
      }
    } else {
      final referenceLatitude = businesses.isEmpty
          ? _kDefaultMapCenter.latitude
          : businesses.map((b) => b.latitude!).reduce((a, b) => a + b) /
                businesses.length;
      final clusters = clusterBusinesses(
        businesses: businesses,
        zoom: _currentZoom,
        referenceLatitude: referenceLatitude,
      );
      for (final cluster in clusters) {
        if (cluster.isSingle) {
          final business = cluster.businesses.first;
          final isSelected = business.id == _selectedBusinessId;
          final icon = _pinBitmapFor(
            mapPinCategoryFor(business.category),
            selected: isSelected,
          );
          if (icon == null) continue; // Bitmaps still loading.
          markers.add(
            Marker(
              markerId: MarkerId(business.id),
              position: cluster.position,
              icon: icon,
              // The selected pin is anchored by its tail tip, the plain
              // circles by their center.
              anchor: isSelected ? _kSelectedPinAnchor : const Offset(0.5, 0.5),
              // Above its neighbours, so a selected pin standing among
              // close-together ones is never half-covered by them.
              zIndexInt: isSelected ? 2 : 0,
              // A direct pin tap both selects (camera + carousel sync,
              // same as any other selection trigger) AND opens the
              // Google-Maps-style detail sheet — see _onMarkerTapped.
              onTap: () => _onMarkerTapped(business),
            ),
          );
        } else {
          final icon = _clusterIcons[_clusterIconKey(cluster.count)];
          if (icon == null) {
            continue; // Bitmaps still loading — skip this frame.
          }
          markers.add(
            Marker(
              markerId: MarkerId(
                '__cluster__'
                '${cluster.position.latitude}_${cluster.position.longitude}',
              ),
              position: cluster.position,
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 1,
              onTap: () => _onClusterTap(cluster),
            ),
          );
        }
      }
    }

    final vehiclePos = _vehicleDisplayPosition;
    final vehicleIcon = _vehicleIcon;
    if (_isNavigating && vehiclePos != null && vehicleIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('__vehicle__'),
          position: vehiclePos,
          icon: vehicleIcon,
          anchor: const Offset(0.5, 0.5),
          rotation: _vehicleDisplayBearing,
          flat: true,
          zIndexInt: 3,
        ),
      );
    }
    return markers;
  }

  /// Tapping a cluster badge zooms/pans to fit exactly its members'
  /// bounds — reuses [_boundsForPoints], the same helper [_startNavigation]
  /// uses to fit a route — rather than a blind fixed zoom-in step, so a
  /// cluster of 2 close-together pins and one of 9 scattered pins each
  /// resolve in one tap instead of sometimes needing a second.
  Future<void> _onClusterTap(MapCluster cluster) async {
    final points = [
      for (final business in cluster.businesses)
        LatLng(business.latitude!, business.longitude!),
    ];
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsForPoints(points), 72),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBusinesses;
    final categories = [_kAllCategories, ..._categories];

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Edge-to-edge real map: fills the entire screen, including
          // behind the status bar. Only the floating UI below respects
          // SafeArea, per Pantalla 2b's "map first" layout.
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kDefaultMapCenter,
              zoom: 13,
            ),
            // Hides Google's native POI/transit icons and retints the base
            // map into the app's cream/sand palette — see map_style.dart.
            style: nikaraMapStyle,
            onMapCreated: _onMapCreated,
            // No setState here deliberately — during a drag/pinch this can
            // fire many times a second, and rebuilding the whole screen on
            // every frame just to re-cluster isn't worth it. It only
            // records the zoom so the re-cluster/re-fetch triggered by
            // onCameraIdle below (which does setState) uses an up-to-date
            // value once the gesture actually settles.
            onCameraMove: (position) => _currentZoom = position.zoom,
            // Skipped while navigating: the camera moves on every GPS fix
            // there, and each of those settling into a viewport re-fetch
            // would be a request per fix for pins that are hidden anyway.
            onCameraIdle: () {
              if (_isNavigating) return;
              unawaited(_loadBusinessesInViewport());
            },
            // Hard zoom limits + a bounds constraint are what keep the
            // camera from panning/zooming out into empty ocean.
            minMaxZoomPreference: const MinMaxZoomPreference(6, 18),
            cameraTargetBounds: CameraTargetBounds(_kMapBounds),
            // Google's native 3D building extrusions render in their own
            // flat industrial gray regardless of `style` (that JSON only
            // covers 2D feature coloring) — most visible once navigation's
            // tilted camera (see _onPositionUpdate) zooms in close, clashing
            // with Níkara's cream palette. Disabling them keeps the custom
            // style consistent at every zoom level, tilted or not.
            buildingsEnabled: false,
            myLocationEnabled: _myLocationEnabled,
            // Custom recenter button below replaces the default one.
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: _buildMarkers(filtered),
            polylines: _polylines,
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x59FFF9F0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary500),
                ),
              ),
            )
          else if (_loadError != null)
            Positioned.fill(
              child: _MapErrorOverlay(
                message: _loadError!,
                onRetry: _loadAllBusinessesAndFitCamera,
              ),
            ),
          // Floating chrome — search bar, filter button, category chips —
          // each with its own hairline border/shadow directly over the
          // map, per Pantalla 2b (no enclosing glass panel). Estado 19c
          // hides all of it: while following a route the only chrome left
          // is the floating navigation panel at the bottom.
          if (!_isNavigating)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MapSearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onSubmitted: _onSearchSubmitted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _MapFilterButton(
                          onTap: () => _onCategorySelected(_kAllCategories),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return _CategoryChip(
                            label: category,
                            selected: _selectedCategory == category,
                            onTap: () => _onCategorySelected(category),
                          );
                        },
                      ),
                    ),
                    if (!_isLoading &&
                        _loadError == null &&
                        _businesses.isNotEmpty &&
                        filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: _EmptyBusinessesBanner(
                          message: 'Ningún negocio coincide con tu búsqueda.',
                        ),
                      )
                    else if (!_isLoading &&
                        _loadError == null &&
                        _businesses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: _EmptyBusinessesBanner(),
                      ),
                  ],
                ),
              ),
            ),
          // Persistent "Recomendaciones destacadas" carousel (Pantalla 2a) —
          // replaces the old tap-to-open modal preview: every filtered
          // business gets a card. Scrolling through them is browse-only —
          // it neither selects nor moves the camera; only tapping a card
          // (or its pin) commits to it (see _selectBusiness /
          // _onCarouselCardTapped / _onMarkerTapped).
          if (!_isNavigating && filtered.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12, bottom: 8),
                        child: _CarouselHeaderLabel(),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: _carouselHeight,
                        child: PageView.builder(
                          controller: _carouselController,
                          padEnds: false,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final business = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: _BusinessCarouselCard(
                                  business: business,
                                  expanded: business.id == _selectedBusinessId,
                                  distanceKm: LocationService.distanceKm(
                                    _userPosition,
                                    business.latitude,
                                    business.longitude,
                                  ),
                                  onTap: () => _onCarouselCardTapped(business),
                                  onNavigate: () => _startNavigation(business),
                                  onViewProfile: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BusinessDetailScreen(
                                          business: business,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Estado 19c — floating bottom panel: ETA badge, remaining
          // distance + destination, and the Voz / Cancelar viaje actions.
          // MainLayout's bottom nav is hidden while this shows (see
          // _startNavigation), so it sits directly on the bottom edge.
          if (_isNavigating && _navigationTarget != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _NavigationPanel(
                    destinationName: _navigationTarget!.name,
                    etaLabel: _remainingEtaLabel,
                    remainingLabel: _remainingDistanceLabel,
                    voiceEnabled: _voiceGuidanceEnabled,
                    onToggleVoice: _toggleVoiceGuidance,
                    onCancel: _stopNavigation,
                  ),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            right: 16,
            // Sits just above whatever occupies the bottom of the screen:
            // the navigation panel (19c), the carousel (Pantalla 2a,
            // whose own height animates between its compact and expanded
            // states — see [_carouselHeight]), or nothing at all (Pantalla
            // 2b's bottom-right corner).
            bottom: _isNavigating
                ? _kNavigationPanelHeight + 16
                : (filtered.isEmpty ? 16 : _carouselHeight + 16),
            child: SafeArea(
              top: false,
              bottom: false,
              child: _RecenterButton(
                isLoading: _locatingUser,
                onPressed: () => _locateUser(animate: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleVoiceGuidance() {
    setState(() => _voiceGuidanceEnabled = !_voiceGuidanceEnabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _voiceGuidanceEnabled
              ? 'Guía por voz activada. Las indicaciones habladas llegan pronto.'
              : 'Guía por voz desactivada.',
        ),
      ),
    );
  }
}

/// Carousel height while no card is selected (Estado 19a) — tall enough
/// for [_BusinessCarouselCard]'s compact layout (thumbnail, name,
/// location, one fixed-height badge slot — no action buttons) with a
/// little slack for font-metric rounding, so it never triggers a
/// `RenderFlex` overflow.
const double _kCarouselCompactHeight = 108;

/// Carousel height once a card is selected and expands to its full layout
/// with "Cómo llegar" / "Ver perfil" (Estado 19b), Pantalla 2a.
const double _kCarouselExpandedHeight = 168;

/// Fixed height of the compact card's badge line (see
/// [_BusinessCarouselCard]) — reserved whether or not a badge actually
/// renders there, so every compact card measures exactly the same total
/// height no matter which business is in it.
const double _kCompactBadgeSlotHeight = 26;

/// Vertical space [_NavigationPanel] takes at the bottom of the screen —
/// what the recenter button clears while navigating.
const double _kNavigationPanelHeight = 132;

/// Estado 19c — the only chrome left while a route is being followed:
/// a white Níkara card floating over the bottom of the map with the live
/// ETA badge, how much is left to the destination, and the two trip
/// actions. Replaces the earlier top banner; the bottom navigation bar is
/// hidden underneath it (see [MapFocusController.navigationActive]).
class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.destinationName,
    required this.etaLabel,
    required this.remainingLabel,
    required this.voiceEnabled,
    required this.onToggleVoice,
    required this.onCancel,
  });

  final String destinationName;

  /// Remaining ETA, e.g. "12 min".
  final String etaLabel;

  /// Remaining distance, e.g. "3.4 km restantes".
  final String remainingLabel;

  final bool voiceEnabled;
  final VoidCallback onToggleVoice;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.mapControlBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapCardShadow,
            offset: Offset(0, 8),
            blurRadius: 26,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.navigation_rounded,
                      size: 15,
                      color: AppColors.settingsTextDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      etaLabel,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.settingsTextDark,
                        fontSize: 14,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$remainingLabel · $destinationName',
                  style: AppTextStyles.mapRowCaption.copyWith(
                    color: AppColors.settingsTextDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onToggleVoice,
                    icon: Icon(
                      voiceEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      size: 16,
                    ),
                    label: const Text('Voz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.settingsBackground,
                      foregroundColor: AppColors.settingsTextDark,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: AppTextStyles.mapRowTitle.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancelar viaje'),
                    style: ElevatedButton.styleFrom(
                      // Soft-alert pairing, not a solid red block: the pale
                      // coral fill from the palette with the app's one
                      // canonical destructive tint as its text/icon color.
                      backgroundColor: AppColors.complementario1,
                      foregroundColor: AppColors.settingsDanger,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                          color: AppColors.complementario2,
                        ),
                      ),
                      textStyle: AppTextStyles.mapRowTitle.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating recenter/"my location" button — 46px circle, hairline border
/// and soft ink shadow, per Pantalla 2b.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface100,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.mapControlBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadowStrong,
              offset: Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary500,
                ),
              )
            : const Icon(
                Icons.my_location,
                size: 19,
                color: AppColors.settingsTextDark,
              ),
      ),
    );
  }
}

/// Small floating pill labeling the carousel below as "Recomendaciones
/// destacadas" — same hairline-surface chrome language as the search bar
/// and category chips, self-sized so it doesn't compete with the map
/// underneath it.
class _CarouselHeaderLabel extends StatelessWidget {
  const _CarouselHeaderLabel();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.mapControlBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadow,
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 13,
              color: AppColors.primary500,
            ),
            const SizedBox(width: 5),
            Text(
              'Recomendaciones destacadas',
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 12,
                color: AppColors.settingsTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating search field — white surface, hairline border, soft ink
/// shadow, per Pantalla 2b (no thick outline, no glass-blur panel).
class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({
    required this.controller,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Submitting (return key / search action) jumps to the first matching
  /// business — see [_MapScreenState._onSearchSubmitted].
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mapControlBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapControlShadow,
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 16,
            color: AppColors.settingsTextMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.settingsTextDark,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar negocio o lugar...',
                hintStyle: AppTextStyles.caption.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Separate square filter button beside the search bar (its own surface,
/// not embedded inside the search field) — tapping it resets the category
/// filter back to "Todos", per Pantalla 2b's chrome.
class _MapFilterButton extends StatelessWidget {
  const _MapFilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.mapControlBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadow,
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: const Icon(
          Icons.tune,
          size: 18,
          color: AppColors.settingsTextDark,
        ),
      ),
    );
  }
}

/// A single category pill — gold fill while selected, white/hairline
/// otherwise, per Pantalla 2b's "Todos / Lagunas / Tours / Eco" row.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.surface100,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: AppColors.mapControlBorder),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.mapControlShadowStrong
                  : AppColors.mapControlShadowSoft,
              offset: const Offset(0, 3),
              blurRadius: 10,
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.mapRowTitle.copyWith(
            color: selected
                ? AppColors.settingsTextDark
                : AppColors.settingsTextMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _MapErrorOverlay extends StatelessWidget {
  const _MapErrorOverlay({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundCream,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.settingsDanger,
              ),
              const SizedBox(height: 12),
              Text(
                'No se pudieron cargar los negocios',
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.mapRowCaption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.textInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBusinessesBanner extends StatelessWidget {
  const _EmptyBusinessesBanner({
    this.message = 'Todavía no hay negocios registrados en el mapa.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mapControlBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapControlShadow,
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 20,
            color: AppColors.settingsTextMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.mapRowCaption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-top chrome for [MapScreen._showBusinessSheet]'s Google-Maps-style
/// pin detail sheet — a drag handle over whatever [child] is (always a
/// [_BusinessCarouselCard] in practice), so the sheet reads as "swipe down
/// to dismiss" without needing a full [DraggableScrollableSheet] for
/// content that doesn't scroll.
class _PinDetailSheetChrome extends StatelessWidget {
  const _PinDetailSheetChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.profileDivider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Photo, name, category tags, real GPS distance and exactly two actions
/// ("Cómo llegar" / "Ver perfil"), per Pantalla 2b: no price, no
/// reservation button. Both the persistent business carousel's cards
/// (Pantalla 2a, inside a [PageView] whose height animates between
/// [_kCarouselCompactHeight]/[_kCarouselExpandedHeight]) and
/// [MapScreen._showBusinessSheet]'s Google-Maps-style pin detail sheet (no
/// fixed height — sizes to its own content, always [expanded]) render this
/// same card, so a business always looks identical whichever way it got
/// selected.
class _BusinessCarouselCard extends StatelessWidget {
  const _BusinessCarouselCard({
    required this.business,
    required this.onNavigate,
    required this.onViewProfile,
    this.distanceKm,
    this.expanded = true,
    this.onTap,
  });

  final BusinessModel business;

  /// Straight-line (Haversine) distance from the device's last known
  /// position, or `null` when it isn't available — in which case only the
  /// city shows.
  final double? distanceKm;

  /// Switches [MapScreen] into live in-app navigation — see
  /// [_MapScreenState._startNavigation].
  final VoidCallback onNavigate;
  final VoidCallback onViewProfile;

  /// Whether this renders the full layout (photo + tags + "Cómo llegar" /
  /// "Ver perfil", Estado 19b, gold-bordered) or the compact one (small
  /// thumbnail + name + location, Estado 19a) — the carousel expands only
  /// its currently-selected card (see
  /// [_MapScreenState._selectedBusinessId]) and keeps every other one
  /// compact. Always `true` in the pin detail sheet
  /// (`MapScreen._showBusinessSheet`), which only ever shows one card in
  /// full.
  final bool expanded;

  /// Toggles this business's selection — tapping a compact card expands
  /// it, tapping the expanded one's header collapses it back (see
  /// [_MapScreenState._onCarouselCardTapped]). Left null in the pin detail
  /// sheet, which has no compact state to toggle back to.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;
    final km = distanceKm;
    final locationLabel = km == null
        ? business.city
        : '${business.city} · a ${km.toStringAsFixed(0)} km';
    final rating = business.averageRating;
    final firstActivity = business.activities.isNotEmpty
        ? activityLabel(business.activities.first)
        : null;
    // No `is_eco` column exists yet — real owner opt-in (Pantalla 4c's
    // Sello ECO) takes priority; category/activities text is only a
    // fallback for businesses saved before that field existed.
    final isEco =
        business.ecoSealRequested ||
        business.category.toLowerCase().contains('eco') ||
        business.activities.any(
          (a) => activityLabel(a).toLowerCase().contains('eco'),
        );

    final header = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(expanded ? 16 : 12),
            child: SizedBox(
              width: expanded ? 78 : 52,
              height: expanded ? 78 : 52,
              child: LocalImage(
                path: imagePath,
                fallbackIcon: Icons.storefront_outlined,
                fallbackIconSize: expanded ? 24 : 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Right padding reserves room for the floating favorite
                // circle positioned over the expanded card's top-right
                // corner — the compact layout has no favorite toggle.
                Padding(
                  padding: EdgeInsets.only(right: expanded ? 32 : 0),
                  child: Text(
                    business.name,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.settingsTextDark,
                      fontSize: expanded ? 16 : 14,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.near_me,
                      size: expanded ? 12 : 11,
                      color: AppColors.settingsTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationLabel,
                        style: AppTextStyles.settingsSubtitle.copyWith(
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (expanded)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (firstActivity != null)
                        _MapTag(
                          label: firstActivity,
                          background: AppColors.settingsBackground,
                          textColor: AppColors.settingsTextMuted,
                          bordered: true,
                        ),
                      if (isEco)
                        _MapTag(
                          label: 'ECO',
                          background: AppColors.ecoGreen500,
                          textColor: AppColors.surface100,
                        ),
                      if (rating > 0)
                        _MapTag(
                          label: '★ ${rating.toStringAsFixed(1)}',
                          background: AppColors.settingsBackground,
                          textColor: AppColors.settingsTextDark,
                          bordered: true,
                        ),
                    ],
                  )
                // Compact layout shows at most one badge, ECO first — and
                // always in a fixed-height slot (empty when neither badge
                // applies) so every compact card has the exact same total
                // height regardless of which business is in it. Letting
                // this line's presence be optional was what made cards
                // overflow/misalign in the first place: a business with a
                // badge needed more room than one without, inside a
                // carousel whose height only budgeted for one fixed case.
                else
                  SizedBox(
                    height: _kCompactBadgeSlotHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: isEco
                          ? _MapTag(
                              label: 'ECO',
                              background: AppColors.ecoGreen500,
                              textColor: AppColors.surface100,
                            )
                          : rating > 0
                          ? _MapTag(
                              label: '★ ${rating.toStringAsFixed(1)}',
                              background: AppColors.settingsBackground,
                              textColor: AppColors.settingsTextDark,
                              bordered: true,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(22),
        // Always a 2px border so the compact/expanded swap only changes
        // color, never the card's outer size.
        border: Border.all(
          color: expanded ? AppColors.primary500 : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.mapCardShadow,
            offset: Offset(0, expanded ? 10 : 6),
            blurRadius: expanded ? 30 : 16,
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: expanded
            ? Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      header,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: onNavigate,
                                icon: const Icon(
                                  Icons.directions_outlined,
                                  size: 16,
                                ),
                                label: const Text('Cómo llegar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.profileDivider,
                                  foregroundColor: AppColors.settingsTextDark,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: AppTextStyles.mapRowTitle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                onPressed: onViewProfile,
                                icon: const Icon(
                                  Icons.storefront_outlined,
                                  size: 16,
                                ),
                                label: const Text('Ver perfil'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary500,
                                  foregroundColor: AppColors.settingsTextDark,
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: AppTextStyles.mapRowTitle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _FavoriteToggle(businessId: business.id),
                  ),
                ],
              )
            : header,
      ),
    );
  }
}

/// A small rounded tag used in the preview card ("Tour en lancha", "ECO",
/// "★ 4.8") — [bordered] adds the hairline outline the neutral-fill tags
/// use in Pantalla 2b (the solid ECO badge has none).
class _MapTag extends StatelessWidget {
  const _MapTag({
    required this.label,
    required this.background,
    required this.textColor,
    this.bordered = false,
  });

  final String label;
  final Color background;
  final Color textColor;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: bordered ? Border.all(color: AppColors.mapControlBorder) : null,
      ),
      child: Text(
        label,
        style: AppTextStyles.mapRowTitle.copyWith(
          fontSize: 11,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Floating favorite-heart circle over the carousel card's top-right
/// corner (Pantalla 2a — pale-pink background, distinct from the general
/// neutral-fill circle buttons elsewhere in the app) — same
/// [FavoritesService]/[GuestGuard] wiring as Home's favorite buttons, so a
/// business favorited from the map instantly reflects everywhere else.
class _FavoriteToggle extends StatelessWidget {
  const _FavoriteToggle({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritesService().idsNotifier,
      builder: (context, ids, _) {
        final isFavorite = ids.contains(businessId);
        return GestureDetector(
          onTap: () async {
            if (!await GuestGuard.allow(context, GuestFeature.favoritos)) {
              return;
            }
            await FavoritesService().toggleFavorite(businessId);
          },
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.mapFavoriteBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.mapCardShadow,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 15,
              color: AppColors.favoriteActive,
            ),
          ),
        );
      },
    );
  }
}
