import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/business/presentation/widgets/social_contact_row.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/features/routes/presentation/widgets/add_to_route_bottom_sheet.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/detail_sections.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Detail screen for a [BusinessModel] — cover + floating quick-info card +
/// segmented tabs, all in one continuous scroll (no fixed sheet), per
/// Claude Design's turn 3 ("Perfil del negocio / lugar — unificación
/// prototipo + Figma"), Pantalla 3a ("pestaña Información, scroll
/// completo"). No price, no reservation CTA anywhere on this screen — the
/// same discovery-first pivot already applied to the Map redesign.
class BusinessDetailScreen extends StatefulWidget {
  const BusinessDetailScreen({super.key, required this.business});

  final BusinessModel business;

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  static const _coverHeight = 296.0;

  final _favoritesService = FavoritesService();
  final _authService = AuthService();
  final _extrasService = LocalProfileExtrasService();
  final _businessStorageService = BusinessStorageService();

  int _tab = 0;
  bool _isFavorite = false;
  UserModel? _currentProfile;
  String? _currentAvatarPath;
  Position? _userPosition;

  /// Starts as [widget.business] but gets a new `reviews` list appended
  /// in-place after a successful submission, so the rating/opinions/photos
  /// on this screen update immediately without popping and re-pushing.
  late BusinessModel _businessState = widget.business;

  BusinessModel get _business => _businessState;

  /// Real straight-line distance from the device's last known position —
  /// `null` (shown as "—") when location isn't available, never a
  /// fabricated number.
  double? get _distanceKm => LocationService.distanceKm(
    _userPosition,
    _business.latitude,
    _business.longitude,
  );

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
    _loadCurrentUser();
    _loadUserPosition();
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

