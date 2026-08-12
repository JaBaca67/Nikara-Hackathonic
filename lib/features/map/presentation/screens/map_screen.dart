import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Fallback map center when geolocation isn't available (permission denied,
/// location services off, or any lookup failure) — Managua, Nicaragua's
/// capital — the same fallback used by the "Registra tu negocio" wizard's
/// map picker.
const LatLng _kDefaultMapCenter = LatLng(12.1363, -86.2513);

/// Keeps the camera from zooming/panning out into empty, tile-less ocean —
/// a generous box around Nicaragua and its Central American neighbors.
final LatLngBounds _kMapBounds = LatLngBounds(
  const LatLng(7.0, -92.0),
  const LatLng(18.5, -77.0),
);

const String _kAllCategories = 'Todos';

/// Mapa de exploración principal — real, live map (flutter_map + CartoDB
/// Voyager tiles) showing only real businesses persisted in Supabase's
/// `businesses` table, no mock destinations. Visual chrome (floating
/// search bar, category chips, active/inactive pins, no-price preview
/// card) ports the Claude Design project "Rediseño de Níkara Home y Mapa",
/// Pantalla 2b — exact colors, radii and shadows, not the older Figma pass.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final _businessStorageService = BusinessStorageService();
  final _mapController = MapController();
  late final AnimationController _cameraAnimController;

  LatLng _animFrom = _kDefaultMapCenter;
  LatLng _animTo = _kDefaultMapCenter;
  double _animFromZoom = 13;
  double _animToZoom = 13;

  final _searchController = TextEditingController();

  bool _locatingUser = false;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = _kAllCategories;
  String? _loadError;
  String? _selectedBusinessId;
  Position? _userPosition;
  List<BusinessModel> _businesses = const [];

  @override
  void initState() {
    super.initState();
    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_onCameraTick);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _locateUser();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _cameraAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Real categories, not mocked — distinct values pulled straight from the
  /// businesses actually loaded from Supabase.
  List<String> get _availableCategories {
    final categories = _businesses.map((b) => b.category).toSet().toList()
      ..sort();
    return [_kAllCategories, ...categories];
  }

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

  void _onCameraTick() {
    final t = Curves.easeInOutCubic.transform(_cameraAnimController.value);
    final lat =
        _animFrom.latitude + (_animTo.latitude - _animFrom.latitude) * t;
    final lng =
        _animFrom.longitude + (_animTo.longitude - _animFrom.longitude) * t;
    final zoom = _animFromZoom + (_animToZoom - _animFromZoom) * t;
    _mapController.move(LatLng(lat, lng), zoom);
  }

  /// Smoothly flies the camera to [target] — used when the user taps a pin,
  /// so the map glides there instead of snapping.
  void _animateCameraTo(LatLng target, {double zoom = 16}) {
    final camera = _mapController.camera;
    _animFrom = camera.center;
    _animFromZoom = camera.zoom;
    _animTo = target;
    _animToZoom = zoom;
    _cameraAnimController
      ..reset()
      ..forward();
  }

  /// Best-effort: centers the map on the device's current position and
  /// records it for the "a X km" distance shown in [_BusinessPreviewSheet].
  /// Any failure along the way (location services off, permission denied,
  /// timeout) is swallowed silently — the map just stays on the Managua
  /// fallback, exactly like the business registration wizard's map picker.
  /// Goes through [LocationService] so Home and Map share one cached
  /// position instead of each prompting for permission separately.
  Future<void> _locateUser({bool animate = false}) async {
    setState(() => _locatingUser = true);
    try {
      final position = await LocationService().getCurrentPosition(
        forceRefresh: animate,
      );
      if (!mounted || position == null) return;
      setState(() => _userPosition = position);
      final here = LatLng(position.latitude, position.longitude);
      try {
        if (animate) {
          _animateCameraTo(here, zoom: 14);
        } else {
          _mapController.move(here, 14);
        }
      } catch (_) {
        // The map may not have attached yet if this resolves unusually
        // fast — harmless, it just stays on the default center.
      }
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final businesses = await _businessStorageService.getBusinesses();
      if (!mounted) return;
      setState(() {
        // A business without coordinates can't be pinned — defensive only,
        // since `businesses.location` is a NOT NULL column.
        _businesses = businesses
            .where((b) => b.latitude != null && b.longitude != null)
            .toList(growable: false);
        _isLoading = false;
      });
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  void _onBusinessTap(BusinessModel business) {
    _animateCameraTo(LatLng(business.latitude!, business.longitude!));
    setState(() => _selectedBusinessId = business.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BusinessPreviewSheet(
        business: business,
        distanceKm: LocationService.distanceKm(
          _userPosition,
          business.latitude,
          business.longitude,
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedBusinessId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBusinesses;
    final categories = _availableCategories;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Edge-to-edge real map: fills the entire screen, including
          // behind the status bar. Only the floating UI below respects
          // SafeArea, per Pantalla 2b's "map first" layout.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _kDefaultMapCenter,
              initialZoom: 13,
              // Hard zoom limits + a bounds constraint are what actually
              // fix the "Unsupported operation: Infinity or NaN toInt"
              // crash: without them, pinch-zooming out (or a fling past
              // the edge) can drive the camera's zoom to a value tile
              // math can't convert to a valid tile index.
              minZoom: 6,
              maxZoom: 18,
              cameraConstraint: CameraConstraint.contain(bounds: _kMapBounds),
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.flingAnimation,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.nikara_app',
                retinaMode: RetinaMode.isHighDensity(context),
                minZoom: 6,
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  for (final business in filtered)
                    Marker(
                      point: LatLng(business.latitude!, business.longitude!),
                      width: 34,
                      height: 34,
                      child: _BusinessMarkerPin(
                        selected: business.id == _selectedBusinessId,
                        onTap: () => _onBusinessTap(business),
                      ),
                    ),
                ],
              ),
            ],
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
                onRetry: _loadBusinesses,
              ),
            ),
          // Floating chrome — search bar, filter button, category chips —
          // each with its own hairline border/shadow directly over the
          // map, per Pantalla 2b (no enclosing glass panel).
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
                        child: _MapSearchBar(controller: _searchController),
                      ),
                      const SizedBox(width: 10),
                      _MapFilterButton(
                        onTap: () =>
                            setState(() => _selectedCategory = _kAllCategories),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return _CategoryChip(
                          label: category,
                          selected: _selectedCategory == category,
                          onTap: () =>
                              setState(() => _selectedCategory = category),
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
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _RecenterButton(
                  isLoading: _locatingUser,
                  onPressed: () => _locateUser(animate: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A real Material pin (never an emoji): a Material icon in a rounded
/// badge with a soft shadow for depth — matches Pantalla 2b's two pin
/// states exactly: gold ([AppColors.primary500]) with a thick white ring
/// while [selected] (the pin whose preview sheet is currently open), cream
/// with a thin [AppColors.profileDivider] ring otherwise — sits directly
/// on top of the [Marker]'s geographic point.
class _BusinessMarkerPin extends StatelessWidget {
  const _BusinessMarkerPin({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.surface100,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.surface100 : AppColors.profileDivider,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.mapPinShadowActive
                  : AppColors.mapPinShadowInactive,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.storefront,
          size: 16,
          color: selected
              ? AppColors.settingsTextDark
              : AppColors.settingsTextMuted,
        ),
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

/// Floating search field — white surface, hairline border, soft ink
/// shadow, per Pantalla 2b (no thick outline, no glass-blur panel).
class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({required this.controller});

  final TextEditingController controller;

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
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
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
          style: AppTextStyles.mapRowTitle.copyWith(
            color: selected
                ? AppColors.settingsTextDark
                : AppColors.settingsTextMuted,
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

/// Bottom sheet preview shown when a pin is tapped — photo, name, category
/// tags, real GPS distance and exactly two actions ("Cómo llegar" /
/// "Ver perfil"), per Pantalla 2b: no price, no reservation button.
class _BusinessPreviewSheet extends StatelessWidget {
  const _BusinessPreviewSheet({required this.business, this.distanceKm});

  final BusinessModel business;

  /// Straight-line (Haversine) distance from the device's last known
  /// position, or `null` when it isn't available — in which case only the
  /// city shows.
  final double? distanceKm;

  Future<void> _openDirections(BuildContext context) async {
    final lat = business.latitude;
    final lng = business.longitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa de rutas')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
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

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.mapCardShadow,
            offset: Offset(0, 8),
            blurRadius: 26,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral600.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: LocalImage(
                        path: imagePath,
                        fallbackIcon: Icons.storefront_outlined,
                        fallbackIconSize: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                business.name,
                                style: AppTextStyles.sectionTitle.copyWith(
                                  color: AppColors.settingsTextDark,
                                  fontSize: 18,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _FavoriteToggle(businessId: business.id),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me,
                              size: 13,
                              color: AppColors.settingsTextMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                locationLabel,
                                style: AppTextStyles.settingsSubtitle.copyWith(
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _openDirections(context),
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Cómo llegar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.profileDivider,
                          foregroundColor: AppColors.settingsTextDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: AppTextStyles.mapRowTitle.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  BusinessDetailScreen(business: business),
                            ),
                          );
                        },
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: const Text('Ver perfil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: AppColors.settingsTextDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: AppTextStyles.mapRowTitle.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

/// Heart toggle on the preview sheet's header row — same
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
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(left: 8),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.profileDivider,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: isFavorite
                  ? AppColors.favoriteActive
                  : AppColors.settingsTextMuted,
            ),
          ),
        );
      },
    );
  }
}
