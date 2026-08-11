import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
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

/// Mapa de exploración principal (Figma node 167:1849): a real, live map
/// (flutter_map + CartoDB Voyager tiles) showing only real businesses
/// persisted in Supabase's `businesses` table — no mock destinations, no
/// fictional pin layout.
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
  bool _showFilters = false;
  String _searchQuery = '';
  String _selectedCategory = _kAllCategories;
  String? _loadError;
  List<BusinessModel> _businesses = const [];

  @override
  void initState() {
    super.initState();
    _cameraAnimController =
        AnimationController(
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
    return _businesses.where((b) {
      final matchesCategory =
          _selectedCategory == _kAllCategories ||
          b.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          b.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList(growable: false);
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

  /// Best-effort: centers the map on the device's current position. Any
  /// failure along the way (location services off, permission denied,
  /// timeout) is swallowed silently — the map just stays on the Managua
  /// fallback, exactly like the business registration wizard's map picker.
  Future<void> _locateUser({bool animate = false}) async {
    setState(() => _locatingUser = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
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
    } catch (_) {
      // See doc comment above.
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BusinessPreviewSheet(business: business),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBusinesses;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Edge-to-edge real map: fills the entire screen, including
          // behind the status bar. Only the floating UI below respects
          // SafeArea, per a Waze/Uber-style "map first" layout.
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
                      width: 42,
                      height: 42,
                      child: _BusinessMarkerPin(
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
                  child: CircularProgressIndicator(
                    color: AppColors.primary500,
                  ),
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
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MapFrostedHeader(
                  title: 'Mapa de Nicaragua',
                  subtitle: filtered.isEmpty
                      ? 'Explora negocios reales registrados en Níkara'
                      : 'Toca un pin para explorar '
                            '${filtered.length} '
                            '${filtered.length == 1 ? 'negocio' : 'negocios'}',
                  searchController: _searchController,
                  showFilters: _showFilters,
                  onToggleFilters: () =>
                      setState(() => _showFilters = !_showFilters),
                  categories: _availableCategories,
                  selectedCategory: _selectedCategory,
                  onSelectCategory: (category) =>
                      setState(() => _selectedCategory = category),
                ),
                if (!_isLoading &&
                    _loadError == null &&
                    _businesses.isNotEmpty &&
                    filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _EmptyBusinessesBanner(
                      message: 'Ningún negocio coincide con tu búsqueda.',
                    ),
                  )
                else if (!_isLoading && _loadError == null && _businesses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _EmptyBusinessesBanner(),
                  ),
              ],
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
/// gold badge with a soft shadow for depth — sits directly on top of the
/// [Marker]'s geographic point.
class _BusinessMarkerPin extends StatelessWidget {
  const _BusinessMarkerPin({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary500,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface100, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.storefront,
          size: 20,
          color: AppColors.textInk,
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface100,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
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
                  size: 20,
                  color: AppColors.primary700,
                ),
        ),
      ),
    );
  }
}

/// Floating, safe-area-aware header: title/subtitle, the search bar, and an
/// optional row of real category chips — a frosted-glass panel (per the
/// Figma reference's search bar chrome) that sits directly on top of the
/// edge-to-edge map instead of a solid background column.
class _MapFrostedHeader extends StatelessWidget {
  const _MapFrostedHeader({
    required this.title,
    required this.subtitle,
    required this.searchController,
    required this.showFilters,
    required this.onToggleFilters,
    required this.categories,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final String title;
  final String subtitle;
  final TextEditingController searchController;
  final bool showFilters;
  final VoidCallback onToggleFilters;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: BoxDecoration(
            color: AppColors.surface100.withValues(alpha: 0.82),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                offset: Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headerTitleMd),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.sectionSubLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _MapSearchBar(
                controller: searchController,
                onFilterTap: onToggleFilters,
                filtersActive: showFilters,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: showFilters
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in categories)
                              ChoiceChip(
                                label: Text(category),
                                selected: selectedCategory == category,
                                onSelected: (_) => onSelectCategory(category),
                                selectedColor: AppColors.tagGold600,
                                backgroundColor: AppColors.surface100,
                                labelStyle: AppTextStyles.link.copyWith(
                                  color: selectedCategory == category
                                      ? AppColors.neutral1100
                                      : AppColors.neutral700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: BorderSide(
                                    color: selectedCategory == category
                                        ? AppColors.tagGold600
                                        : AppColors.surface200,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({
    required this.controller,
    required this.onFilterTap,
    required this.filtersActive,
  });

  final TextEditingController controller;
  final VoidCallback onFilterTap;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.neutral1100, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF808080)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.neutral1100,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar negocio...',
                hintStyle: AppTextStyles.caption.copyWith(
                  color: const Color(0xFF808080),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filtersActive
                    ? AppColors.primary700
                    : AppColors.tagGold600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune, size: 16, color: AppColors.neutral1100),
            ),
          ),
        ],
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
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
            color: AppColors.neutral500,
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

/// Bottom sheet preview shown when a pin is tapped — mirrors
/// BusinessDetailScreen's warm gold/white palette (see its Quick Info card:
/// white surface, soft shadow, gold accents) at a compact, glanceable size.
class _BusinessPreviewSheet extends StatelessWidget {
  const _BusinessPreviewSheet({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.profileHeaderGoldPale.withValues(alpha: 0.45),
            AppColors.surface100,
          ],
          stops: const [0, 0.4],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                      width: 76,
                      height: 76,
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
                        Text(
                          business.name,
                          style: AppTextStyles.sectionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 13,
                              color: AppColors.neutral500,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                business.city,
                                style: AppTextStyles.listCardCaption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tagGold600,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              business.category,
                              style: AppTextStyles.tagPill,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (business.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  business.description,
                  style: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.neutral700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary500, AppColors.primary700],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Ver perfil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: AppColors.textInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: AppTextStyles.buttonLarge,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