  /// Best-effort, silent on failure — same shared cache as MapScreen via
  /// [LocationService], so whichever screen asks first is the only one
  /// that prompts for permission.
  Future<void> _loadUserPosition() async {
    final position = await LocationService().getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() => _userPosition = position);
  }

  void _openOwnerProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  Future<void> _toggleFavorite() async {
    if (!await GuestGuard.allow(context, GuestFeature.favoritos)) return;
    if (!mounted) return;
    final nowFavorite = await _favoritesService.toggleFavorite(_business.id);
    if (!mounted) return;
    setState(() => _isFavorite = nowFavorite);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Próximamente')));
  }

  /// "Agregar a ruta" — suma este negocio como parada de un itinerario ya
  /// existente (o de uno nuevo) vía [AddToRouteBottomSheet].
  Future<void> _addToRoute() async {
    await AddToRouteBottomSheet.showForBusiness(context, _business);
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
        : 'Viajero Níkara';

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

  /// Sends the user to Níkara's own map, focused on this business (pin
  /// selected + its carousel card centered), instead of handing off to the
  /// external Google Maps app: the in-app map now draws a real route and
  /// tracks the trip itself (MapScreen's "Cómo llegar" / Estado 19c), so
  /// leaving the app here would drop the user out of that flow.
  ///
  /// [MapFocusController] carries the business (id, name, lat/lng) and
  /// switches to the Mapa tab; popping back to `MainLayout` is what makes
  /// that tab visible from this pushed screen.
  void _openDirections() {
    final lat = _business.latitude;
    final lng = _business.longitude;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este negocio todavía no tiene ubicación en el mapa.'),
        ),
      );
      return;
    }
    MapFocusController().focusOnBusiness(
      MapFocusRequest(
        businessId: _business.id,
        name: _business.name,
        latitude: lat,
        longitude: lng,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailCoverImage(
              photos: _business.localImagePaths,
              height: _coverHeight,
              onBack: () => Navigator.of(context).maybePop(),
              caption: _CoverCaption(business: _business),
              actions: [
                DetailCoverIconButton(
                  icon: Icons.add_road_rounded,
                  onTap: _addToRoute,
                ),
                const SizedBox(width: 8),
                DetailCoverIconButton(
                  icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                  onTap: _toggleFavorite,
                ),
                const SizedBox(width: 8),
                DetailCoverIconButton(
                  icon: Icons.ios_share,
                  onTap: _showComingSoon,
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _QuickInfoCard(
                  business: _business,
                  distanceKm: _distanceKm,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DetailSegmentedTabs(
                    labels: const ['Información', 'Reseñas & Fotos'],
                    selected: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _tab == 0
                        ? _InformationTab(
                            business: _business,
                            currentProfile: _currentProfile,
                            currentAvatarPath: _currentAvatarPath,
                            onOwnerTap: _openOwnerProfile,
                            onDirections: _openDirections,
                            onReport: _showComingSoon,
                          )
                        : _ReviewsTab(
                            business: _business,
                            onWriteReview: _openWriteReview,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ContactBar(
        business: _business,
        onDirections: _openDirections,
      ),
    );
  }
}

/// Bloque inferior de la portada — pill de categoría, rating y nombre del
/// negocio sobre el degradado, con las medidas de Pantalla 3a. El resto de
/// la portada (PageView de fotos, scrims, botones, contador "1 / N") vive
/// en [DetailCoverImage].
class _CoverCaption extends StatelessWidget {
  const _CoverCaption({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DetailCoverTagPill(label: business.category),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              business.reviews.isEmpty
                  ? Icons.star_border_rounded
                  : Icons.star_rounded,
              size: 15,
              color: AppColors.tagGold600,
            ),
            const SizedBox(width: 4),
            Text(
              business.averageRating.toStringAsFixed(1),
              style: AppTextStyles.detailRatingValue.copyWith(
                color: AppColors.surface100,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${business.reviews.length} reseñas)',
              style: AppTextStyles.detailRatingCount.copyWith(
                color: AppColors.surface100.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          business.name,
          style: AppTextStyles.detailTitle.copyWith(
            color: AppColors.surface100,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Tarjeta flotante de datos rápidos del negocio — Ubicación / Distancia /
/// Hoy sobre el layout compartido [DetailQuickInfoCard]. Vive aquí y no en
/// el widget compartido porque el valor de "Hoy" sale del horario libre del
/// negocio, no de un campo estructurado.
class _QuickInfoCard extends StatelessWidget {
  const _QuickInfoCard({required this.business, required this.distanceKm});

  final BusinessModel business;
  final double? distanceKm;

  /// El horario libre que escribió el negocio, solo su primera línea —
  /// nunca un "Abierto"/"Cerrado" inventado que ningún dato estructurado
  /// respalda.
  String get _todayValue {
    final schedules = business.schedules.trim();
    if (schedules.isEmpty) return 'No especificado';
    final firstLine = schedules.split('\n').first.trim();
    return firstLine.isEmpty ? 'No especificado' : firstLine;
  }

  @override
  Widget build(BuildContext context) {
    final km = distanceKm;
    return DetailQuickInfoCard(
      items: [
        DetailQuickInfoItem(
          label: 'Ubicación',
          value: business.city.isEmpty ? 'No especificado' : business.city,
        ),
        DetailQuickInfoItem(
          label: 'Distancia',
          value: km == null ? '—' : '${km.toStringAsFixed(0)} km',
        ),
        DetailQuickInfoItem(
          label: 'Hoy',
          value: _todayValue,
          valueColor: business.schedules.trim().isEmpty
              ? AppColors.settingsTextMuted
              : AppColors.accent300,
        ),
      ],
    );
  }
}

/// "Información" tab body — Descripción, Actividades, Servicios del lugar,
/// Anfitrión, Horarios, Contacto y redes, Cómo llegar and a report link,
/// in that order — the exact section list and sequence from Pantalla 3a.
/// Stateful only to hold the "ver todas las actividades" expand toggle.
class _InformationTab extends StatefulWidget {
  const _InformationTab({
    required this.business,
    required this.currentProfile,
    required this.currentAvatarPath,
    required this.onOwnerTap,
    required this.onDirections,
    required this.onReport,
  });

  final BusinessModel business;
  final UserModel? currentProfile;
  final String? currentAvatarPath;
  final VoidCallback onOwnerTap;
  final VoidCallback onDirections;
  final VoidCallback onReport;

  @override
  State<_InformationTab> createState() => _InformationTabState();
}

class _InformationTabState extends State<_InformationTab> {
  bool _showAllActivities = false;

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final contacts = <SocialContact>[
      if (business.contactPhone.isNotEmpty)
        SocialContact.whatsapp(
          business.contactPhone,
          message:
              'Hola, vi su negocio en Níkara y me gustaría más información '
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

    final sections = <Widget>[
      _DescriptionSection(business: business),
      if (business.activities.isNotEmpty)
        _ActivitiesSection(
          activities: business.activities,
          ecoSeal: business.ecoSealRequested,
          expanded: _showAllActivities,
          onToggle: () =>
              setState(() => _showAllActivities = !_showAllActivities),
        ),
      if (business.amenities.isNotEmpty)
        _ServicesSection(amenities: business.amenities),
      _HostSection(
        business: business,
        currentProfile: widget.currentProfile,
        currentAvatarPath: widget.currentAvatarPath,
        onTap: widget.onOwnerTap,
      ),
      _ScheduleSection(business: business),
      if (contacts.isNotEmpty) _ContactSection(contacts: contacts),
      _DirectionsSection(business: business, onTap: widget.onDirections),
      _ReportLinkSection(onTap: widget.onReport),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          sections[i],
          if (i != sections.length - 1) const SizedBox(height: 22),
        ],
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
        Text(
          business.description.isEmpty
              ? 'Este anfitrión aún no agregó una descripción.'
              : business.description,
          style: AppTextStyles.detailDescriptionText,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showFullDescription(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mostrar más', style: AppTextStyles.detailInlineLink),
              const Icon(
                Icons.expand_more,
                size: 15,
                color: AppColors.accent300,
              ),
            ],
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
                      color: AppColors.settingsTextDark,
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
          style: AppTextStyles.detailActivityLabel.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.detailDescriptionText),
      ],
    );
  }
}

/// Actividades — icon rows with an optional "ECO" badge (shown only when
/// the activity's own text literally mentions it, never guessed), showing
/// the first 3 with a "Ver las N actividades" expand link, per Pantalla 3a.
class _ActivitiesSection extends StatelessWidget {
  const _ActivitiesSection({
    required this.activities,
    required this.ecoSeal,
    required this.expanded,
    required this.onToggle,
  });

  final List<String> activities;
  final bool ecoSeal;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visible = expanded ? activities : activities.take(3).toList();
    return DetailSection(
      title: 'Actividades',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final activity in visible) ...[
            _ActivityRow(label: activity, ecoSeal: ecoSeal),
            if (activity != visible.last) const SizedBox(height: 8),
          ],
          if (activities.length > 3) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onToggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expanded
                        ? 'Ver menos'
                        : 'Ver las ${activities.length} actividades',
                    style: AppTextStyles.detailInlineLink,
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.chevron_right,
                    size: 15,
                    color: AppColors.accent300,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.label, required this.ecoSeal});

  final String label;

  /// The business's own Sello ECO opt-in (Pantalla 4c) — applies to every
  /// activity row, on top of the per-label "eco" text match below.
  final bool ecoSeal;

  bool get _isEco =>
      ecoSeal || activityLabel(label).toLowerCase().contains('eco');

  @override
  Widget build(BuildContext context) {
    final isEco = _isEco;
    return DetailIconRow(
      icon: activityIcon(label),
      label: activityLabel(label),
      iconColor: isEco ? AppColors.accent300 : AppColors.settingsTextMuted,
      iconBackground: isEco
          ? AppColors.detailActivityIconBg
          : AppColors.settingsBackground,
      trailing: isEco
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.detailActivityIconBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('ECO', style: AppTextStyles.detailEcoBadge),
            )
          : null,
    );
  }
}

/// Servicios del lugar — a [Wrap] of hairline-bordered pills, one per
/// amenity, per Pantalla 3a.
class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.amenities});

  final List<String> amenities;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Servicios del lugar',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final amenity in amenities)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface100,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.mapControlBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    amenityIcon(amenity),
                    size: 15,
                    color: AppColors.settingsTextMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      amenity,
                      style: AppTextStyles.detailServicePill,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

/// Horarios — the business's own free-text hours in a single bordered
/// card. Pantalla 3a shows a 3-row structured weekly table, but the data
/// model only has one free-text [BusinessModel.schedules] field — this
/// shows that real value rather than fabricating per-day hours.
class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Horarios',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.mapControlBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 18,
              color: AppColors.settingsTextMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                business.schedules.trim().isEmpty
                    ? 'Horario no especificado'
                    : business.schedules,
                style: AppTextStyles.detailScheduleLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.contacts});

  final List<SocialContact> contacts;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Contacto y redes',
      child: SocialHub(contacts: contacts),
    );
  }
}

