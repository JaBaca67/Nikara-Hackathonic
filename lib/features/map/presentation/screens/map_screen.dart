import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nikara_app/core/services/directions_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/core/services/tts_service.dart';
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

/// Centro por defecto si falla la geolocalización (permiso denegado,
/// GPS apagado, etc.) — Managua, mismo fallback que el selector de mapa
/// del wizard "Registra tu negocio".
const LatLng _kDefaultMapCenter = LatLng(12.1363, -86.2513);

/// Evita que la cámara se aleje hacia el océano fuera de Nicaragua y sus
/// vecinos centroamericanos.
final LatLngBounds _kMapBounds = LatLngBounds(
  southwest: const LatLng(7.0, -92.0),
  northeast: const LatLng(18.5, -77.0),
);

const String _kAllCategories = 'Todos';

/// Margen extra sobre el viewport visible al consultar negocios (ver
/// [_MapScreenState._loadBusinessesInViewport]/[_MapScreenState._paddedBounds]).
const double _kViewportPadding = 0.3;

/// Mapa de exploración principal (`google_maps_flutter`) con negocios reales
/// de Supabase, sin destinos mock. El chrome visual sigue el diseño
/// "Rediseño de Níkara Home y Mapa", Pantalla 2b.
///
/// "Cómo llegar" usa [DirectionsService] y pasa por dos fases, siempre
/// dentro de la app (nunca delega a la app externa de Google Maps):
///  - **Fase 1 (preview)**: cámara enmarca origen+destino+ruta, selector
///    Automóvil/A pie (ver [_MapScreenState._changeTripMode]), panel con
///    distancia/ETA (ver [_MapScreenState._startTripPreview]).
///  - **Fase 2 (live)**: "Iniciar viaje" inclina la cámara, sigue
///    [Geolocator.getPositionStream], recorta la `Polyline` a lo que falta
///    y narra maniobras vía [TtsService] (ver
///    [_MapScreenState._confirmStartTrip]).
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.initialFocus});

  /// Negocio a centrar/seleccionar al cargar el mapa — se usa cuando se abre
  /// el mapa enfocado en un negocio en vez de exploración libre.
  /// `MainLayout` construye esta pantalla sin argumentos, así que esa vía
  /// llega por [MapFocusController] (ver [_MapScreenState._onFocusRequested]);
  /// este parámetro es para cuando el mapa se empuja como ruta propia.
  final MapFocusRequest? initialFocus;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _businessStorageService = BusinessStorageService();
  GoogleMapController? _mapController;

  /// Bitmap de pin sin seleccionar por [MapPinCategory] (Estado 19a). Si una
  /// categoría no está lista, cae a [MapPinCategory.general] para que nunca
  /// falte ícono.
  final Map<MapPinCategory, BitmapDescriptor> _pinIcons = {};

  /// Bitmap de pin seleccionado por [MapPinCategory] (Estado 19b) — mismo
  /// dorado en todas, solo cambia el glifo (ver [_buildPinBitmap]).
  final Map<MapPinCategory, BitmapDescriptor> _pinIconsSelected = {};
  BitmapDescriptor? _vehicleIcon;

  /// Bitmaps de badge de cluster por conteo (2..9, 10 = "9+", ver
  /// [_clusterIconKey]). Se generan una sola vez junto a los pines en
  /// [_loadMarkerIcons] porque `icon` de un marker necesita un
  /// [BitmapDescriptor] ya listo, no algo construido al vuelo dentro del
  /// build síncrono.
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

  /// Solicitud pendiente de centrar el mapa en un negocio — de
  /// [MapScreen.initialFocus] o [MapFocusController], aplicada por
  /// [_consumePendingFocus] cuando ya hay negocios cargados.
  MapFocusRequest? _pendingFocus;

  /// Cancela la suscripción realtime a cambios en `businesses` (otro
  /// dispositivo registra/edita un negocio) — ver
  /// [BusinessStorageService.subscribeToBusinessChanges].
  Future<void> Function()? _unsubscribeBusinessChanges;

  /// Junta una ráfaga de eventos realtime (una edición multi-fila dispara
  /// uno por fila) en un solo reload.
  Timer? _realtimeReloadDebounce;

  /// Todas las categorías de la tabla, deliberadamente sin acotar al
  /// viewport actual (ver [BusinessStorageService.getAllCategories]) para
  /// que los chips no cambien al hacer pan.
  List<String> _categories = const [];

  /// Zoom actual de cámara, actualizado desde [GoogleMap.onCameraMove] (sin
  /// `setState` ahí) para que esté al día cuando [GoogleMap.onCameraIdle]
  /// re-agrupa al terminar el gesto.
  double _currentZoom = 13;

  // --- Modo de preview de viaje, Fase 1 (ver _startTripPreview) ---
  bool _isPreviewingTrip = false;
  TravelMode _tripMode = TravelMode.driving;

  /// Fijado al tocar "Cómo llegar" y reusado en cada cambio de modo durante
  /// el preview — releer el GPS en cada tap no tendría sentido antes de que
  /// el viaje realmente empiece.
  LatLng? _tripOrigin;

  /// True mientras [_changeTripMode] recarga la ruta para el modo recién
  /// tocado — bloquea el selector para que un segundo tap no dispare otra
  /// solicitud a mitad de vuelo.
  bool _isChangingTripMode = false;

  // --- Modo de navegación en vivo, Fase 2 (ver _confirmStartTrip) ---
  bool _isNavigating = false;
  BusinessModel? _navigationTarget;
  DirectionsRoute? _navigationRoute;

  /// Polyline de la ruta recortada a lo que falta por recorrer —
  /// recalculada en cada fix de GPS (ver [_onPositionUpdate] y
  /// [nearestRouteIndex]). Usa la ruta completa hasta que llega el primer fix.
  List<LatLng>? _remainingRoutePoints;

  /// Índice del vértice de ruta más lejano ya confirmado como recorrido —
  /// monotónico, para que un salto de GPS nunca haga reaparecer un tramo ya
  /// recorrido de la polyline.
  int _routeTrimIndex = 0;

  /// Índice en `_navigationRoute!.steps` de la próxima maniobra mostrada en
  /// [_ManeuverBanner].
  int _currentStepIndex = 0;

  /// Distancia en metros al punto de maniobra del paso actual, recalculada
  /// en cada fix de GPS — el contador "En 80 m" de [_ManeuverBanner].
  double? _distanceToStepMeters;

  /// Evita que el anuncio TTS del paso actual se repita en cada fix de GPS
  /// dentro del radio de anuncio — debe sonar una sola vez por maniobra.
  bool _announcedCurrentStep = false;

  /// Velocidad en vivo desde el fix de GPS (`position.speed`, m/s)
  /// convertida a km/h — lectura de [_SpeedometerBadge].
  double? _currentSpeedKmh;

  /// Seguimiento de cámara estilo Waze/Google Maps — true mantiene el
  /// vehículo fijo al centro en cada fix (ver [_onPositionUpdate]). Arrastrar
  /// el mapa a mitad de viaje (detectado vía [GoogleMap.onCameraMoveStarted]
  /// en build(), ver [_programmaticCameraMoves]) lo pone en false para que
  /// el pan manual no se revierta en el siguiente fix; el botón flotante
  /// "Recentrar" ([_recenterNavigationCamera]) lo vuelve a poner en true.
  bool _isCameraLocked = true;

  /// Contador de animaciones de cámara en curso emitidas por nosotros (ver
  /// [_animateNavigationCamera]) — mientras sea positivo,
  /// [GoogleMap.onCameraMoveStarted] sabe que el movimiento es nuestro
  /// seguimiento automático, no un gesto del usuario, y no toca
  /// [_isCameraLocked]. Es contador y no bool porque dos animaciones
  /// solapadas (un fix de GPS llega a mitad de una animación) no deben dejar
  /// que la primera en terminar limpie una bandera que la segunda aún
  /// necesita.
  int _programmaticCameraMoves = 0;

  /// Metros restantes de ruta desde la posición actual del vehículo,
  /// recalculado en cada fix de GPS (ver [remainingRouteMeters]) — lectura
  /// "3,4 km restantes" de [_NavigationPanel]. Null hasta el primer fix.
  double? _remainingMeters;

  /// Toggle de voz en [_NavigationPanel] — silencia [TtsService] sin
  /// detener la navegación.
  bool _voiceGuidanceEnabled = false;
  StreamSubscription<Position>? _positionSub;
  late final AnimationController _vehicleLerpController;
  LatLng? _vehicleLerpFrom;
  LatLng? _vehicleLerpTo;
  double _vehicleLerpFromBearing = 0;
  double _vehicleLerpToBearingDelta = 0;
  LatLng? _vehicleDisplayPosition;
  double _vehicleDisplayBearing = 0;

  /// Ruta completa durante el preview (Fase 1), recortada a lo que falta
  /// una vez inicia la navegación en vivo (Fase 2, ver [_onPositionUpdate]).
  Set<Polyline> get _polylines {
    final route = _navigationRoute;
    if (route == null || (!_isNavigating && !_isPreviewingTrip)) {
      return const {};
    }
    final points = _isNavigating
        ? (_remainingRoutePoints ?? route.points)
        : route.points;
    if (points.length < 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('__route__'),
        points: points,
        color: AppColors.primary500,
        width: 5,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    // Se lee antes de suscribirse para no re-disparar _onFocusRequested con
    // lo que ya se acaba de tomar.
    _pendingFocus =
        widget.initialFocus ?? MapFocusController().pendingFocus.value;
    MapFocusController().pendingFocus.value = null;
    MapFocusController().pendingFocus.addListener(_onFocusRequested);
    MapFocusController().pendingRoute.addListener(_onRouteRequested);
    // Negocios creados/editados/eliminados en ESTE dispositivo (el wizard
    // incrementa esto al guardar) para que volver de "Registra tu negocio"
    // muestre el pin nuevo sin reabrir el mapa.
    BusinessStorageService.revision.addListener(_onBusinessesChanged);
    // La suscripción realtime para cambios hechos en otro lugar se abre
    // tras la primera carga exitosa — ver _loadAllBusinessesAndFitCamera.
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
    // La primera carga de negocios ocurre cuando el mapa reporta su región
    // visible inicial — ver onMapCreated en build().
  }

  @override
  void dispose() {
    MapFocusController().pendingFocus.removeListener(_onFocusRequested);
    MapFocusController().pendingRoute.removeListener(_onRouteRequested);
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
    unawaited(TtsService().stop());
    super.dispose();
  }

  /// Se agregó/editó/eliminó un negocio desde este dispositivo — recarga y
  /// reencuadra la cámara. Se omite a mitad de viaje (preview o live): mover
  /// la cámara lejos de una ruta en curso sería peor que un pin desactualizado,
  /// y [_stopNavigation]/[_cancelTripPreview] recargan al salir de todos modos.
  void _onBusinessesChanged() {
    if (_isNavigating || _isPreviewingTrip) return;
    unawaited(_loadAllBusinessesAndFitCamera());
  }

  void _onRemoteBusinessesChanged() {
    _realtimeReloadDebounce?.cancel();
    _realtimeReloadDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _onBusinessesChanged();
    });
  }

  /// Otra pantalla (hoy: "Cómo llegar" en `BusinessDetailScreen`) pidió que
  /// el mapa enfoque un negocio.
  void _onFocusRequested() {
    final request = MapFocusController().pendingFocus.value;
    if (request == null) return;
    // Limpiarlo aquí también re-entra a este listener con null, que la
    // guarda de arriba descarta.
    MapFocusController().pendingFocus.value = null;
    _pendingFocus = request;
    // Si está cargando, _loadAllBusinessesAndFitCamera lo consume al terminar.
    if (!_isLoading) unawaited(_consumePendingFocus());
  }

  /// Otra pantalla (hoy: "Cómo llegar" en `EcoDetailScreen`) pidió iniciar
  /// un preview de ruta hacia un punto que no es un negocio registrado.
  void _onRouteRequested() {
    final request = MapFocusController().pendingRoute.value;
    if (request == null) return;
    MapFocusController().pendingRoute.value = null;
    unawaited(_startTripPreview(_syntheticDestination(request)));
  }

  /// [_startTripPreview] recibe un [BusinessModel] porque todo otro disparador
  /// de "Cómo llegar" ya tiene uno a mano. En vez de generalizar todo el
  /// estado de preview/navegación a un tipo compartido más chico, se adapta
  /// la solicitud de ruta a un [BusinessModel] desechable (nunca persistido
  /// ni mostrado como card) del que solo se leen name/latitude/longitude
  /// (y category, para que el pin use el glifo eco).
  BusinessModel _syntheticDestination(MapRouteRequest request) {
    return BusinessModel(
      id: request.destinationId,
      name: request.destinationName,
      category: 'Eco',
      description: '',
      city: '',
      locationText: '',
      latitude: request.latitude,
      longitude: request.longitude,
      contactPhone: '',
      allowsReservations: false,
      hostName: '',
    );
  }

  /// Centra y selecciona el negocio de [_pendingFocus], igual que un tap en
  /// el pin. Si el negocio ya no está en el set cargado (p. ej. se borró
  /// entre pantallas), solo vuela a las coordenadas.
  Future<void> _consumePendingFocus() async {
    final request = _pendingFocus;
    if (request == null || _mapController == null) return;
    _pendingFocus = null;

    // Un filtro de categoría/búsqueda residual podría ocultar el negocio
    // pedido, así que el foco resetea ambos.
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

  /// Altura objetivo del carrusel — expandida (Estado 19b) con card
  /// seleccionada, compacta (Estado 19a) si no. Alimenta tanto el
  /// [AnimatedContainer] del carrusel como el offset del botón de
  /// recentrar, para que ninguno salte al cambiar la selección.
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

  /// Genera todos los estados de pin (seleccionado/no, por categoría) como
  /// bitmaps porque `google_maps_flutter` no permite un widget Flutter vivo
  /// como marker (a diferencia de `flutter_map`'s `Marker.child`), así que
  /// cada badge de Pantalla 2b se dibuja en un canvas.
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

  /// Bitmap de [category] en el estado [selected]; cae a
  /// [MapPinCategory.general] si esa categoría aún no está lista.
  BitmapDescriptor? _pinBitmapFor(
    MapPinCategory category, {
    required bool selected,
  }) {
    final byCategory = selected ? _pinIconsSelected : _pinIcons;
    return byCategory[category] ?? byCategory[MapPinCategory.general];
  }

  /// 9+ se agrupa en un solo bitmap compartido en vez de generar uno por
  /// conteo exacto — la densidad de negocios de Nikara no justifica un
  /// badge exacto tipo "47".
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
        // Sin fontFamily: este TextPainter dibuja sobre un canvas de
        // dart:ui para generar el bitmap del pin, donde google_fonts no puede
        // resolver una familia — se usa la del sistema, como cualquier otro
        // texto pintado a mano.
        style: TextStyle(
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
    // Sin imagePixelRatio el bitmap se trata como 1:1, duplicando/triplicando
    // el tamaño visual del pin al renderizarlo a mayor densidad.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  /// "Puck" de navegación dorado (círculo + flecha) dibujado apuntando al
  /// norte por defecto, para que [Marker.rotation] lo rote según el rumbo
  /// real del teléfono durante el tracking en vivo.
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
    // Sin imagePixelRatio el bitmap se trata como 1:1, duplicando/triplicando
    // el tamaño visual del pin al renderizarlo a mayor densidad.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  /// Pin inactivo (Estado 19a): círculo blanco con anillo y glifo en el
  /// color de acento de [MapPinCategory] (ver [mapPinColor]).
  static const double _kPinDiameter = 34;

  /// Pin seleccionado (Estado 19b): círculo dorado más grande con cola,
  /// para que el negocio activo se lea como un pin real clavado en su
  /// coordenada y no solo un punto recoloreado.
  static const double _kSelectedPinDiameter = 42;
  static const double _kSelectedPinTail = 11;
  static const double _kSelectedPinHeight =
      _kSelectedPinDiameter + _kSelectedPinTail;

  /// Ancla el pin seleccionado por la punta de la cola (termina 1.5px
  /// lógicos arriba del borde inferior, dejando espacio para el blur).
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
      // Se dibuja antes que el círculo para que este cubra la unión.
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
        // El pin seleccionado usa siempre un anillo neutro dorado/crema (el
        // relleno dorado ya comunica "seleccionado"); el no seleccionado usa
        // el color de acento de su categoría para ser legible sin depender
        // del glifo.
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
    // Sin imagePixelRatio el bitmap se trata como 1:1, duplicando/triplicando
    // el tamaño visual del pin al renderizarlo a mayor densidad.
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: devicePixelRatio,
    );
  }

  Future<void> _animateCameraTo(LatLng target, {double zoom = 16}) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  /// Centra el mapa en la posición actual y la guarda para el "a X km" de
  /// [_BusinessPreviewSheet]. Cualquier falla (GPS apagado, permiso
  /// denegado, timeout) se ignora silenciosamente y el mapa se queda en el
  /// fallback de Managua. Usa [LocationService] para que Home y Mapa
  /// compartan una posición cacheada en vez de pedir permiso cada uno.
  Future<void> _locateUser({bool animate = false}) async {
    setState(() => _locatingUser = true);
    try {
      final position = await LocationService().getCurrentPosition(
        forceRefresh: animate,
      );
      if (!mounted || position == null) return;
      setState(() {
        _userPosition = position;
        // Durante la navegación el puck del vehículo YA es el marcador de
        // usuario — activar el punto azul de Google dibujaría un segundo.
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

  Future<void> _loadCategories() async {
    try {
      final categories = await _businessStorageService.getAllCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } on BusinessServiceException {
      // No fatal — los chips solo caen a "Todos" hasta el próximo load
      // exitoso; _loadBusinessesInViewport es quien muestra el error real.
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _loadAllBusinessesAndFitCamera();
  }

  /// Trae solo lo que está dentro del viewport actual (con margen
  /// [_kViewportPadding]) en cada [GoogleMap.onCameraIdle], para no
  /// descargar la tabla `businesses` completa al hacer pan/zoom.
  ///
  /// Los resultados se *fusionan* en [_businesses] en vez de reemplazarlo:
  /// es una carga incremental, así que hacer zoom en un pin no debe hacer
  /// desaparecer los demás. [_loadAllBusinessesAndFitCamera] es quien
  /// reemplaza el set completo (y así refleja negocios borrados en otro
  /// lado). Es silencioso a propósito: sin spinner ni overlay de error para
  /// un refresco de fondo que no afecta los pines ya visibles.
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
        // Defensivo solamente: `businesses.location` es NOT NULL, pero sin
        // coordenadas no se puede anclar un pin.
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

  /// Expande el bounds por [factor] en cada lado para que negocios justo
  /// fuera del borde visible ya estén cargados cuando un pan pequeño los
  /// revele, sin esperar un round-trip por cada pan.
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

  /// Punto de entrada único para "enfocar este negocio": tap en marker, tap
  /// en card del carrusel, o búsqueda. Deliberadamente NO se dispara solo
  /// con el scroll del carrusel — deslizar solo hojea, tocar confirma.
  Future<void> _selectBusiness(BusinessModel business) async {
    setState(() => _selectedBusinessId = business.id);
    unawaited(
      _animateCameraTo(LatLng(business.latitude!, business.longitude!)),
    );
    final index = _filteredBusinesses.indexWhere((b) => b.id == business.id);
    if (index == -1) return;
    // El carrusel aún no está montado en los primeros frames — caso de una
    // solicitud de foco externa (ver [_consumePendingFocus]). Salta a la
    // card en cuanto exista.
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

  /// Tap directo en pin (vs. card o búsqueda): además de seleccionar, abre
  /// un bottom sheet estilo Google Maps con el detalle — Estado 19b separa
  /// ambos comportamientos (card solo mueve cámara, pin abre panel). Tocar
  /// el pin ya seleccionado lo deselecciona en vez de reabrir el sheet.
  Future<void> _onMarkerTapped(BusinessModel business) async {
    if (business.id == _selectedBusinessId) {
      setState(() => _selectedBusinessId = null);
      return;
    }
    await _selectBusiness(business);
    if (!mounted) return;
    await _showBusinessSheet(business);
  }

  /// Espejo del toggle de [_onMarkerTapped] pero para cards del carrusel:
  /// re-tocar la card ya seleccionada la deselecciona (colapsa a Estado
  /// 19a) sin mover cámara ni el scroll.
  void _onCarouselCardTapped(BusinessModel business) {
    if (business.id == _selectedBusinessId) {
      setState(() => _selectedBusinessId = null);
      return;
    }
    unawaited(_selectBusiness(business));
  }

  /// Reusa [_BusinessCarouselCard] tal cual dentro del chrome de
  /// [_PinDetailSheetChrome] en vez de duplicar ese layout.
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
            _startTripPreview(business);
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

  /// Chips (Estado 19a): filtran pines y carrusel, y reencuadran la cámara
  /// a lo que queda visible.
  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      // Un negocio que el nuevo filtro oculta no puede seguir seleccionado.
      final stillVisible = _filteredBusinesses.any(
        (b) => b.id == _selectedBusinessId,
      );
      if (!stillVisible) _selectedBusinessId = null;
    });
    // La lista del carrusel cambió, así que la página actual apuntaría a
    // un negocio distinto.
    _jumpCarouselTo(0);
    unawaited(_fitCameraToBusinesses(_filteredBusinesses));
  }

  /// Carga inicial: trae todos los negocios dentro de [_kMapBounds] (no solo
  /// el viewport inicial) para que [_fitCameraToBusinesses] tenga el set
  /// completo. A escala real (cientos+ de negocios) esto debería acotarse a
  /// "ciudades cercanas"; hoy no se justifica esa complejidad.
  /// [_loadBusinessesInViewport] toma el control en cada pan/zoom posterior.
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
        // Un negocio que desapareció de la tabla no puede seguir seleccionado.
        if (_businessById(_selectedBusinessId ?? '') == null) {
          _selectedBusinessId = null;
        }
        _isLoading = false;
      });
      // Solo se abre tras el primer load exitoso — evita mantener un socket
      // realtime en pantallas que nunca cargaron (y deja a los widget tests,
      // que no llegan aquí, sin una conexión viva que cerrar).
      _unsubscribeBusinessChanges ??= _businessStorageService
          .subscribeToBusinessChanges(_onRemoteBusinessesChanged);
      // Una solicitud de foco pendiente gana sobre el encuadre general —
      // si no, la cámara encuadraría todo y luego volaría al pin pedido.
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

  /// Encuadra la cámara sobre todos los [businesses] vía [_boundsForPoints].
  /// Cae al centro por defecto de Managua si no hay nada que encuadrar.
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

  /// "Cómo llegar" — Fase 1: pide la posición actual y una ruta real (nunca
  /// una línea recta) vía [DirectionsService], y entra en modo preview en
  /// vez de arrancar el viaje de inmediato (cámara encuadra origen+destino+
  /// ruta, selector de modo, panel de distancia/ETA — ver
  /// [_confirmStartTrip] para Fase 2). Si no se puede obtener una ruta real
  /// (sin key, sin red, sin resultado), muestra la razón en un snackbar y
  /// nunca dibuja una ruta inventada.
  Future<void> _startTripPreview(BusinessModel business) async {
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

    final route = await _fetchTripRoute(
      origin: origin,
      destination: destination,
      mode: TravelMode.driving,
    );
    if (route == null || !mounted) return;

    setState(() {
      _isPreviewingTrip = true;
      _tripMode = TravelMode.driving;
      _tripOrigin = origin;
      _navigationTarget = business;
      _navigationRoute = route;
      _selectedBusinessId = business.id;
    });
    // Oculta el bottom nav de MainLayout durante ambas fases del viaje —
    // carrusel y chrome de búsqueda ya se ocultan solos en build() según
    // `_isPreviewingTrip`/`_isNavigating`.
    MapFocusController().navigationActive.value = true;
    await _fitTripPreviewCamera();
  }

  /// Compartido por [_startTripPreview] y [_changeTripMode] — envuelve
  /// [DirectionsService.getRoute] mostrando el snackbar de error y
  /// devuelve `null` en vez de lanzar, para no duplicar el try/catch.
  Future<DirectionsRoute?> _fetchTripRoute({
    required LatLng origin,
    required LatLng destination,
    required TravelMode mode,
  }) async {
    try {
      return await DirectionsService().getRoute(
        origin: origin,
        destination: destination,
        mode: mode,
      );
    } on DirectionsServiceException catch (e) {
      debugPrint('[MapScreen] route failed: ${e.message}');
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return null;
    }
  }

  /// Encuadra origen + destino + la polyline completa (no solo los puntos
  /// de la ruta), para que ambos pines queden dentro del frame aunque el
  /// `overview_polyline` de Directions empiece/termine unos metros corto.
  Future<void> _fitTripPreviewCamera() async {
    final origin = _tripOrigin;
    final target = _navigationTarget;
    final route = _navigationRoute;
    if (origin == null || target == null || route == null) return;
    final destination = LatLng(target.latitude!, target.longitude!);
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        _boundsForPoints([origin, destination, ...route.points]),
        72,
      ),
    );
  }

  /// Tap en el selector de modo durante el preview — si la recarga falla,
  /// deja la ruta/modo anterior en pantalla en vez de limpiarlo, para que
  /// una solicitud fallida no deje el preview sin nada dibujado.
  Future<void> _changeTripMode(TravelMode mode) async {
    if (mode == _tripMode || _isChangingTripMode) return;
    final origin = _tripOrigin;
    final target = _navigationTarget;
    if (origin == null || target == null || target.latitude == null) return;
    setState(() => _isChangingTripMode = true);
    final route = await _fetchTripRoute(
      origin: origin,
      destination: LatLng(target.latitude!, target.longitude!),
      mode: mode,
    );
    if (!mounted) return;
    if (route == null) {
      setState(() => _isChangingTripMode = false);
      return;
    }
    setState(() {
      _tripMode = mode;
      _navigationRoute = route;
      _isChangingTripMode = false;
    });
    await _fitTripPreviewCamera();
  }

  /// "Iniciar viaje" — Fase 1 -> Fase 2: inicia navegación GPS en vivo con
  /// la ruta ya cargada, inclina la cámara a vista de manejo y abre el
  /// stream de posición que alimenta [_onPositionUpdate].
  Future<void> _confirmStartTrip() async {
    final origin = _tripOrigin;
    final route = _navigationRoute;
    if (origin == null || route == null) return;

    final initialBearing = route.points.length > 1
        ? Geolocator.bearingBetween(
            origin.latitude,
            origin.longitude,
            route.points[1].latitude,
            route.points[1].longitude,
          )
        : 0.0;

    setState(() {
      _isPreviewingTrip = false;
      _isNavigating = true;
      _isCameraLocked = true;
      _remainingMeters = route.distanceMeters.toDouble();
      _remainingRoutePoints = route.points;
      _routeTrimIndex = 0;
      _currentStepIndex = 0;
      _distanceToStepMeters = null;
      _announcedCurrentStep = false;
      _currentSpeedKmh = null;
      _vehicleDisplayPosition = origin;
      _vehicleDisplayBearing = initialBearing;
      // El puck del vehículo reemplaza al punto azul de Google — ambos a
      // la vez mostrarían dos marcadores de usuario superpuestos.
      _myLocationEnabled = false;
    });

    // Transición 3D inmediata — _onPositionUpdate toma el control del
    // encuadre desde el primer fix de GPS real.
    await _animateNavigationCamera(
      CameraPosition(
        target: origin,
        zoom: _kNavCameraZoom,
        tilt: _kNavCameraTilt,
        bearing: initialBearing,
      ),
    );

    if (_voiceGuidanceEnabled && route.steps.isNotEmpty) {
      unawaited(TtsService().speak(route.steps.first.instruction));
    }

    await _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(_onPositionUpdate);
  }

  /// Sale del preview (Fase 1) sin llegar a iniciar el viaje — el espejo
  /// de [_stopNavigation] para esta fase.
  Future<void> _cancelTripPreview() async {
    MapFocusController().navigationActive.value = false;
    final target = _navigationTarget;
    setState(() {
      _isPreviewingTrip = false;
      _tripMode = TravelMode.driving;
      _tripOrigin = null;
      _navigationTarget = null;
      _navigationRoute = null;
    });
    if (target != null) await _selectBusiness(target);
  }

  /// "Cancelar viaje" — limpia la ruta y vuelve a Estado 19a/19b con el
  /// destino aún seleccionado, para no dejar un mapa en blanco.
  Future<void> _stopNavigation() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _vehicleLerpController.stop();
    unawaited(TtsService().stop());
    MapFocusController().navigationActive.value = false;
    if (!mounted) return;
    final target = _navigationTarget;
    setState(() {
      _isNavigating = false;
      _isCameraLocked = true;
      _navigationTarget = null;
      _navigationRoute = null;
      _remainingMeters = null;
      _remainingRoutePoints = null;
      _routeTrimIndex = 0;
      _currentStepIndex = 0;
      _distanceToStepMeters = null;
      _announcedCurrentStep = false;
      _currentSpeedKmh = null;
      _tripOrigin = null;
      _tripMode = TravelMode.driving;
      _vehicleDisplayPosition = null;
      _myLocationEnabled = _userPosition != null;
    });
    if (target != null) await _selectBusiness(target);
  }

  /// Zoom/tilt de cámara para la vista de manejo estilo Waze — usado por
  /// la transición inicial, el seguimiento GPS y "Recentrar" por igual.
  static const double _kNavCameraZoom = 17.5;
  static const double _kNavCameraTilt = 50;

  /// Envuelve toda animación de cámara emitida durante navegación en vivo
  /// para que [GoogleMap.onCameraMoveStarted] distinga nuestras
  /// actualizaciones de seguimiento del arrastre real del usuario — solo
  /// este último debe apagar [_isCameraLocked].
  Future<void> _animateNavigationCamera(CameraPosition position) async {
    _programmaticCameraMoves++;
    try {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(position),
      );
    } finally {
      _programmaticCameraMoves--;
    }
  }

  Future<void> _recenterNavigationCamera() async {
    setState(() => _isCameraLocked = true);
    final position = _vehicleDisplayPosition;
    if (position == null) return;
    await _animateNavigationCamera(
      CameraPosition(
        target: position,
        zoom: _kNavCameraZoom,
        tilt: _kNavCameraTilt,
        bearing: _vehicleDisplayBearing,
      ),
    );
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

  /// Distancia al punto de maniobra bajo la cual se anuncia por TTS.
  static const double _kManeuverAnnounceMeters = 80;

  /// Distancia bajo la cual una maniobra se considera alcanzada y
  /// [_onPositionUpdate] avanza al siguiente paso.
  static const double _kManeuverAdvanceMeters = 25;

  /// Se dispara en cada fix de GPS: calcula el rumbo por movimiento real
  /// (no la brújula del teléfono, que salta mucho más) y anima el puck
  /// suavemente hacia la nueva posición en vez de saltar de golpe. También
  /// recorta la ruta dibujada, avanza/anuncia la maniobra y actualiza el
  /// velocímetro.
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
      // Por debajo de esto, el ruido del GPS hace inútil el rumbo — se
      // mantiene la orientación previa del puck en vez de tembloriquear.
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
      _routeTrimIndex = nearestRouteIndex(
        routePoints: route.points,
        current: newPos,
        minIndex: _routeTrimIndex,
      );
      final trimmedPoints = [newPos, ...route.points.sublist(_routeTrimIndex)];

      var stepIndex = _currentStepIndex;
      var distanceToStep = _distanceToStepMeters;
      var announced = _announcedCurrentStep;
      if (stepIndex < route.steps.length) {
        final step = route.steps[stepIndex];
        distanceToStep = Geolocator.distanceBetween(
          newPos.latitude,
          newPos.longitude,
          step.startLocation.latitude,
          step.startLocation.longitude,
        );
        if (!announced &&
            distanceToStep <= _kManeuverAnnounceMeters &&
            _voiceGuidanceEnabled) {
          announced = true;
          unawaited(TtsService().speak(step.instruction));
        }
        if (distanceToStep <= _kManeuverAdvanceMeters &&
            stepIndex < route.steps.length - 1) {
          stepIndex++;
          announced = false;
          distanceToStep = null;
        }
      }

      setState(() {
        _remainingMeters = remainingRouteMeters(
          routePoints: trimmedPoints,
          current: newPos,
        );
        _remainingRoutePoints = trimmedPoints;
        _currentStepIndex = stepIndex;
        _distanceToStepMeters = distanceToStep;
        _announcedCurrentStep = announced;
        _currentSpeedKmh = (position.speed * 3.6).clamp(0, 300);
      });
    }

    // Sigue al vehículo con el mapa orientado hacia el rumbo e inclinado,
    // como una vista turn-by-turn. Se omite si el usuario ya arrastró el
    // mapa (ver [_isCameraLocked]) para no revertir su pan manual.
    if (_isCameraLocked) {
      unawaited(
        _animateNavigationCamera(
          CameraPosition(
            target: newPos,
            zoom: _kNavCameraZoom,
            tilt: _kNavCameraTilt,
            bearing: targetBearing,
          ),
        ),
      );
    }
  }

  /// ETA de lo que falta: duración total de la ruta escalada por la
  /// fracción de distancia restante. Deliberadamente derivada de la única
  /// llamada a Directions al iniciar — un ETA realmente en vivo implicaría
  /// re-pedir ruta en cada fix de GPS, fuera del alcance de este MVP.
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

  String get _tripPreviewDistanceLabel {
    final route = _navigationRoute;
    if (route == null) return '';
    return route.distanceKm < 1
        ? '${route.distanceMeters} m'
        : '${route.distanceKm.toStringAsFixed(1)} km';
  }

  /// Hora estimada de llegada (`DateTime.now()` + duración de la ruta),
  /// recalculada en cada build, no cacheada.
  String get _tripPreviewArrivalLabel {
    final route = _navigationRoute;
    if (route == null) return '';
    final arrival = DateTime.now().add(
      Duration(seconds: route.durationSeconds),
    );
    return '${arrival.hour.toString().padLeft(2, '0')}:'
        '${arrival.minute.toString().padLeft(2, '0')}';
  }

  String get _maneuverDistanceLabel {
    final meters = _distanceToStepMeters;
    if (meters == null) return '';
    return meters < 1000
        ? 'En ${meters.round()} m'
        : 'En ${(meters / 1000).toStringAsFixed(1)} km';
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

  /// Delta angular ([-180, 180]) por el camino corto — sin esto, animar
  /// 350° -> 10° giraría el puck casi una vuelta completa en vez de solo
  /// cruzar el norte.
  static double _shortestBearingDelta(double from, double to) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }

  Set<Marker> _buildMarkers(List<BusinessModel> businesses) {
    // Los bitmaps de MapPinCategory.general (fallback de todos los demás,
    // ver _pinBitmapFor) aún no cargan.
    if (_pinIcons[MapPinCategory.general] == null ||
        _pinIconsSelected[MapPinCategory.general] == null) {
      return const {};
    }

    final markers = <Marker>{};

    // Durante ambas fases de viaje solo queda el pin de destino (más el
    // puck del vehículo si es en vivo) — sin clustering, siempre es un
    // único pin.
    final target = _navigationTarget;
    if ((_isNavigating || _isPreviewingTrip) && target != null) {
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
          if (icon == null) continue; // Bitmap aún no cargado.
          markers.add(
            Marker(
              markerId: MarkerId(business.id),
              position: cluster.position,
              icon: icon,
              // El pin seleccionado se ancla por la punta de su cola, los
              // demás por su centro.
              anchor: isSelected ? _kSelectedPinAnchor : const Offset(0.5, 0.5),
              // Por encima de sus vecinos para no quedar tapado entre pines
              // muy juntos.
              zIndexInt: isSelected ? 2 : 0,
              onTap: () => _onMarkerTapped(business),
            ),
          );
        } else {
          final icon = _clusterIcons[_clusterIconKey(cluster.count)];
          if (icon == null) {
            continue; // Bitmap aún no cargado — se omite este frame.
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

  /// Encuadra la cámara a los bordes exactos de los miembros del cluster
  /// (en vez de un zoom fijo) para que se resuelva en un solo tap sin
  /// importar qué tan dispersos estén.
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
          // Mapa a pantalla completa, incluso detrás del status bar; solo
          // el chrome flotante respeta SafeArea (layout "map first" de
          // Pantalla 2b).
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kDefaultMapCenter,
              zoom: 13,
            ),
            // Oculta los íconos nativos de POI/transporte de Google y
            // retiñe el mapa a la paleta crema/arena — ver map_style.dart.
            style: nikaraMapStyle,
            onMapCreated: _onMapCreated,
            // Sin setState aquí a propósito: durante un drag/pinch esto
            // puede dispararse muchas veces por segundo. Solo guarda el
            // zoom para que onCameraIdle (que sí hace setState) lo use al
            // asentarse el gesto.
            onCameraMove: (position) => _currentZoom = position.zoom,
            // Este callback dispara tanto por gestos del usuario como por
            // nuestras propias animaciones de seguimiento GPS;
            // `_programmaticCameraMoves` distingue ambos casos — solo un
            // gesto real de usuario debe desbloquear la cámara.
            onCameraMoveStarted: () {
              if (_isNavigating &&
                  _isCameraLocked &&
                  _programmaticCameraMoves == 0) {
                setState(() => _isCameraLocked = false);
              }
            },
            // Se omite navegando (la cámara se mueve en cada fix de GPS, y
            // recargar el viewport en cada uno sería un desperdicio con los
            // pines ocultos) y a mitad de preview (esos movimientos de
            // cámara son encuadres automáticos, no paneo del usuario).
            onCameraIdle: () {
              if (_isNavigating || _isPreviewingTrip) return;
              unawaited(_loadBusinessesInViewport());
            },
            minMaxZoomPreference: const MinMaxZoomPreference(6, 18),
            cameraTargetBounds: CameraTargetBounds(_kMapBounds),
            // Las extrusiones 3D nativas de edificios de Google se ven en
            // gris industrial sin importar `style` (ese JSON solo cubre
            // colores 2D) y chocan con la paleta crema al inclinar la
            // cámara en navegación — se desactivan para mantener el estilo
            // consistente.
            buildingsEnabled: false,
            myLocationEnabled: _myLocationEnabled,
            // El botón de recentrar propio reemplaza al nativo.
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
                color: AppColors.mapLoadingOverlay,
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
          // Oculto en ambas fases de viaje: el selector de modo (Fase 1) y
          // el banner de maniobra (Fase 2) toman el tope de la pantalla.
          if (!_isNavigating && !_isPreviewingTrip)
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
          // Fase 1 — preview: botón de cerrar + selector Automóvil/A pie.
          // Explícitamente `Positioned` (no un hijo suelto del Stack): con
          // `fit: StackFit.expand` un hijo no posicionado se estira a toda
          // la pantalla y un `Row` centraría su contenido en medio de esa
          // altura forzada en vez de pegarlo arriba.
          if (_isPreviewingTrip)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.close_rounded,
                    onTap: _cancelTripPreview,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TripModeSelector(
                      mode: _tripMode,
                      isLoading: _isChangingTripMode,
                      onChanged: _changeTripMode,
                    ),
                  ),
                ],
              ),
            ),
          // Carrusel persistente "Recomendaciones destacadas" (Pantalla 2a):
          // scrollear es solo navegar, no selecciona ni mueve la cámara —
          // solo tocar una card o su pin lo hace.
          if (!_isNavigating && !_isPreviewingTrip && filtered.isNotEmpty)
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
                                  onNavigate: () => _startTripPreview(business),
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
          // Fase 1 — panel inferior del preview: distancia, ETA, hora de
          // llegada y botón "Iniciar viaje" (ver [_confirmStartTrip]).
          if (_isPreviewingTrip && _navigationTarget != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _TripPreviewPanel(
                    destinationName: _navigationTarget!.name,
                    distanceLabel: _tripPreviewDistanceLabel,
                    etaLabel: _remainingEtaLabel,
                    arrivalLabel: _tripPreviewArrivalLabel,
                    onStart: _confirmStartTrip,
                  ),
                ),
              ),
            ),
          // Fase 2 — banner de maniobra (siguiente giro + distancia, ícono
          // derivado de `maneuver` de Directions, ver [_maneuverIcon]).
          // `Positioned` explícito por la misma razón que el de arriba: sin
          // eso, `StackFit.expand` lo estira a pantalla completa.
          if (_isNavigating &&
              _navigationRoute != null &&
              _currentStepIndex < _navigationRoute!.steps.length)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              child: _ManeuverBanner(
                instruction:
                    _navigationRoute!.steps[_currentStepIndex].instruction,
                maneuver: _navigationRoute!.steps[_currentStepIndex].maneuver,
                distanceLabel: _maneuverDistanceLabel,
              ),
            ),
          // Estado 19c — panel inferior con ETA, distancia restante y
          // acciones Voz/Cancelar. El bottom nav de MainLayout está oculto
          // mientras se muestra (ver _confirmStartTrip).
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
          // Fase 2 — velocímetro, abajo a la izquierda para no solaparse
          // con el botón de recentrar ni el panel inferior.
          if (_isNavigating && _currentSpeedKmh != null)
            Positioned(
              left: 16,
              bottom: _kNavigationPanelHeight + 16,
              child: SafeArea(
                top: false,
                bottom: false,
                child: _SpeedometerBadge(speedKmh: _currentSpeedKmh!),
              ),
            ),
          // Oculto por completo mientras navega con la cámara ya bloqueada
          // al vehículo — nada que recentrar. Al arrastrar el mapa (ver
          // `onCameraMoveStarted`) se vuelve el botón de mira "Recentrar".
          if (!_isNavigating || !_isCameraLocked)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              right: 16,
              // Se posiciona justo encima de lo que ocupe el fondo de la
              // pantalla (panel de navegación, panel de preview, o carrusel).
              bottom: _isNavigating
                  ? _kNavigationPanelHeight + 16
                  : _isPreviewingTrip
                  ? _kTripPreviewPanelHeight + 16
                  : (filtered.isEmpty ? 16 : _carouselHeight + 16),
              child: SafeArea(
                top: false,
                bottom: false,
                child: _isNavigating
                    ? _RecenterButton(
                        isLoading: false,
                        icon: Icons.center_focus_strong_rounded,
                        onPressed: _recenterNavigationCamera,
                      )
                    : _RecenterButton(
                        isLoading: _locatingUser,
                        onPressed: () => _locateUser(animate: true),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  /// Desactivar a mitad de un anuncio lo corta de inmediato en vez de
  /// dejarlo terminar; reactivar no repite nada, solo deja hablar a la
  /// próxima maniobra.
  void _toggleVoiceGuidance() {
    setState(() => _voiceGuidanceEnabled = !_voiceGuidanceEnabled);
    if (!_voiceGuidanceEnabled) unawaited(TtsService().stop());
  }
}

/// Altura del carrusel sin card seleccionada (Estado 19a) — con margen
/// extra para redondeo de fuente, evita overflow de `RenderFlex`.
const double _kCarouselCompactHeight = 108;

/// Altura del carrusel con card expandida y "Cómo llegar"/"Ver perfil"
/// (Estado 19b), Pantalla 2a.
const double _kCarouselExpandedHeight = 168;

/// Altura fija de la línea de badge en la card compacta — reservada haya
/// o no badge, para que todas las cards midan igual.
const double _kCompactBadgeSlotHeight = 26;

/// Espacio que ocupa [_NavigationPanel] al fondo — lo que el botón de
/// recentrar debe despejar mientras navega.
const double _kNavigationPanelHeight = 132;

/// Espacio que ocupa [_TripPreviewPanel] al fondo durante el preview.
const double _kTripPreviewPanelHeight = 170;

/// Mapea el `maneuver` de Directions al ícono correspondiente; `null`
/// (paso sin maniobra especial, típicamente el primero de la ruta) cae a
/// una flecha recta.
IconData _maneuverIcon(String? maneuver) {
  return switch (maneuver) {
    'turn-left' => Icons.turn_left_rounded,
    'turn-right' => Icons.turn_right_rounded,
    'turn-slight-left' => Icons.turn_slight_left_rounded,
    'turn-slight-right' => Icons.turn_slight_right_rounded,
    'turn-sharp-left' => Icons.turn_sharp_left_rounded,
    'turn-sharp-right' => Icons.turn_sharp_right_rounded,
    'uturn-left' => Icons.u_turn_left_rounded,
    'uturn-right' => Icons.u_turn_right_rounded,
    'roundabout-left' => Icons.roundabout_left_rounded,
    'roundabout-right' => Icons.roundabout_right_rounded,
    'merge' => Icons.merge_rounded,
    'fork-left' || 'ramp-left' || 'keep-left' => Icons.fork_left_rounded,
    'fork-right' || 'ramp-right' || 'keep-right' => Icons.fork_right_rounded,
    _ => Icons.straight_rounded,
  };
}

/// Se mantiene en la capa de presentación en vez de en el enum porque
/// [TravelMode] es un tipo plano de la capa de servicio.
IconData _travelModeIcon(TravelMode mode) => switch (mode) {
  TravelMode.driving => Icons.directions_car_rounded,
  TravelMode.walking => Icons.directions_walk_rounded,
};

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
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
        child: Icon(icon, size: 18, color: AppColors.settingsTextDark),
      ),
    );
  }
}

