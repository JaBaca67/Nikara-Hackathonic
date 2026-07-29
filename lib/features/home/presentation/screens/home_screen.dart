import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Home / "Inicio" screen (Figma node 124:37 for the general structure —
/// header, hero banner, category rows). Everything below the header is
/// 100% dynamic, sourced from [BusinessStorageService]: a hero carousel of
/// the most recently registered businesses, then one horizontally
/// scrolling row per category that actually has at least one business.
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

  Timer? _photoTimer;
  int _heroIndex = 0;
  int _heroPhotoIndex = 0;

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
  }

  @override
  void dispose() {
    _photoTimer?.cancel();
    _heroPageController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinesses() async {
    final businesses = await _businessStorageService.getBusinesses();
    if (!mounted) return;
    setState(() {
      _businesses = businesses;
      _heroIndex = 0;
      _heroPhotoIndex = 0;
    });
    _restartPhotoTimer();
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

  Map<String, List<BusinessModel>> _groupByCategory(
    List<BusinessModel> businesses,
  ) {
    final grouped = <String, List<BusinessModel>>{};
    for (final business in businesses) {
      grouped.putIfAbsent(business.category, () => []).add(business);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final businesses = _businesses;

    return Scaffold(
      backgroundColor: AppColors.surface100,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const SearchHeaderWidget(notificationCount: 3),
            const SizedBox(height: 16),
            Expanded(
              child: businesses == null
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
    final categories = _groupByCategory(businesses);
    final heroIndex = heroBusinesses.isEmpty
        ? 0
        : _heroIndex.clamp(0, heroBusinesses.length - 1);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heroBusinesses.isNotEmpty)
            _HeroCarousel(
              controller: _heroPageController,
              businesses: heroBusinesses,
              activeIndex: heroIndex,
              photoIndex: _heroPhotoIndex,
              onPageChanged: _onHeroPageChanged,
              onSelectPhoto: _selectHeroPhoto,
              onTapDetail: _openBusinessDetail,
            ),
          for (final category in categories.keys)
            _CategorySection(
              title: category,
              businesses: categories[category]!,
              onTap: _openBusinessDetail,
            ),
        ],
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

  static const _height = 310.0;

  final PageController controller;
  final List<BusinessModel> businesses;
  final int activeIndex;
  final int photoIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSelectPhoto;
  final ValueChanged<BusinessModel> onTapDetail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
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
        ),
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
          // Dark gradient confined to roughly the bottom 140px of the card,
          // so the text/thumbnails overlay stays legible.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 1 - (140 / _HeroCarousel._height), 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.tagGold600,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                business.category,
                style: AppTextStyles.tagPill.copyWith(
                  fontSize: 11,
                  color: AppColors.neutral1100,
                ),
              ),
            ),
          ),
          if (isEco)
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
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
                      size: 10,
                      color: AppColors.surface100,
                    ),
                    const SizedBox(width: 4),
                    Text('ECO', style: AppTextStyles.tagPill),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(business.name, style: AppTextStyles.heroTitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 12,
                            color: AppColors.surface100,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              business.locationText,
                              style: AppTextStyles.heroLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (business.allowsReservations)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            business.formattedPrice,
                            style: AppTextStyles.heroPrice,
                          ),
                          Text('/p', style: AppTextStyles.heroLocation),
                        ],
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
                          height: 40,
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
                                  width: 40,
                                  height: 40,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white
                                          : Colors.transparent,
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
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Ver detalle →',
                          style: AppTextStyles.ctaPill,
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

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.businesses,
    required this.onTap,
  });

  final String title;
  final List<BusinessModel> businesses;
  final ValueChanged<BusinessModel> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: AppTextStyles.sectionTitle),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 191,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const ClampingScrollPhysics(),
              itemCount: businesses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final business = businesses[index];
                return _CompactBusinessCard(
                  business: business,
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

class _CompactBusinessCard extends StatelessWidget {
  const _CompactBusinessCard({required this.business, required this.onTap});

  final BusinessModel business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const width = 168.0;
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;

    return Semantics(
      button: true,
      label: '${business.name}, ${business.locationText}',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24FDBE02),
                  offset: Offset(0, 4),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: LocalImage(
                      path: imagePath,
                      fallbackIcon: Icons.storefront_outlined,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: AppTextStyles.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 10,
                            color: AppColors.neutral700,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              business.locationText,
                              style: AppTextStyles.cardLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (business.allowsReservations)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              business.formattedPrice,
                              style: AppTextStyles.cardPrice,
                            ),
                            Text('/p', style: AppTextStyles.cardPriceSuffix),
                          ],
                        )
                      else
                        Text(
                          '★ ${business.averageRating.toStringAsFixed(1)}',
                          style: AppTextStyles.cardPriceSuffix,
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
              'Aún no hay negocios registrados en Nikara',
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
