import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nikara_app/shared/widgets/origin_badge.dart';
import 'package:nikara_app/shared/widgets/user_avatar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/business/data/business_post_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/data/review_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/business_post_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/business/presentation/widgets/social_contact_row.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/business/utils/business_schedule.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/public_user_profile_screen.dart';
import 'package:nikara_app/features/routes/presentation/widgets/add_to_route_bottom_sheet.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/detail_sections.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/face_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/eco_badge.dart';
import 'package:nikara_app/shared/widgets/favorite_toggle.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Pantalla de detalle de [BusinessModel], sin precio ni CTA de reserva — mismo pivote "discovery-first" ya aplicado al rediseño del Mapa.
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
  final _businessStorageService = BusinessStorageService();

  int _tab = 0;
  bool _isFavorite = false;
  UserModel? _currentProfile;

  /// Perfil del dueño real del negocio, sea o no la sesión actual. Antes solo
  /// se resolvía cuando el dueño era el usuario logueado, así que al cambiar
  /// de cuenta el anfitrión aparecía como texto libre y sin perfil que abrir.
  UserModel? _ownerProfile;
  Position? _userPosition;

  /// Se actualiza in-place al enviar una reseña para reflejar el cambio sin salir y reentrar a la pantalla.
  late BusinessModel _businessState = widget.business;

  BusinessModel get _business => _businessState;

  /// `null` (se muestra como "—") si no hay ubicación disponible; nunca un número inventado.
  double? get _distanceKm => LocationService.distanceKm(
    _userPosition,
    _business.latitude,
    _business.longitude,
  );

  @override
  void initState() {
    super.initState();
    // El corazón sigue al servicio y no solo a los toques de esta pantalla:
    // "Deshacer" (del aviso de favorito quitado) cambia el favorito por fuera
    // de aquí y, sin esto, el corazón se quedaba vacío.
    _favoritesService.idsNotifier.addListener(_syncFavorite);
    _loadFavoriteState();
    _loadCurrentUser();
    _loadUserPosition();
  }

  @override
  void dispose() {
    _favoritesService.idsNotifier.removeListener(_syncFavorite);
    super.dispose();
  }

  void _syncFavorite() {
    if (!mounted) return;
    final isFavorite = _favoritesService.idsNotifier.value.contains(
      _business.id,
    );
    if (isFavorite != _isFavorite) setState(() => _isFavorite = isFavorite);
  }

  Future<void> _loadFavoriteState() async {
    final isFavorite = await _favoritesService.isFavorite(_business.id);
    if (!mounted) return;
    setState(() => _isFavorite = isFavorite);
  }

  Future<void> _loadCurrentUser() async {
    UserModel? profile;
    UserModel? owner;
    try {
      profile = await _authService.getCurrentProfile();
      final ownerId = _business.ownerId;
      if (ownerId.isEmpty) {
        owner = null;
      } else if (ownerId == profile?.id) {
        // Mismo perfil: se evita el segundo round-trip.
        owner = profile;
      } else {
        owner = await _authService.getProfileById(ownerId);
      }
    } on AuthServiceException {
      // RLS solo deja leer `profiles` a cuentas autenticadas: en modo
      // invitado el bloque cae al `hostName` de texto libre, como antes.
    }
    if (!mounted) return;
    setState(() {
      _currentProfile = profile;
      _ownerProfile = owner;
    });
  }

  /// Comparte cache con [LocationService] de MapScreen: solo la primera pantalla que pregunta pide permiso.
  Future<void> _loadUserPosition() async {
    final position = await LocationService().getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() => _userPosition = position);
  }

  /// El propio dueño va a su ProfileScreen (editable); cualquier otro
  /// visitante va al perfil público de esa persona. Antes esto abría siempre
  /// ProfileScreen, así que tocar "Anfitrión" en un negocio ajeno te llevaba a
  /// tu propio perfil.
  void _openOwnerProfile() {
    final ownerId = _business.ownerId;
    if (ownerId.isEmpty) return;
    if (ownerId == _currentProfile?.id) {
      pushSharedAxis(context, const ProfileScreen());
      return;
    }
    pushSharedAxis(
      context,
      PublicUserProfileScreen(
        userId: ownerId,
        fallbackName: _business.hostName,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (!await GuestGuard.allow(context, GuestFeature.favoritos)) return;
    if (!mounted) return;
    if (!await FaceGuard.allow(context, FaceLimitedAction.favoritos)) return;
    if (!mounted) return;
    // Desde que los favoritos viven en `user_favorites`, guardar puede fallar
    // por red. El corazón no se mueve si eso pasa (`null`): pintarlo lleno
    // haría creer que el negocio quedó guardado cuando no se escribió ninguna
    // fila. Si quitó el favorito, el helper ofrece "Deshacer"; ese cambio
    // vuelve por `idsNotifier` (ver `_syncFavorite`).
    final nowFavorite = await toggleFavoriteWithFeedback(context, _business.id);
    if (nowFavorite == null || !mounted) return;
    setState(() => _isFavorite = nowFavorite);
  }

  void _showComingSoon() {
    AppSnackbar.showInfo(context, 'Próximamente');
  }

  Future<void> _addToRoute() async {
    await AddToRouteBottomSheet.showForBusiness(context, _business);
  }

  /// Tope para publicar una reseña. Sin red la petición puede quedarse
  /// colgada mucho más que esto, y el botón no debe girar para siempre.
  static const _reviewPublishTimeout = Duration(seconds: 15);

  /// Desde que la persona toca "Enviar" hasta que la fila queda escrita (o
  /// falla): con esto la misma reseña no se publica dos veces.
  bool _isSubmittingReview = false;

  /// Última reseña que no se pudo publicar. Se conserva para no perder lo que
  /// la persona escribió: "Reintentar" la reenvía y "Escribir una reseña" la
  /// vuelve a mostrar prellenada.
  ReviewDraft? _failedReviewDraft;

  /// Con [retry] la hoja se abre con la reseña fallida y la envía sola, para
  /// que el spinner se vea en el botón "Enviar reseña".
  Future<void> _openWriteReview({bool retry = false}) async {
    if (_isSubmittingReview) return;
    if (!await FaceGuard.allow(context, FaceLimitedAction.resena)) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => WriteReviewSheet(
        initialDraft: _failedReviewDraft,
        autoSubmit: retry && _failedReviewDraft != null,
        onSubmit: _submitReview,
      ),
    );
  }

  /// Lo llama la hoja al tocar "Enviar reseña", mientras sigue abierta (así
  /// el spinner y el bloqueo viven en ese botón). Devuelve `true` si se
  /// publicó, `false` si falló (ya avisó con `AppSnackbar`) y `null` si
  /// ignoró la llamada por haber otra en curso.
  Future<bool?> _submitReview(ReviewDraft draft) async {
    if (_isSubmittingReview) return null;
    setState(() => _isSubmittingReview = true);
    try {
      // Desde que las reseñas van a la tabla `reviews`, publicar puede fallar
      // por red. Solo se agrega a la lista en pantalla si la fila se escribió:
      // mostrarla igual haría creer que quedó publicada para todos.
      final review = await _publishReview(draft).timeout(_reviewPublishTimeout);
      if (!mounted) return true;
      setState(() {
        _failedReviewDraft = null;
        _businessState = _businessState.copyWith(
          reviews: [..._businessState.reviews, review],
        );
      });
      AppSnackbar.showSuccess(context, '¡Gracias por tu reseña!');
      return true;
    } on TimeoutException {
      _failReview(
        draft,
        'La publicación tardó demasiado. Verifica tu internet e intenta de '
        'nuevo.',
      );
    } on ReviewServiceException catch (e) {
      _failReview(draft, e.message);
    } on Exception {
      _failReview(
        draft,
        'No se pudo publicar tu reseña. Verifica tu internet e intenta de '
        'nuevo.',
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
    return false;
  }

  Future<ReviewModel> _publishReview(ReviewDraft draft) async {
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
    return review;
  }

  /// Guarda la reseña y avisa con un "Reintentar". La hoja se cierra después
  /// de esto (el aviso quedaría tapado por ella), por eso el texto se guarda
  /// aquí y no en la hoja.
  void _failReview(ReviewDraft draft, String message) {
    if (!mounted) return;
    _failedReviewDraft = draft;
    AppSnackbar.showError(
      context,
      message,
      actionLabel: 'Reintentar',
      onAction: () => unawaited(_openWriteReview(retry: true)),
    );
  }

  /// Enfoca el mapa propio de Níkara (no Google Maps externo) porque el mapa in-app ya traza ruta real y sigue el viaje.
  void _openDirections() {
    final lat = _business.latitude;
    final lng = _business.longitude;
    if (lat == null || lng == null) {
      AppSnackbar.showInfo(
        context,
        'Este negocio todavía no tiene ubicación en el mapa.',
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
                  label: 'Agregar a una ruta',
                ),
                const SizedBox(width: 8),
                DetailCoverIconButton(
                  icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                  onTap: _toggleFavorite,
                  label: _isFavorite
                      ? 'Quitar de favoritos'
                      : 'Agregar a favoritos',
                ),
                const SizedBox(width: 8),
                DetailCoverIconButton(
                  icon: Icons.ios_share,
                  onTap: _showComingSoon,
                  label: 'Compartir negocio',
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -kDetailQuickInfoOverlap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: _tab == 0
                        ? _InformationTab(
                            business: _business,
                            currentProfile: _currentProfile,
                            ownerProfile: _ownerProfile,
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

/// Bloque inferior de la portada (categoría, rating, nombre); el resto de la portada vive en [DetailCoverImage].
class _CoverCaption extends StatelessWidget {
  const _CoverCaption({required this.business});

  final BusinessModel business;

  String get _categoryLabel {
    final category =
        businessCategoryPresetFor(business.category) ?? business.category;
    if (business.subcategory.isEmpty) return category;
    return '${business.subcategory} · $category';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DetailCoverTagPill(
          // Categoría normalizada: cruda, un dato semilla pintaba acá
          // "Finca cafetalera · Agroturismo / Fincas", con la categoría
          // repitiendo lo que la subcategoría ya dice.
          label: _categoryLabel,
        ),
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

/// Vive aquí y no en [DetailQuickInfoCard] porque el valor del horario sale
/// del texto libre del negocio, no de un campo estructurado.
class _QuickInfoCard extends StatelessWidget {
  const _QuickInfoCard({required this.business, required this.distanceKm});

  final BusinessModel business;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final km = distanceKm;
    // La etiqueta la decide el propio horario: "Hoy" solo si se pudo resolver
    // la franja del día, "Horario" si es prosa libre — nunca un
    // "Abierto/Cerrado" inventado.
    final schedule = businessScheduleSummary(business.schedules);
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
          label: schedule.label,
          value: schedule.value,
          valueColor: business.schedules.trim().isEmpty
              ? AppColors.settingsTextMuted
              : AppColors.oliveText,
        ),
      ],
    );
  }
}

/// Stateful solo para guardar el toggle de "ver todas las actividades".
class _InformationTab extends StatefulWidget {
  const _InformationTab({
    required this.business,
    required this.currentProfile,
    required this.ownerProfile,
    required this.onOwnerTap,
    required this.onDirections,
    required this.onReport,
  });

  final BusinessModel business;
  final UserModel? currentProfile;
  final UserModel? ownerProfile;
  final VoidCallback onOwnerTap;
  final VoidCallback onDirections;
  final VoidCallback onReport;

  @override
  State<_InformationTab> createState() => _InformationTabState();
}

class _InformationTabState extends State<_InformationTab> {
  bool _showAllActivities = false;
  List<BusinessPostModel> _posts = const [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void didUpdateWidget(_InformationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.business.id != widget.business.id) _loadPosts();
  }

  /// Anuncios es contenido secundario del detalle: si falla la carga, la
  /// sección simplemente no aparece en vez de tumbar el resto de la
  /// pantalla con un error.
  Future<void> _loadPosts() async {
    // 'draft' = BusinessModel armado por el wizard para "Vista previa", sin
    // fila real en Supabase — no tiene anuncios que cargar.
    if (widget.business.id == 'draft') return;
    try {
      final posts = await BusinessPostService().getPostsForBusiness(
        widget.business.id,
      );
      if (mounted) setState(() => _posts = posts);
    } on BusinessPostServiceException {
      // Se queda en la lista vacía (ver doc de arriba).
    }
  }

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
    ];

    final sections = <Widget>[
      if (_posts.isNotEmpty) _AnnouncementsSection(posts: _posts),
      _DescriptionSection(business: business),
      if (business.dayPassEnabled) _DayPassSection(business: business),
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
      if (business.showHost)
        _HostSection(
          business: business,
          currentProfile: widget.currentProfile,
          ownerProfile: widget.ownerProfile,
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
                color: AppColors.oliveText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Acceso de los visitantes" y "Otros aspectos" están vacíos hoy porque el wizard aún no los recolecta.
class _FullDescriptionSheet extends StatelessWidget {
  const _FullDescriptionSheet({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
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
                      semanticLabel: 'Cerrar',
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

/// El badge "ECO" solo aparece si el texto de la actividad lo menciona literalmente, nunca por inferencia.
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
                    color: AppColors.oliveText,
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

  /// El opt-in de Sello ECO del negocio aplica a toda fila, además del match de texto "eco" por actividad.
  final bool ecoSeal;

  bool get _isEco =>
      ecoSeal || activityLabel(label).toLowerCase().contains('eco');

  @override
  Widget build(BuildContext context) {
    final isEco = _isEco;
    return DetailIconRow(
      icon: activityIcon(label),
      label: activityLabel(label),
      iconColor: isEco ? AppColors.oliveText : AppColors.settingsTextMuted,
      iconBackground: isEco
          ? AppColors.detailActivityIconBg
          : AppColors.settingsBackground,
      trailing: isEco ? const EcoBadge() : null,
    );
  }
}

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
                borderRadius: BorderRadius.circular(AppRadius.pill),
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

/// Tarjeta informativa, no un CTA de reserva: igual que el resto del
/// detalle, termina en el mismo botón de WhatsApp de [_ContactBar] — el
/// flujo de reservas en vivo se eliminó por completo en agosto 2026.
class _DayPassSection extends StatelessWidget {
  const _DayPassSection({required this.business});

  final BusinessModel business;

  void _contact(BuildContext context) {
    launchWhatsApp(
      context,
      business.contactPhone,
      message:
          'Hola, vi el pase de día de ${business.name} en Níkara y me '
          'gustaría más información.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = business.dayPassPrice;
    return DetailSection(
      title: 'Pase de día',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.mapControlBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (price != null)
              Text(
                '\$${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} por persona',
                style: AppTextStyles.detailActivityLabel.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (business.dayPassIncludes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in business.dayPassIncludes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.settingsBackground,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            amenityIcon(item),
                            size: 15,
                            color: AppColors.settingsTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              item,
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
            ],
            if (business.dayPassSchedule.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: AppColors.settingsTextMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      business.dayPassSchedule,
                      style: AppTextStyles.detailDescriptionText,
                    ),
                  ),
                ],
              ),
            ],
            if (business.dayPassNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppColors.settingsTextMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      business.dayPassNotes,
                      style: AppTextStyles.detailDescriptionText.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: business.contactPhone.isEmpty
                  ? null
                  : () => _contact(context),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Preguntar por el pase de día',
                      style: AppTextStyles.detailInlineLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: AppColors.oliveText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Canal de novedades del negocio ("promo del día", un pase de día puntual,
/// un evento, un aviso de cierre) — publicado manualmente por el dueño desde
/// `ManageBusinessPostsScreen`. No lleva "editar"/"borrar" acá: esa gestión
/// vive solo en el flujo del dueño, esta es la vista pública de solo lectura.
class _AnnouncementsSection extends StatelessWidget {
  const _AnnouncementsSection({required this.posts});

  final List<BusinessPostModel> posts;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Anuncios',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < posts.length; i++) ...[
            _AnnouncementCard(post: posts[i]),
            if (i != posts.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.post});

  final BusinessPostModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.relativeTime(),
            style: AppTextStyles.wizardCaption.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(post.body, style: AppTextStyles.detailDescriptionText),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: LocalImage(path: post.imageUrl),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nunca fabrica un horario que el modelo no tenga: la prosa libre se muestra
/// literal y solo el formato estructurado del wizard se traduce a días y horas
/// legibles (crudo decía "1,2,3,4,5: 07:00–18:00").
class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.business});

  final BusinessModel business;

  @override
  Widget build(BuildContext context) {
    final lines = businessScheduleLines(business.schedules);
    return DetailSection(
      title: 'Horarios',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lines.isEmpty)
                    Text(
                      'Horario no especificado',
                      style: AppTextStyles.detailScheduleLabel,
                    )
                  else
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i != 0) const SizedBox(height: AppSpacing.xs),
                      Text(lines[i], style: AppTextStyles.detailScheduleLabel),
                    ],
                ],
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

/// El anfitrión se resuelve contra `profiles` por [BusinessModel.ownerId], sin
/// importar qué cuenta esté activa; [BusinessModel.hostName] queda solo como
/// respaldo para negocios sin `owner_id` (los sembrados) o cuando `profiles` no
/// es legible (modo invitado).
class _HostSection extends StatelessWidget {
  const _HostSection({
    required this.business,
    required this.currentProfile,
    required this.ownerProfile,
    required this.onTap,
  });

  final BusinessModel business;
  final UserModel? currentProfile;
  final UserModel? ownerProfile;
  final VoidCallback onTap;

  bool get _isOwnBusiness =>
      business.ownerId.isNotEmpty &&
      currentProfile != null &&
      business.ownerId == currentProfile!.id;

  /// Una cuenta admin puede registrar y operar negocios como cualquier otra
  /// (ver CLAUDE.md > seguridad): lo que no debe pasar es que su identidad
  /// real quede a la vista de otros usuarios en una pantalla pública. Esto
  /// solo oculta el nombre/foto que se **dibujan** — la fila en
  /// `businesses.owner_id` sigue siendo la real (así el propio dueño puede
  /// seguir editando su negocio), así que sigue siendo legible por cualquiera
  /// que consulte la REST API directo con la anon key mientras RLS esté
  /// deshabilitada. El propio dueño admin sigue viendo su nombre real al
  /// entrar a su propio negocio; solo se enmascara para otros usuarios.
  bool get _maskOwnerIdentity {
    if (_isOwnBusiness) return false;
    return ownerProfile?.role == UserRole.admin;
  }

  @override
  Widget build(BuildContext context) {
    final owner = ownerProfile;
    final maskIdentity = _maskOwnerIdentity;
    return DetailSection(
      title: 'Anfitrión',
      child: _HostRow(
        hostName: business.hostName,
        linkedName: maskIdentity ? null : owner?.fullName,
        linkedAvatarUrl: maskIdentity ? null : owner?.avatarUrl,
        isOwnBusiness: _isOwnBusiness,
        hasWhatsapp: business.contactPhone.isNotEmpty,
        // Hay perfil que abrir siempre que exista owner_id: el propio va a
        // ProfileScreen, el ajeno al perfil público. Enmascarado = tampoco
        // hay a dónde llevar el toque.
        onTap: business.ownerId.isEmpty || maskIdentity ? null : onTap,
      ),
    );
  }
}

/// Sin stat inventado tipo "Anfitrión desde 2023 · N lugares": no hay dato real de antigüedad ni conteo de negocios por dueño.
class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.hostName,
    required this.linkedName,
    required this.linkedAvatarUrl,
    required this.isOwnBusiness,
    required this.hasWhatsapp,
    required this.onTap,
  });

  final String hostName;
  final String? linkedName;
  final String? linkedAvatarUrl;
  final bool isOwnBusiness;
  final bool hasWhatsapp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final linkedName = this.linkedName;
    final displayName = linkedName != null && linkedName.trim().isNotEmpty
        ? linkedName
        : (hostName.isEmpty ? 'Anfitrión Níkara' : hostName);
    final avatarPath = linkedAvatarUrl;
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim()[0].toUpperCase();

    return DetailProfileCard(
      avatar: avatarPath != null && avatarPath.isNotEmpty
          ? LocalImage(path: avatarPath)
          : Container(
              color: AppColors.oliveText,
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTextStyles.h6.copyWith(color: AppColors.surface100),
              ),
            ),
      name: displayName,
      verified: true,
      caption: onTap != null
          ? (isOwnBusiness
                ? 'Tu negocio · toca para ver tu perfil'
                : 'Toca para ver el perfil')
          : (hasWhatsapp ? 'Disponible por WhatsApp' : null),
      captionColor: onTap != null ? AppColors.oliveText : null,
      onTap: onTap,
    );
  }
}

/// [DetailMapCard] muestra una ilustración decorativa, no un mapa real.
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
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
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
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
            borderRadius: BorderRadius.circular(AppRadius.pill),
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

  void _openAuthor(BuildContext context) {
    if (review.authorId.isEmpty) return;
    pushSharedAxis(
      context,
      PublicUserProfileScreen(
        userId: review.authorId,
        fallbackName: review.authorName,
      ),
    );
  }

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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: review.authorId.isEmpty
                    ? null
                    : () => _openAuthor(context),
                customBorder: const CircleBorder(),
                child: UserAvatar(
                  avatarUrl: review.authorAvatarUrl,
                  initials: initial,
                  size: 32,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: review.authorId.isEmpty
                      ? null
                      : () => _openAuthor(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorName,
                        style: AppTextStyles.reviewAuthor,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(_relativeDate, style: AppTextStyles.reviewMeta),
                    ],
                  ),
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
          if (review.authorOrigin.hasCountry)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OriginBadge(origin: review.authorOrigin),
            ),
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
                                color: AppColors.surface100,
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

/// Sin precio ni "Reservar ahora": el flujo de reservas se eliminó por completo (ago 2026); solo quedan WhatsApp y direcciones.
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
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
                            borderRadius: BorderRadius.circular(AppRadius.md),
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

/// [BusinessDetailScreen] (no el sheet) estampa identidad, id y timestamp para construir el [ReviewModel] real.
@visibleForTesting
class ReviewDraft {
  const ReviewDraft({
    required this.rating,
    required this.comment,
    required this.mediaPaths,
  });

  final double rating;
  final String comment;
  final List<String> mediaPaths;
}

/// Usa `pickMultipleMedia` como control único para fotos y videos, ya que no hay un picker de video separado en el proyecto.
///
/// Publica desde dentro: [onSubmit] corre mientras la hoja sigue abierta, así
/// "Enviar reseña" muestra el spinner y queda bloqueado mientras dura, y la
/// hoja no se puede cerrar a medio publicar. [onSubmit] devuelve `true` si se
/// publicó, `false` si falló y `null` si ignoró la llamada; la hoja se cierra
/// salvo con `null`.
@visibleForTesting
class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    super.key,
    required this.onSubmit,
    this.initialDraft,
    this.autoSubmit = false,
  });

  final Future<bool?> Function(ReviewDraft draft) onSubmit;

  /// Reseña que no se pudo publicar: la hoja se abre con ese texto.
  final ReviewDraft? initialDraft;

  /// Envía [initialDraft] apenas se muestra la hoja ("Reintentar").
  final bool autoSubmit;

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  late int _rating = widget.initialDraft?.rating.round().clamp(1, 5) ?? 5;
  late final _commentController = TextEditingController(
    text: widget.initialDraft?.comment ?? '',
  );
  late final List<XFile> _media = [
    ...?widget.initialDraft?.mediaPaths.map(XFile.new),
  ];
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_submit());
      });
    }
  }

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

  Future<void> _submit() async {
    if (_isPublishing) return;
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      AppSnackbar.showInfo(context, 'Escribe un comentario antes de enviar');
      return;
    }
    setState(() => _isPublishing = true);
    bool? result;
    try {
      result = await widget.onSubmit(
        ReviewDraft(
          rating: _rating.toDouble(),
          comment: comment,
          mediaPaths: _media.map((x) => x.path).toList(),
        ),
      );
    } finally {
      // Con resultado la hoja se cierra, así que no se vuelve a habilitar el
      // botón un instante antes de desaparecer.
      if (mounted && result == null) setState(() => _isPublishing = false);
    }
    if (result == null || !mounted) return;
    Navigator.of(context).pop();
  }

  InputDecoration _commentDecoration() {
    return InputDecoration(
      hintText: 'Cuéntanos cómo fue tu experiencia...',
      hintStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.neutral600),
      filled: true,
      fillColor: AppColors.surface100,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: AppColors.neutral600.withValues(alpha: 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
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
    // Mientras se publica la hoja no se cierra (ni con atrás, ni arrastrando,
    // ni con la X): cerrarla a medio enviar dejaría la reseña sin dueño.
    return PopScope(
      canPop: !_isPublishing,
      child: Padding(
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
                    onTap: _isPublishing
                        ? null
                        : () => Navigator.of(context).pop(),
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
                        semanticLabel: 'Cerrar',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
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
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: isVideoPath(path)
                                  ? Container(
                                      color: AppColors.neutral800,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.videocam,
                                        color: AppColors.surface100,
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
                                  color: AppColors.removeButtonBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  semanticLabel: 'Quitar foto',
                                  size: 14,
                                  color: AppColors.surface100,
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
              // Sin doble toque: mientras `_submit` no termina, el botón queda
              // deshabilitado con spinner (`isLoading` cubre el envío
              // automático de "Reintentar").
              SizedBox(
                width: double.infinity,
                child: AppLoadingButton(
                  label: 'Enviar reseña',
                  isLoading: _isPublishing,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