/// Anfitrión — [BusinessModel.ownerId] is the account that created the
/// listing. This app is device-local/single-account (no backend session
/// sharing), so the only case where that id resolves to a REAL, richer
/// profile (real photo, real name, a tappable link) is when it matches the
/// device's own signed-in session. Every other business falls back to the
/// wizard's free-text [BusinessModel.hostName] with an initials avatar.
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
    return DetailSection(
      title: 'Anfitrión',
      child: _HostRow(
        hostName: business.hostName,
        linkedName: isLinked ? currentProfile!.fullName : null,
        linkedAvatarPath: isLinked ? currentAvatarPath : null,
        hasWhatsapp: business.contactPhone.isNotEmpty,
        onTap: isLinked ? onTap : null,
      ),
    );
  }
}

/// Compact host card — 48px avatar, name + "VERIFICADO" badge on one row,
/// a single caption line, per Pantalla 3a's proportions. No invented
/// "Anfitrión desde 2023 · N lugares" stat — the app has no per-owner
/// join-date or listing-count data wired into this screen.
class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.hostName,
    required this.linkedName,
    required this.linkedAvatarPath,
    required this.hasWhatsapp,
    required this.onTap,
  });

  final String hostName;
  final String? linkedName;
  final String? linkedAvatarPath;
  final bool hasWhatsapp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final linkedName = this.linkedName;
    final displayName = linkedName != null && linkedName.trim().isNotEmpty
        ? linkedName
        : (hostName.isEmpty ? 'Anfitrión Níkara' : hostName);
    final avatarPath = linkedAvatarPath;
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();

    return DetailProfileCard(
      avatar: avatarPath != null && avatarPath.isNotEmpty
          ? LocalImage(path: avatarPath)
          : Container(
              color: AppColors.accent300,
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTextStyles.h6.copyWith(color: AppColors.surface100),
              ),
            ),
      name: displayName,
      verified: true,
      caption: hasWhatsapp || onTap != null
          ? (onTap != null
                ? 'Toca para ver el perfil'
                : 'Disponible por WhatsApp')
          : null,
      captionColor: onTap != null ? AppColors.accent300 : null,
      onTap: onTap,
    );
  }
}

