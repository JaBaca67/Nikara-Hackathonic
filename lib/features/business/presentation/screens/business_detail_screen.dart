import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/business/presentation/widgets/social_contact_row.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Airbnb-style detail screen for a [BusinessModel] (Figma nodes 284:2256
/// "Informacion lugar" and 233:437 "Reseñas Lugar"). The cover + floating
/// info card + segmented tabs are a plain [Stack] rather than a
/// [SliverAppBar] — simpler to reason about and consistent with how every
/// other screen in this app is built.
class BusinessDetailScreen extends StatefulWidget {
  const BusinessDetailScreen({super.key, required this.business});

  final BusinessModel business;

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  static const _coverHeight = 320.0;

  final _favoritesService = FavoritesService();
  final _authService = AuthService();
  final _extrasService = LocalProfileExtrasService();
  final _businessStorageService = BusinessStorageService();

  int _tab = 0;
  bool _isFavorite = false;
  UserModel? _currentProfile;
  String? _currentAvatarPath;

  /// Starts as [widget.business] but gets a new `reviews` list appended
  /// in-place after a successful submission, so the rating/opinions/photos
  /// on this screen update immediately without popping and re-pushing.
  late BusinessModel _businessState = widget.business;

  BusinessModel get _business => _businessState;

  /// Simulated distance — there's no real geolocation wired up, so this is
  /// a stable, per-business pseudo-random figure (never a literal constant,
  /// never re-randomized on rebuild).
  int get _simulatedDistanceKm => 5 + (_business.id.hashCode.abs() % 40);

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
    _loadCurrentUser();
  }

  Future<void> _loadFavoriteState() async {
    final isFavorite = await _favoritesService.isFavorite(_business.id);
    if (!mounted) return;
    setState(() => _isFavorite = isFavorite);
  }

  Future<void> _loadCurrentUser() async {
    final profile = await _authService.getCurrentProfile();
    final avatarPath = await _extrasService.getAvatarPath();
    if (!mounted) return;
    setState(() {
      _currentProfile = profile;
      _currentAvatarPath = avatarPath;
    });
  }

  void _openOwnerProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  Future<void> _toggleFavorite() async {
    final nowFavorite = await _favoritesService.toggleFavorite(_business.id);
    if (!mounted) return;
    setState(() => _isFavorite = nowFavorite);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Próximamente')));
  }

  Future<void> _openWriteReview() async {
    final draft = await showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _WriteReviewSheet(),
    );
    if (draft == null || !mounted) return;

    final profile = _currentProfile ?? await _authService.getCurrentProfile();
    final authorName = profile != null && profile.fullName.trim().isNotEmpty
        ? profile.fullName
        : 'Viajero Nikara';

    final review = ReviewModel(
      id: const Uuid().v4(),
      authorName: authorName,
      authorId: _authService.currentAuthUser?.id ?? '',
      rating: draft.rating,
      comment: draft.comment,
      date: DateTime.now(),
      mediaPaths: draft.mediaPaths,
    );

    await _businessStorageService.addReview(_business, review);
    if (!mounted) return;
    setState(() {
      _businessState = _businessState.copyWith(
        reviews: [..._businessState.reviews, review],
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Gracias por tu reseña! +20 puntos')),
    );
  }

  void _openLocationOnMap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abriendo el mapa de Nikara...')),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface100,
      // Stack sizes itself to its non-positioned children (just the cover)
      // under the loose constraints Scaffold hands its body, which left the
      // sheet below squeezed into a sliver and the rest of the screen blank.
      // SizedBox.expand forces the Stack to the full body size so the
      // Positioned.fill sheet gets its real height.
      body: SizedBox.expand(
        child: Stack(
          children: [
            _CoverImage(
              business: _business,
              height: _coverHeight,
              isFavorite: _isFavorite,
              onBack: () => Navigator.of(context).maybePop(),
              onShare: _showComingSoon,
              onToggleFavorite: _toggleFavorite,
            ),
            Positioned.fill(
              top: _coverHeight - 28,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface100,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QuickInfoCard(
                        business: _business,
                        distanceKm: _simulatedDistanceKm,
                        onLocationTap: _openLocationOnMap,
                      ),
                      const SizedBox(height: 16),
                      _SegmentedTabs(
                        tab: _tab,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                      const Divider(
                        height: 32,
                        thickness: 1,
                        color: Color(0xFFEEEEEE),
                      ),
                      if (_tab == 0)
                        _InformationTab(
                          business: _business,
                          onLocationTap: _openLocationOnMap,
                          currentProfile: _currentProfile,
                          currentAvatarPath: _currentAvatarPath,
                          onOwnerTap: _openOwnerProfile,
                        )
                      else
                        _ReviewsTab(
                          business: _business,
                          onWriteReview: _openWriteReview,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ContactBar(business: _business),
    );
  }
}

/// Cover: swipeable [PageView] over every photo the business has (falls
/// back to a single placeholder frame when there are none), with a
/// "1/N" counter badge and the usual back/favorite/share overlay.
class _CoverImage extends StatefulWidget {
  const _CoverImage({
    required this.business,
    required this.height,
    required this.isFavorite,
    required this.onBack,
    required this.onShare,
    required this.onToggleFavorite,
  });

  final BusinessModel business;
  final double height;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onToggleFavorite;

  @override
  State<_CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<_CoverImage> {
  final _pageController = PageController();
  int _photoIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final photos = business.localImagePaths;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photos.isEmpty
              ? const LocalImage(
                  path: null,
                  fallbackIcon: Icons.image_outlined,
                  fallbackIconSize: 48,
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: photos.length,
                  onPageChanged: (index) =>
                      setState(() => _photoIndex = index),
                  itemBuilder: (context, index) => LocalImage(
                    path: photos[index],
                    fallbackIcon: Icons.image_outlined,
                    fallbackIconSize: 48,
                  ),
                ),
          // A decorated Container hit-tests as opaque across its whole
          // rectangle (even the visually-transparent parts of the
          // gradient), so left bare this silently ate every drag before it
          // ever reached the PageView underneath. IgnorePointer makes it
          // purely decorative again.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xB31A1510), Color(0x001A1510)],
                  stops: [0.0, 0.55],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CoverIconButton(
                        icon: Icons.arrow_back,
                        onTap: widget.onBack,
                      ),
                      Row(
                        children: [
                          _CoverIconButton(
                            icon: widget.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            onTap: widget.onToggleFavorite,
                          ),
                          const SizedBox(width: 8),
                          _CoverIconButton(
                            icon: Icons.ios_share,
                            onTap: widget.onShare,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Purely informational — must never intercept the drag
                  // that swipes the PageView underneath.
                  IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            business.category,
                            style: AppTextStyles.detailTagPill.copyWith(
                              color: AppColors.textInk,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              business.reviews.isEmpty
                                  ? Icons.star_border_rounded
                                  : Icons.star_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              business.averageRating.toStringAsFixed(1),
                              style: AppTextStyles.detailRatingValue.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${business.reviews.length} reseñas)',
                              style: AppTextStyles.detailRatingCount.copyWith(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          business.name,
                          style: AppTextStyles.detailTitle.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Generous bottom margin so the title never sits under the
                  // sliding white sheet, regardless of how long the name is.
                  const SizedBox(height: 44),
                ],
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              right: 16,
              bottom: 40,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_photoIndex + 1}/${photos.length}',
                    style: AppTextStyles.detailRatingValue.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverIconButton extends StatelessWidget {
  const _CoverIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _QuickInfoCard extends StatelessWidget {
  const _QuickInfoCard({
    required this.business,
    required this.distanceKm,
    required this.onLocationTap,
  });

  final BusinessModel business;
  final int distanceKm;
  final VoidCallback onLocationTap;

  static Widget get _quickInfoDivider => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppColors.primary500.withValues(alpha: 0.3),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickInfoItem(
              icon: Icons.location_on_outlined,
              label: 'Ubicación',
              value: business.city,
              onTap: onLocationTap,
            ),
          ),
          _quickInfoDivider,
          Expanded(
            child: _QuickInfoItem(
              icon: Icons.near_me_outlined,
              label: 'Distancia',
              value: '$distanceKm km',
            ),
          ),
          if (business.allowsReservations) ...[
            _quickInfoDivider,
            Expanded(
              child: _QuickInfoItem(
                icon: null,
                label: 'Precio',
                value: business.formattedPrice,
                valueColor: AppColors.ecoForest,
                valueSuffix: '/p',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickInfoItem extends StatelessWidget {
  const _QuickInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueSuffix,
    this.onTap,
  });

  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? valueSuffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.quickInfoLabel,
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Without a Flexible here, this Text lays out at its natural
            // (unbounded) width — a long value has nowhere to shrink and
            // the Row overflows horizontally instead of eliding.
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.quickInfoValue.copyWith(
                  color: valueColor ?? AppColors.textInk,
                ),
              ),
            ),
            if (valueSuffix != null)
              Text(
                valueSuffix!,
                style: AppTextStyles.legend.copyWith(
                  color: AppColors.neutral600,
                ),
              ),
          ],
        ),
      ],
    );

    final result = icon == null
        ? content
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 15, color: AppColors.primary500),
              ),
              const SizedBox(width: 8),
              Flexible(child: content),
            ],
          );

    if (onTap == null) return result;
    return GestureDetector(onTap: onTap, child: result);
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.tab, required this.onChanged});

  final int tab;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentedTrackBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Información',
              selected: tab == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Reseñas & Fotos',
              selected: tab == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x4DFDBE02),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.segmentedTabLabel.copyWith(
            color: selected ? AppColors.textInk : AppColors.neutral600,
          ),
        ),
      ),
    );
  }
}

