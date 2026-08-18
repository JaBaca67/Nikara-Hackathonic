import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

const String _kAllCategories = 'Todos';

enum _SortMode { recientes, cercanos }

/// "a N km" desde [from] al negocio, o `null` si no hay posición disponible (sin permiso, GPS apagado, o [from] aún no resolvió).
String? _distanceLabel(Position? from, BusinessModel business) {
  final km = LocationService.distanceKm(
    from,
    business.latitude,
    business.longitude,
  );
  return km == null ? null : 'a ${km.toStringAsFixed(0)} km';
}

/// "{ciudad} · a N km", o solo "{ciudad}" si no hay distancia disponible.
String _cityWithDistance(Position? from, BusinessModel business) {
  final distance = _distanceLabel(from, business);
  return distance == null ? business.city : '${business.city} · $distance';
}

/// Pantalla "Inicio" (Figma nodo 124:37). Todo debajo del header es 100% dinámico desde [BusinessStorageService] — sin nombres, precios ni distancias mock.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _photoRotationInterval = Duration(seconds: 5);

  final _businessStorageService = BusinessStorageService();
  final _heroPageController = PageController();
  List<BusinessModel>? _businesses;
  String? _loadError;
  String? _userName;
  Position? _userPosition;

  Timer? _photoTimer;
  int _heroIndex = 0;
  int _heroPhotoIndex = 0;
  String _selectedCategory = _kAllCategories;
  _SortMode _sortMode = _SortMode.recientes;

  /// Hasta 5 negocios, los más recientes primero.
  List<BusinessModel> get _heroBusinesses {
    final businesses = _businesses;
    if (businesses == null || businesses.isEmpty) return const [];
    return businesses.reversed.take(5).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    // Home queda vivo pero fuera de pantalla en el IndexedStack de
    // MainLayout, así que sin este listener un negocio editado no se
    // refleja aquí hasta reiniciar la app.
    BusinessStorageService.revision.addListener(_onBusinessesChanged);
    _loadBusinesses();
    _loadUserName();
    _loadPosition();
  }

  @override
  void dispose() {
    BusinessStorageService.revision.removeListener(_onBusinessesChanged);
    _photoTimer?.cancel();
    _heroPageController.dispose();
    super.dispose();
  }

  void _onBusinessesChanged() {
    if (!mounted) return;
    _loadBusinesses();
  }

  Future<void> _loadUserName() async {
    if (GuestSessionService().isGuest || !AuthService().isLoggedIn) return;
    final profile = await AuthService().getCurrentProfile();
    if (!mounted || profile == null) return;
    setState(() => _userName = profile.firstName);
  }

  Future<void> _loadPosition() async {
    final position = await LocationService().getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() => _userPosition = position);
  }

  Future<void> _loadBusinesses() async {
    setState(() => _loadError = null);
    try {
      final businesses = await _businessStorageService.getBusinesses();
      if (!mounted) return;
      setState(() {
        _businesses = businesses;
        _heroIndex = 0;
        _heroPhotoIndex = 0;
      });
      _restartPhotoTimer();
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }

  /// Rota solo las fotos del negocio activo; cambiar de negocio es manual (swipe).
  void _restartPhotoTimer() {
    _photoTimer?.cancel();
    final heroBusinesses = _heroBusinesses;
    if (heroBusinesses.isEmpty) return;
    final activeIndex = _heroIndex.clamp(0, heroBusinesses.length - 1);
    final photoCount = heroBusinesses[activeIndex].localImagePaths.length;
    if (photoCount <= 1) return;
    _photoTimer = Timer.periodic(_photoRotationInterval, (_) {
      if (!mounted) return;
      setState(() {
        _heroPhotoIndex = (_heroPhotoIndex + 1) % photoCount;
      });
    });
  }

  void _onHeroPageChanged(int index) {
    setState(() {
      _heroIndex = index;
      _heroPhotoIndex = 0;
    });
    _restartPhotoTimer();
  }

  void _selectHeroPhoto(int index) {
    setState(() => _heroPhotoIndex = index);
    _restartPhotoTimer();
  }

  void _openBusinessDetail(BusinessModel business) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business),
      ),
    );
  }

  void _openWizard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterBusinessWizard()));
  }

  List<String> _availableCategories(List<BusinessModel> businesses) {
    final categories = businesses.map((b) => b.category).toSet().toList()
      ..sort();
    return [_kAllCategories, ...categories];
  }

  List<BusinessModel> _visibleBusinesses(List<BusinessModel> businesses) {
    final filtered = _selectedCategory == _kAllCategories
        ? businesses
        : businesses.where((b) => b.category == _selectedCategory).toList();
    if (_sortMode == _SortMode.recientes) {
      return filtered.reversed.toList(growable: false);
    }
    final withDistance = [...filtered];
    withDistance.sort((a, b) {
      final da = LocationService.distanceKm(
        _userPosition,
        a.latitude,
        a.longitude,
      );
      final db = LocationService.distanceKm(
        _userPosition,
        b.latitude,
        b.longitude,
      );
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return withDistance;
  }

  Future<void> _openFilterSheet() async {
    final mode = await showModalBottomSheet<_SortMode>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SortSheet(current: _sortMode),
    );
    if (mode == null || !mounted) return;
    setState(() => _sortMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final businesses = _businesses;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SearchHeaderWidget(
              userName: _userName,
              isGuest:
                  GuestSessionService().isGuest || !AuthService().isLoggedIn,
              notificationCount: 0,
              onFilterTap: _openFilterSheet,
            ),
            Expanded(
              child: _loadError != null
                  ? _LoadErrorState(
                      message: _loadError!,
                      onRetry: _loadBusinesses,
                    )
                  : businesses == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary500,
                      ),
                    )
                  : businesses.isEmpty
                  ? _EmptyState(onRegister: _openWizard)
                  : _buildFeed(businesses),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(List<BusinessModel> businesses) {
    final heroBusinesses = _heroBusinesses;
    final heroIndex = heroBusinesses.isEmpty
        ? 0
        : _heroIndex.clamp(0, heroBusinesses.length - 1);
    final categories = _availableCategories(businesses);
    final visible = _visibleBusinesses(businesses);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      // Margen extra porque MainLayout usa extendBody: true y la barra de
      // navegación flotante se superpone al final del scroll.
      padding: const EdgeInsets.only(bottom: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heroBusinesses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _HeroCarousel(
                  controller: _heroPageController,
                  businesses: heroBusinesses,
                  activeIndex: heroIndex,
                  photoIndex: _heroPhotoIndex,
                  onPageChanged: _onHeroPageChanged,
                  onSelectPhoto: _selectHeroPhoto,
                  onTapDetail: _openBusinessDetail,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _CategoryChipsRow(
            categories: categories,
            selected: _selectedCategory,
            onSelect: (category) =>
                setState(() => _selectedCategory = category),
          ),
          _DestacadosSection(
            businesses: visible,
            userPosition: _userPosition,
            onTap: _openBusinessDetail,
            onSeeAll: _selectedCategory == _kAllCategories
                ? null
                : () => setState(() => _selectedCategory = _kAllCategories),
          ),
          if (_userPosition case final position?)
            _CercaDeTiSection(
              businesses: businesses,
              userPosition: position,
              onTap: _openBusinessDetail,
            ),
        ],
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final _SortMode current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ordenar por', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            _SortOption(
              label: 'Más recientes',
              selected: current == _SortMode.recientes,
              onTap: () => Navigator.of(context).pop(_SortMode.recientes),
            ),
            _SortOption(
              label: 'Más cercanos',
              selected: current == _SortMode.cercanos,
              onTap: () => Navigator.of(context).pop(_SortMode.cercanos),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(label),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary500 : AppColors.neutral400,
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const ClampingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return GestureDetector(
            onTap: () => onSelect(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary500 : AppColors.surface100,
                borderRadius: BorderRadius.circular(999),
                border: isSelected
                    ? null
                    : Border.all(
                        color: AppColors.settingsTextDark.withValues(
                          alpha: 0.08,
                        ),
                      ),
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: AppColors.detailSegmentGlow,
                          offset: Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                category,
                style: AppTextStyles.homeChipLabel.copyWith(
                  color: isSelected
                      ? AppColors.settingsTextDark
                      : AppColors.settingsTextMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Banner destacado deslizable manualmente sobre los negocios más recientes. El marco [ClipRRect] es estático; solo el [PageView] interior cambia de página, para que un swipe nunca parezca una segunda tarjeta entrando desde el borde.
class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.controller,
    required this.businesses,
    required this.activeIndex,
    required this.photoIndex,
    required this.onPageChanged,
    required this.onSelectPhoto,
    required this.onTapDetail,
  });

  static const _height = 224.0;

  final PageController controller;
  final List<BusinessModel> businesses;
  final int activeIndex;
  final int photoIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSelectPhoto;
  final ValueChanged<BusinessModel> onTapDetail;

  @override
  Widget build(BuildContext context) {
    // El padding/borde redondeado los aplica el padre (_buildFeed); esto solo llena ese marco.
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: PageView.builder(
        controller: controller,
        itemCount: businesses.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final business = businesses[index];
          final isActive = index == activeIndex;
          return _HeroCard(
            business: business,
            photoIndex: isActive ? photoIndex : 0,
            onSelectPhoto: onSelectPhoto,
            onTap: () => onTapDetail(business),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.business,
    required this.photoIndex,
    required this.onSelectPhoto,
    required this.onTap,
  });

  final BusinessModel business;
  final int photoIndex;
  final ValueChanged<int> onSelectPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photos = business.localImagePaths;
    final safeIndex = photos.isEmpty
        ? 0
        : photoIndex.clamp(0, photos.length - 1);
    final imagePath = photos.isEmpty ? null : photos[safeIndex];
    final isEco = business.category.toLowerCase().contains('eco');

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: LocalImage(
              key: ValueKey('${business.id}-$safeIndex'),
              path: imagePath,
              fallbackIcon: Icons.storefront_outlined,
              fallbackIconSize: 40,
            ),
          ),
          // Degradado oscuro solo en la parte inferior para que el texto/thumbnails sean legibles.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 1 - (150 / _HeroCarousel._height), 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.detailCoverScrimBottom,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tagGold600,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                business.category,
                style: AppTextStyles.homeHeroPill.copyWith(
                  color: AppColors.settingsTextDark,
                ),
              ),
            ),
          ),
          if (isEco)
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ecoGreen500,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.eco,
                      size: 12,
                      color: AppColors.surface100,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ECO',
                      style: AppTextStyles.homeHeroPill.copyWith(
                        color: AppColors.surface100,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(business.name, style: AppTextStyles.homeHeroTitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me,
                      size: 13,
                      color: AppColors.surface100,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${business.city} · Nicaragua',
                        style: AppTextStyles.homeHeroLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (photos.length > 1)
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final selected = index == safeIndex;
                              return GestureDetector(
                                onTap: () => onSelectPhoto(index),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.surface100
                                          : AppColors.surface100.withValues(
                                              alpha: 0.35,
                                            ),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LocalImage(
                                      path: photos[index],
                                      fallbackIconSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface100.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.surface100.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                            child: Text(
                              'Ver detalle →',
                              style: AppTextStyles.homeCtaPill,
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
        ],
      ),
    );
  }
}

class _DestacadosSection extends StatelessWidget {
  const _DestacadosSection({
    required this.businesses,
    required this.userPosition,
    required this.onTap,
    required this.onSeeAll,
  });

  final List<BusinessModel> businesses;
  final Position? userPosition;
  final ValueChanged<BusinessModel> onTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Destacados',
                    style: AppTextStyles.homeSectionTitle,
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text('Ver todos', style: AppTextStyles.homeSeeMore),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (businesses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Ningún negocio coincide con esta categoría.',
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.neutral600,
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const ClampingScrollPhysics(),
                itemCount: businesses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  return _DestacadoCard(
                    business: business,
                    locationLabel: _cityWithDistance(userPosition, business),
                    onTap: () => onTap(business),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DestacadoCard extends StatelessWidget {
  const _DestacadoCard({
    required this.business,
    required this.locationLabel,
    required this.onTap,
  });

  final BusinessModel business;
  final String locationLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const width = 196.0;
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;
    final isEco = business.category.toLowerCase().contains('eco');

    return Semantics(
      button: true,
      label: '${business.name}, $locationLabel',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.mapControlBorder),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardGlowSoft,
                  offset: Offset(0, 2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: SizedBox(
                    height: 96,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LocalImage(
                          path: imagePath,
                          fallbackIcon: Icons.storefront_outlined,
                        ),
                        if (isEco)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.ecoGreen500,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'ECO',
                                style: AppTextStyles.homeMiniBadge.copyWith(
                                  color: AppColors.surface100,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: _FavoriteButton(
                            businessId: business.id,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: AppTextStyles.homeCardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locationLabel,
                        style: AppTextStyles.homeCardLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Cerca de ti": lista ordenada por distancia real. Solo se renderiza si hay posición GPS; sin ella no existe la sección en vez de mostrar distancias inventadas.
class _CercaDeTiSection extends StatelessWidget {
  const _CercaDeTiSection({
    required this.businesses,
    required this.userPosition,
    required this.onTap,
  });

  final List<BusinessModel> businesses;
  final Position userPosition;
  final ValueChanged<BusinessModel> onTap;

  List<BusinessModel> get _nearest {
    final withDistance = [...businesses]
      ..removeWhere((b) => b.latitude == null || b.longitude == null)
      ..sort((a, b) {
        final da = LocationService.distanceKm(
          userPosition,
          a.latitude,
          a.longitude,
        )!;
        final db = LocationService.distanceKm(
          userPosition,
          b.latitude,
          b.longitude,
        )!;
        return da.compareTo(db);
      });
    return withDistance.take(5).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final nearest = _nearest;
    if (nearest.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Cerca de ti', style: AppTextStyles.homeSectionTitle),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final business in nearest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NearbyRow(
                      business: business,
                      locationLabel: _cityWithDistance(userPosition, business),
                      onTap: () => onTap(business),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({
    required this.business,
    required this.locationLabel,
    required this.onTap,
  });

  final BusinessModel business;
  final String locationLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;
    final isEco = business.category.toLowerCase().contains('eco');

    return Semantics(
      button: true,
      label: '${business.name}, $locationLabel',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.mapControlBorder),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardGlowSoft,
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 52,
                    height: 46,
                    child: LocalImage(
                      path: imagePath,
                      fallbackIcon: Icons.storefront_outlined,
                      fallbackIconSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        business.name,
                        style: AppTextStyles.homeCardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              locationLabel,
                              style: AppTextStyles.homeCardLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isEco) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.ecoGreen500,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'ECO',
                                style: AppTextStyles.homeMiniBadge.copyWith(
                                  color: AppColors.surface100,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _FavoriteButton(businessId: business.id, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de favorito sobre la foto — protegido por [GuestGuard] y sincronizado vía [FavoritesService.idsNotifier] con otras pantallas.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.businessId, this.size = 30});

  final String businessId;

  /// 30 en la card de Destacados, 32 en la fila Cerca-de-ti (Pantalla 2a).
  final double size;

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
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.profileDivider,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 14,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 44,
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no hay negocios registrados en Níkara',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Sé la primera persona en dar a conocer tu negocio turístico '
              'a toda la comunidad.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRegister,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Registrar mi Negocio'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.textInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: AppTextStyles.buttonLg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Se muestra en vez del feed cuando falla la carga (problema de red/Supabase, no "aún sin negocios" — eso es [_EmptyState]). [message] ya viene traducido al español.
class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.settingsDanger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: AppColors.settingsDanger,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No se pudieron cargar los negocios',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.textInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: AppTextStyles.buttonLg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