/// Cómo llegar — la tarjeta compartida [DetailMapCard] (ilustración
/// decorativa de mini-mapa, no un mapa real) con la dirección exacta del
/// negocio y la pastilla "Abrir mapa" que salta al mapa de Níkara.
class _DirectionsSection extends StatelessWidget {
  const _DirectionsSection({required this.business, required this.onTap});

  final BusinessModel business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Cómo llegar',
      child: DetailMapCard(
        address: business.locationText.isEmpty
            ? 'Dirección no especificada'
            : business.locationText,
        caption: 'Se abrirá en el mapa de Níkara',
        onTap: onTap,
      ),
    );
  }
}

class _ReportLinkSection extends StatelessWidget {
  const _ReportLinkSection({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          'Reportar información incorrecta',
          style: AppTextStyles.profileCaption10.copyWith(
            fontSize: 10.5,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
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
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Text(
                  business.averageRating.toStringAsFixed(1),
                  style: AppTextStyles.ratingBig,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (_) => const Icon(
                      Icons.star,
                      size: 10,
                      color: AppColors.primary500,
                    ),
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
          child: Text(
            '$star',
            style: AppTextStyles.reviewMeta.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
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
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.cardShadow,
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
                  style: AppTextStyles.reviewAuthor.copyWith(
                    color: Colors.white,
                  ),
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

/// Fixed bottom bar — exactly two actions, per Pantalla 3a: a compact
/// "Cómo llegar" pill and a full-width gold "Escribir por WhatsApp" CTA.
/// No price, no "Reservar ahora" — the app's reservation flow was removed
/// entirely (Aug 2026); WhatsApp/directions are this bottom bar's only
/// actions until a map-based routes/booking system replaces it.
class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.business, required this.onDirections});

  final BusinessModel business;
  final VoidCallback onDirections;

  void _contact(BuildContext context) {
    launchWhatsApp(
      context,
      business.contactPhone,
      message:
          'Hola, vi su negocio en Níkara y me gustaría más información '
          'sobre ${business.name}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailBottomBar(
      child: Row(
        children: [
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: business.latitude == null ? null : onDirections,
              icon: const Icon(Icons.directions_outlined, size: 18),
              label: const Text('Cómo llegar'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.settingsBackground,
                foregroundColor: AppColors.settingsTextDark,
                side: const BorderSide(color: AppColors.mapControlBorder),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: AppTextStyles.detailBottomBarSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: business.contactPhone.isEmpty
                  ? FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('Sin WhatsApp'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.segmentedTrackBg,
                        foregroundColor: AppColors.settingsTextMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.detailPrimaryButtonGlow,
                            offset: Offset(0, 4),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: () => _contact(context),
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text(
                          'Escribir por WhatsApp',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          foregroundColor: AppColors.settingsTextDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: AppTextStyles.detailBottomBarPrimary,
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
      fillColor: AppColors.surface100,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.neutral600.withValues(alpha: 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.neutral600.withValues(alpha: 0.35),
        ),
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
                      color: AppColors.settingsTextDark,
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
              style: AppTextStyles.detailActivityLabel.copyWith(
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
                    Text(
                      'Adjuntar fotos o videos',
                      style: AppTextStyles.subtitle2,
                    ),
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