class _InformationTab extends StatelessWidget {
  const _InformationTab({
    required this.business,
    required this.onLocationTap,
    required this.currentProfile,
    required this.currentAvatarPath,
    required this.onOwnerTap,
  });

  final BusinessModel business;
  final VoidCallback onLocationTap;
  final UserModel? currentProfile;
  final String? currentAvatarPath;
  final VoidCallback onOwnerTap;

  static const _sectionDivider = Divider(
    height: 40,
    thickness: 1,
    color: Color(0xFFEEEEEE),
  );

  @override
  Widget build(BuildContext context) {
    // Order matches the Figma spec: Comodidades, Descripción, módulo
    // dinámico por categoría, Mapa de ubicación — everything else the
    // wizard also collects (Actividades, Anfitrión, Horarios y contacto)
    // follows after, since removing that real data isn't part of this fix.
    final sections = <Widget>[
      if (business.amenities.isNotEmpty)
        _ChipSection(
          title: 'Comodidades',
          background: AppColors.warmChipBackground,
          border: AppColors.warmChipBorder,
          tint: AppColors.chipContentDark,
          labels: business.amenities,
          iconOf: amenityIcon,
        ),
      _DescriptionSection(business: business),
      if (business.activities.isNotEmpty)
        _DynamicCategorySection(business: business),
      _LocationSection(business: business, onLocationTap: onLocationTap),
      if (business.activities.isNotEmpty)
        _ChipSection(
          title: 'Actividades',
          background: AppColors.warmChipBackgroundAlt,
          border: AppColors.warmChipBorder,
          tint: AppColors.chipContentDark,
          labels: business.activities,
          iconOf: activityIcon,
        ),
      _HostSection(
        business: business,
        currentProfile: currentProfile,
        currentAvatarPath: currentAvatarPath,
        onTap: onOwnerTap,
      ),
      _SchedulesAndSocialSection(business: business),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          sections[i],
          if (i != sections.length - 1) _sectionDivider,
        ],
      ],
    );
  }
}

