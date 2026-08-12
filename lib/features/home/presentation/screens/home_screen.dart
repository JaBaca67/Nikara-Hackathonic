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

/// "a N km" from [from] to the business, or `null` when no position is
/// available (no permission, location services off, or [from] hasn't
/// resolved yet) — callers fall back to showing just the city in that case.
String? _distanceLabel(Position? from, BusinessModel business) {
  final km = LocationService.distanceKm(
    from,
    business.latitude,
    business.longitude,
  );
  return km == null ? null : 'a ${km.toStringAsFixed(0)} km';
}

/// "{city} · a N km", or just "{city}" when the distance isn't available.
String _cityWithDistance(Position? from, BusinessModel business) {
  final distance = _distanceLabel(from, business);
  return distance == null ? business.city : '${business.city} · $distance';
}

/// Home / "Inicio" screen (Figma node 124:37 for the general structure —
/// header, hero banner, category rows). Everything below the header is
/// 100% dynamic, sourced from [BusinessStorageService]: a hero carousel of
/// the most recently registered businesses, real category filter chips,
/// and a "Destacados" grid — no mock names, prices, or distances.
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

  /// Up to the 5 most recently registered businesses, newest first.
  List<BusinessModel> get _heroBusinesses {
    final businesses = _businesses;
    if (businesses == null || businesses.isEmpty) return const [];
    return businesses.reversed.take(5).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _loadUserName();
    _loadPosition();
  }

  @override
  void dispose() {
    _photoTimer?.cancel();
    _heroPageController.dispose();
    super.dispose();
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

  /// Rotates only the *photos of the currently active business* — moving
  /// between businesses is manual (swipe), never automatic.
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
      // Extra clearance (not just 24) because MainLayout's Scaffold uses
      // extendBody: true so the floating nav bar overlaps the bottom of
      // this scroll view instead of reserving its own space.
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
                          color: Color(0x47F0B500),
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

/// Manually swipeable hero banner over the latest registered businesses.
/// The rounded card frame is a single static [ClipRRect] that never moves —
/// only the [PageView] living *inside* it changes pages, so a swipe never
/// looks like a second card sliding in from the edge. Within whichever
/// business is currently on screen, its own photos rotate automatically
/// (Timer.periodic every 5s, owned by the parent state) and can also be
/// picked directly from the thumbnail row overlaid at the bottom of the
/// card, right next to "Ver detalle →".
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
    // The parent (_buildFeed) wraps this whole carousel in the padded,
    // rounded (20) frame the spec calls for — this card itself just fills
    // that frame edge-to-edge.
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
          // Dark gradient confined to roughly the bottom 150px of the card,
          // so the text/thumbnails overlay stays legible.
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
                    Colors.black.withValues(alpha: 0.78),
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
                    const Icon(Icons.near_me, size: 13, color: Colors.white),
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
                                          ? Colors.white
                                          : Colors.white.withValues(
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
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.42),
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
                  color: Color(0x1AF0B500),
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

/// "Cerca de ti" — a vertical list of businesses actually sorted by real
/// distance from the device. Only rendered when a real GPS position is
/// available: without one there's nothing honest to call "near you" (no
/// fabricated placeholder distances), so the whole section just doesn't
/// exist rather than showing a list that isn't actually distance-sorted.
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
                  color: Color(0x1AF0B500),
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

/// Heart toggle overlaid on a business photo — gated by [GuestGuard] like
/// every other favorites entry point in the app, and listens directly to
/// [FavoritesService.idsNotifier] so it stays in sync if the same business
/// gets favorited/unfavorited from BusinessDetailScreen instead.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.businessId, this.size = 30});

  final String businessId;

  /// 30 on the Destacados card, 32 on the Cerca-de-ti row — the two exact
  /// sizes Pantalla 2a uses for this button in each context.
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

/// Shown instead of the feed when [BusinessStorageService.getBusinesses]
/// fails — a Supabase connection/network problem, not "no businesses yet"
/// (that's [_EmptyState]). [message] is the friendly Spanish text the
/// service already translated the error into.
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