class _TripModeSelector extends StatelessWidget {
  const _TripModeSelector({
    required this.mode,
    required this.isLoading,
    required this.onChanged,
  });

  final TravelMode mode;
  final bool isLoading;
  final ValueChanged<TravelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(999),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final travelMode in TravelMode.values)
            _TripModeButton(
              travelMode: travelMode,
              selected: travelMode == mode,
              onTap: isLoading ? null : () => onChanged(travelMode),
            ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TripModeButton extends StatelessWidget {
  const _TripModeButton({
    required this.travelMode,
    required this.selected,
    required this.onTap,
  });

  final TravelMode travelMode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _travelModeIcon(travelMode),
              size: 16,
              color: selected
                  ? AppColors.settingsTextDark
                  : AppColors.settingsTextMuted,
            ),
            const SizedBox(width: 6),
            Text(
              travelMode.label,
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 12,
                color: selected
                    ? AppColors.settingsTextDark
                    : AppColors.settingsTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripPreviewPanel extends StatelessWidget {
  const _TripPreviewPanel({
    required this.destinationName,
    required this.distanceLabel,
    required this.etaLabel,
    required this.arrivalLabel,
    required this.onStart,
  });

  final String destinationName;
  final String distanceLabel;
  final String etaLabel;
  final String arrivalLabel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            destinationName,
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.settingsTextDark,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TripStat(label: 'Distancia', value: distanceLabel),
              ),
              Expanded(
                child: _TripStat(label: 'Tiempo', value: etaLabel),
              ),
              Expanded(
                child: _TripStat(label: 'Llegada', value: arrivalLabel),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: const Text('Iniciar viaje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.settingsTextDark,
                elevation: 0,
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

class _TripStat extends StatelessWidget {
  const _TripStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.settingsTextDark,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.mapRowCaption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ManeuverBanner extends StatelessWidget {
  const _ManeuverBanner({
    required this.instruction,
    required this.maneuver,
    required this.distanceLabel,
  });

  final String instruction;
  final String? maneuver;
  final String distanceLabel;

  @override
  Widget build(BuildContext context) {
    // Dorado Nikara, igual que el resto del chrome de navegación en vivo
    // (badge de ETA, "Iniciar viaje"), no el verde oscuro de business-detail.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary500,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapCardShadow,
            offset: Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surface100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _maneuverIcon(maneuver),
              size: 22,
              color: AppColors.settingsTextDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (distanceLabel.isNotEmpty)
                  Text(
                    distanceLabel,
                    style: AppTextStyles.mapRowCaption.copyWith(
                      color: AppColors.settingsTextDark,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  instruction,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.settingsTextDark,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedometerBadge extends StatelessWidget {
  const _SpeedometerBadge({required this.speedKmh});

  final double speedKmh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface100,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.mapControlBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapControlShadowStrong,
            offset: Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            speedKmh.round().toString(),
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.settingsTextDark,
              fontSize: 18,
              height: 1,
            ),
          ),
          Text(
            'km/h',
            style: AppTextStyles.mapRowCaption.copyWith(fontSize: 8),
          ),
        ],
      ),
    );
  }
}

/// Estado 19c — único chrome mientras se sigue una ruta: card flotante con
/// ETA, distancia y las dos acciones del viaje. El bottom nav queda oculto
/// debajo (ver [MapFocusController.navigationActive]).
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
  final String etaLabel;
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
                      // Alerta suave, no un bloque rojo sólido: fondo coral
                      // pálido con el tinte destructivo canónico del texto/ícono.
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

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({
    required this.isLoading,
    required this.onPressed,
    this.icon = Icons.my_location,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  /// `my_location` en exploración/preview; en navegación en vivo se pasa
  /// una mira, así el mismo chrome sirve para ambos casos.
  final IconData icon;

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
            : Icon(icon, size: 19, color: AppColors.settingsTextDark),
      ),
    );
  }
}

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

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({
    required this.controller,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
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

/// Botón cuadrado junto a la búsqueda; al tocarlo resetea el filtro de
/// categoría a "Todos".
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

/// Handle de arrastre sobre [child] para el sheet de detalle de pin (ver
/// [MapScreen._showBusinessSheet]) — evita un [DraggableScrollableSheet]
/// completo para contenido que no hace scroll.
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

/// Card compartida por el carrusel persistente (Pantalla 2a) y el sheet de
/// detalle de pin ([MapScreen._showBusinessSheet]), para que un negocio se
/// vea igual sin importar cómo se seleccionó. Sin precio ni botón de
/// reserva, por diseño de Pantalla 2b.
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

  /// Distancia en línea recta (Haversine) desde la última posición
  /// conocida, o `null` si no hay — en ese caso solo se muestra la ciudad.
  final double? distanceKm;

  final VoidCallback onNavigate;
  final VoidCallback onViewProfile;

  /// Layout completo (Estado 19b, con borde dorado) vs. compacto (Estado
  /// 19a) — el carrusel solo expande la card seleccionada. Siempre `true`
  /// en el sheet de detalle de pin.
  final bool expanded;

  /// Alterna la selección (expande/colapsa). Null en el sheet de detalle,
  /// que no tiene un estado compacto al cual volver.
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
    // Aún no existe columna `is_eco` — el opt-in real del dueño (Sello ECO,
    // Pantalla 4c) tiene prioridad; category/activities es solo fallback
    // para negocios guardados antes de ese campo.
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
                // Padding derecho reserva espacio para el círculo de
                // favorito flotante en la esquina superior — el layout
                // compacto no tiene ese toggle.
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
                // El layout compacto muestra a lo sumo un badge (ECO
                // primero) en un slot de altura fija (vacío si no aplica
                // ninguno) — dejar esta línea opcional antes causaba
                // overflow/desalineación entre cards con y sin badge.
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
        // Borde de 2px siempre presente para que compacto/expandido solo
        // cambie el color, nunca el tamaño exterior de la card.
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

/// Misma integración de [FavoritesService]/[GuestGuard] que los botones de
/// favorito de Home, para que un negocio marcado desde el mapa se refleje
/// al instante en el resto de la app.
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