/// Picks the right prompt for `_buildDynamicCategorySection` per the
/// business's category. The app models category as a free-text String
/// (set by the wizard's fixed chip list, reused for Home's grouping and
/// Map's filters) rather than an enum, so this matches on keywords instead
/// of a `BusinessCategory` type.
String _categoryPromptFor(String category) {
  final key = category.toLowerCase();
  if (key.contains('hospedaje')) return '¿Dónde vas a descansar?';
  if (key.contains('restaurante') || key.contains('gastro')) {
    return '¿Qué vas a degustar?';
  }
  if (key.contains('aventura') || key.contains('tour') || key.contains('cultura')) {
    return '¿Qué vas a vivir?';
  }
  return '¿Qué vas a explorar?'; // Eco Turismo, Transporte, Otro, etc.
}

/// Category-aware highlight carousel — reuses [BusinessModel.activities] as
/// the backing list (the model has no per-category data like rooms/dishes/
/// stops yet) and cycles through the business's own photos, only changing
/// the section title based on category.
class _DynamicCategorySection extends StatelessWidget {
  const _DynamicCategorySection({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final items = business.activities;
    if (items.isEmpty) return const SizedBox.shrink();
    final photos = business.localImagePaths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _categoryPromptFor(business.category),
          style: AppTextStyles.detailSectionTitle,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final imagePath = photos.isEmpty
                  ? null
                  : photos[index % photos.length];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LocalImage(
                        path: imagePath,
                        fallbackIcon: Icons.photo_outlined,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.4, 1.0],
                            colors: [Colors.transparent, Color(0xCC1A1510)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          items[index],
                          style: AppTextStyles.detailRowText.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A section title followed by a [Wrap] of warm, bordered chips — used for
/// both Comodidades and Actividades, each with its own vector icon per
/// item via [iconOf] (no emojis — see [amenityIcon]/[activityIcon]).
class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.background,
    required this.border,
    required this.tint,
    required this.labels,
    required this.iconOf,
  });

  final String title;
  final Color background;
  final Color border;
  final Color tint;
  final List<String> labels;
  final IconData Function(String label) iconOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.detailSectionTitle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in labels)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconOf(label), size: 14, color: tint),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AppTextStyles.detailRowText.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.business});

  final BusinessModel business;

  void _showFullDescription(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _FullDescriptionSheet(business: business),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Descripción', style: AppTextStyles.detailSectionTitle),
        const SizedBox(height: 8),
        Text(
          business.description.isEmpty
              ? 'Este anfitrión aún no agregó una descripción.'
              : business.description,
          style: AppTextStyles.bodyText2.copyWith(color: AppColors.neutral800),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showFullDescription(context),
          child: Text(
            'Mostrar más',
            style: AppTextStyles.detailRowText.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.accent300,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Mostrar más" sheet — the full write-up behind the truncated description:
/// El Espacio (reuses [BusinessModel.description]), Acceso de los
/// visitantes and Otros aspectos a destacar (both dedicated fields, empty
/// for now since the wizard doesn't collect them yet).
class _FullDescriptionSheet extends StatelessWidget {
  const _FullDescriptionSheet({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Acerca de este lugar',
                  style: AppTextStyles.detailSectionTitle,
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.segmentedTrackBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.neutral900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _subsection(
                      'El Espacio',
                      business.description.isEmpty
                          ? 'Este anfitrión aún no agregó una descripción.'
                          : business.description,
                    ),
                    const SizedBox(height: 20),
                    _subsection(
                      'Acceso de los visitantes',
                      business.accessDetails.isEmpty
                          ? 'No especificado.'
                          : business.accessDetails,
                    ),
                    const SizedBox(height: 20),
                    _subsection(
                      'Otros aspectos a destacar',
                      business.otherNotes.isEmpty
                          ? 'No especificado.'
                          : business.otherNotes,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subsection(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.detailRowText.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.bodyText2.copyWith(color: AppColors.neutral800),
        ),
      ],
    );
  }
}

/// "Mapa de ubicación exacta e indicaciones" — the exact address
/// ([BusinessModel.locationText], never the short [BusinessModel.city]
/// shown on cards) plus a tap target that opens the map, matching
/// [onLocationTap] used by the quick-info card above.
class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.business, required this.onLocationTap});

  final BusinessModel business;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación exacta', style: AppTextStyles.detailSectionTitle),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onLocationTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ecoForest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.ecoForest.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ecoForest.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: AppColors.ecoForest,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.locationText.isEmpty
                            ? 'Dirección no especificada'
                            : business.locationText,
                        style: AppTextStyles.detailRowText.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ver indicaciones en el mapa',
                        style: AppTextStyles.reviewMeta.copyWith(
                          color: AppColors.ecoForest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.ecoForest),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Anfitrión section — [BusinessModel.ownerId] is the account email that
/// created the listing. This app is device-local/single-account (no
/// backend), so the only case where that id can resolve to a REAL, richer
/// profile (real photo, real name, a tappable link) is when it matches the
/// device's own signed-in session. Every other business (created before
/// [BusinessModel.ownerId] existed, or in a future multi-account world,
/// owned by someone else) falls back to the wizard's free-text
/// [BusinessModel.hostName] with an initials avatar, same as before.
class _HostSection extends StatelessWidget {
  const _HostSection({
    required this.business,
    required this.currentProfile,
    required this.currentAvatarPath,
    required this.onTap,
  });

  final BusinessModel business;
  final UserModel? currentProfile;
  final String? currentAvatarPath;
  final VoidCallback onTap;

  bool get _isLinkedToCurrentUser =>
      business.ownerId.isNotEmpty &&
      currentProfile != null &&
      business.ownerId == currentProfile!.id;

  @override
  Widget build(BuildContext context) {
    final isLinked = _isLinkedToCurrentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anfitrión', style: AppTextStyles.detailSectionTitle),
        const SizedBox(height: 12),
        _HostRow(
          hostName: business.hostName,
          linkedName: isLinked ? currentProfile!.fullName : null,
          linkedAvatarPath: isLinked ? currentAvatarPath : null,
          hasWhatsapp: business.contactPhone.isNotEmpty,
          onTap: isLinked ? onTap : null,
        ),
      ],
    );
  }
}

/// Horarios (icon + bold title + value, always shown) followed by a
/// [SocialHub] of whichever contact channels this business actually has
/// data for.
class _SchedulesAndSocialSection extends StatelessWidget {
  const _SchedulesAndSocialSection({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final contacts = <SocialContact>[
      if (business.contactPhone.isNotEmpty)
        SocialContact.whatsapp(
          business.contactPhone,
          message:
              'Hola, vi su negocio en Nikara y me gustaría más información '
              'sobre ${business.name}.',
        ),
      if (business.contactPhone.isNotEmpty)
        SocialContact.phone(business.contactPhone),
      if (business.instagramLink.isNotEmpty)
        SocialContact.instagram(business.instagramLink),
      if (business.facebookLink.isNotEmpty)
        SocialContact.facebook(business.facebookLink),
      if (business.tiktokLink.isNotEmpty)
        SocialContact.tiktok(business.tiktokLink),
      if (business.socialMediaLink.isNotEmpty)
        SocialContact.link(business.socialMediaLink),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconValueRow(
          icon: Icons.access_time_rounded,
          title: 'Horarios',
          value: business.schedules.isEmpty
              ? 'Horario no especificado'
              : business.schedules,
        ),
        if (contacts.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Contacto y redes', style: AppTextStyles.detailSectionTitle),
          const SizedBox(height: 10),
          SocialHub(contacts: contacts),
        ],
      ],
    );
  }
}

class _IconValueRow extends StatelessWidget {
  const _IconValueRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.neutral600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.detailRowText.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.neutral600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Premium host card — big avatar, name + "Anfitrión Verificado" badge (a
/// fair claim: every host here went through Nikara's own registration
/// wizard, unlike a fabricated trust score), and a real capability line
/// instead of a made-up "responds in ~1 hour" metric this app has no data
/// to back — there's no messaging system to time a response against.
class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.hostName,
    required this.linkedName,
    required this.linkedAvatarPath,
    required this.hasWhatsapp,
    required this.onTap,
  });

  final String hostName;

  /// Non-null only when this business's [BusinessModel.ownerId] matches
  /// the device's signed-in account — the one case with a real photo/name
  /// to show instead of the wizard's free-text [hostName].
  final String? linkedName;
  final String? linkedAvatarPath;
  final bool hasWhatsapp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final linkedName = this.linkedName;
    final displayName = linkedName != null && linkedName.trim().isNotEmpty
        ? linkedName
        : (hostName.isEmpty ? 'Anfitrión Nikara' : hostName);
    final avatarPath = linkedAvatarPath;
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: avatarPath != null && avatarPath.isNotEmpty
                  ? LocalImage(path: avatarPath)
                  : Container(
                      color: AppColors.ecoForest,
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: AppTextStyles.h5.copyWith(color: Colors.white),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.detailRowText.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ecoForest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: AppColors.ecoForest,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Anfitrión Verificado',
                        style: AppTextStyles.reviewMeta.copyWith(
                          color: AppColors.ecoForest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasWhatsapp || onTap != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    onTap != null
                        ? 'Toca para ver el perfil'
                        : 'Disponible por WhatsApp',
                    style: AppTextStyles.reviewMeta.copyWith(
                      color: onTap != null
                          ? AppColors.accent300
                          : AppColors.neutral600,
                      fontWeight: onTap != null ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.neutral500),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.business, required this.onWriteReview});

  final BusinessModel business;
  final VoidCallback onWriteReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onWriteReview,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Escribir una reseña'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary500,
              side: const BorderSide(color: AppColors.primary500),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (business.reviews.isEmpty)
          const _ReviewsEmptyState()
        else ...[
          _RatingSummaryCard(business: business),
          if (business.localImagePaths.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Fotos del lugar', style: AppTextStyles.detailSectionTitle),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: business.localImagePaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = business.localImagePaths[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 90,
                      height: 72,
                      child: LocalImage(path: path),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Opiniones', style: AppTextStyles.detailSectionTitle),
          const SizedBox(height: 10),
          for (final review in business.reviews) ...[
            _ReviewCard(review: review),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _ReviewsEmptyState extends StatelessWidget {
  const _ReviewsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 40,
            color: AppColors.neutral500,
          ),
          const SizedBox(height: 12),
          Text('Aún no hay reseñas', style: AppTextStyles.detailSectionTitle),
          const SizedBox(height: 4),
          Text(
            'Sé la primera persona en compartir tu experiencia.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final total = business.reviews.length;
    final counts = List<int>.filled(6, 0);
    for (final review in business.reviews) {
      final rounded = review.rating.round().clamp(1, 5);
      counts[rounded]++;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Text(business.averageRating.toStringAsFixed(1), style: AppTextStyles.ratingBig),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (_) => const Icon(Icons.star, size: 10, color: AppColors.primary500),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total reseñas',
                  style: AppTextStyles.reviewMeta,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _RatingBarRow(
                      star: star,
                      fraction: total == 0 ? 0 : counts[star] / total,
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

class _RatingBarRow extends StatelessWidget {
  const _RatingBarRow({required this.star, required this.fraction});

  final int star;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 8,
          child: Text('$star', style: AppTextStyles.reviewMeta.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.segmentedTrackBg,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '${(fraction * 100).round()}%',
            style: AppTextStyles.reviewMeta,
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ReviewModel review;

  String get _relativeDate {
    final days = DateTime.now().difference(review.date).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'hace 1 día';
    if (days < 7) return 'hace $days días';
    if (days < 30) return 'hace ${(days / 7).floor()} semana(s)';
    return 'hace ${(days / 30).floor()} mes(es)';
  }

  @override
  Widget build(BuildContext context) {
    final initial = review.authorName.trim().isEmpty
        ? '?'
        : review.authorName.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.ecoForest,
                child: Text(
                  initial,
                  style: AppTextStyles.reviewAuthor.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName, style: AppTextStyles.reviewAuthor),
                    Text(_relativeDate, style: AppTextStyles.reviewMeta),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating.round() ? Icons.star : Icons.star_border,
                    size: 9,
                    color: AppColors.primary500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(review.comment, style: AppTextStyles.reviewComment),
          if (review.mediaPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.mediaPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final path = review.mediaPaths[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: isVideoPath(path)
                          ? Container(
                              color: AppColors.neutral800,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 20,
                              ),
                            )
                          : LocalImage(path: path),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fixed bottom bar — WhatsApp is the one and only call to action, worded
/// and priced differently depending on whether the business has a set
/// price (reservable) or is free/consult-to-book.
class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.business});

  final BusinessModel business;

  bool get _hasPrice => business.allowsReservations && business.price != null;

  void _contact(BuildContext context) {
    launchWhatsApp(
      context,
      business.contactPhone,
      message:
          'Hola, vi su negocio en Nikara y me gustaría más información '
          'sobre ${business.name}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface100,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _hasPrice
                        ? '${business.formattedPrice} / persona'
                        : 'Consultar disponibilidad',
                    style: AppTextStyles.detailRowText.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _hasPrice ? 'Reserva por WhatsApp' : 'e información',
                    style: AppTextStyles.reviewMeta,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _contact(context),
                icon: const Icon(Icons.chat, size: 20),
                label: Text(
                  _hasPrice ? 'Chatear por WhatsApp' : 'Contactar por WhatsApp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: AppTextStyles.buttonMd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What [_WriteReviewSheet] hands back — the raw star/comment/media input.
/// [BusinessDetailScreen] is the one that stamps author identity, an id and
/// a timestamp onto it to build the real [ReviewModel], since that's real
/// business logic the sheet itself shouldn't need to know about.
class _ReviewDraft {
  const _ReviewDraft({
    required this.rating,
    required this.comment,
    required this.mediaPaths,
  });

  final double rating;
  final String comment;
  final List<String> mediaPaths;
}

/// "Escribir una reseña" bottom sheet — 1-5 star selector, a free-text
/// comment, and a photo/video picker via `image_picker`'s
/// `pickMultipleMedia` (a single control for both media types, since
/// there's no separate video picker in this project).
class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet();

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  int _rating = 5;
  final _commentController = TextEditingController();
  final List<XFile> _media = [];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picked = await ImagePicker().pickMultipleMedia();
    if (picked.isEmpty || !mounted) return;
    setState(() => _media.addAll(picked));
  }

  void _removeMedia(int index) => setState(() => _media.removeAt(index));

  void _submit() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un comentario antes de enviar')),
      );
      return;
    }
    Navigator.of(context).pop(
      _ReviewDraft(
        rating: _rating.toDouble(),
        comment: comment,
        mediaPaths: _media.map((x) => x.path).toList(),
      ),
    );
  }

  InputDecoration _commentDecoration() {
    return InputDecoration(
      hintText: 'Cuéntanos cómo fue tu experiencia...',
      hintStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.neutral600),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.neutral600.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.neutral600.withValues(alpha: 0.35)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.wizardFocus, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Escribir una reseña',
                  style: AppTextStyles.detailSectionTitle,
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.segmentedTrackBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.neutral900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    GestureDetector(
                      onTap: () => setState(() => _rating = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i <= _rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 40,
                          color: AppColors.primary500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tu comentario',
              style: AppTextStyles.detailRowText.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: _commentDecoration(),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface200.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary500.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.primary500,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text('Adjuntar fotos o videos', style: AppTextStyles.subtitle2),
                  ],
                ),
              ),
            ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _media.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = _media[index].path;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: isVideoPath(path)
                                ? Container(
                                    color: AppColors.neutral800,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.videocam,
                                      color: Colors.white,
                                    ),
                                  )
                                : LocalImage(path: path),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeMedia(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Enviar reseña',
                  style: AppTextStyles.buttonLg.copyWith(
                    color: AppColors.textInk,
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
