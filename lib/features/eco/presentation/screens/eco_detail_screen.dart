import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nikara_app/features/business/presentation/widgets/social_contact_row.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nikara_app/shared/widgets/origin_badge.dart';
import 'package:nikara_app/shared/widgets/user_avatar.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/permission_service.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/features/admin/presentation/widgets/rejection_reason_dialog.dart';
import 'package:nikara_app/features/business/data/review_service.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/data/eco_moment_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_moment_state.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_moment_policy_sheet.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_organizer.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_participant_avatars.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_participation.dart';
import 'package:nikara_app/features/eco/utils/eco_format.dart';
import 'package:nikara_app/features/eco/utils/eco_icons.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';
import 'package:nikara_app/features/routes/presentation/widgets/add_to_route_bottom_sheet.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/detail_sections.dart';
import 'package:nikara_app/shared/widgets/face_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Reutiliza la estructura de `BusinessDetailScreen`/`detail_sections.dart`; recibe el [EcoActivityModel] completo y se refresca al montarse por si quedó desactualizado.
class EcoDetailScreen extends StatefulWidget {
  const EcoDetailScreen({super.key, required this.activity});

  final EcoActivityModel activity;

  @override
  State<EcoDetailScreen> createState() => _EcoDetailScreenState();
}

class _EcoDetailScreenState extends State<EcoDetailScreen> {
  static const _coverHeight = 296.0;

  late EcoActivityModel _activity = widget.activity;
  int _tab = 0;
  bool _showFullDescription = false;

  /// Mientras se une o sale de la actividad: bloquea el segundo toque.
  bool _isJoining = false;

  List<EcoParticipant>? _participants;
  bool _loadingParticipants = false;

  List<ReviewModel>? _moments;
  bool _loadingMoments = false;
  bool _postingMoment = false;
  EcoMomentState? _momentState;
  String? _momentError;
  Future<void> Function()? _stopMomentChanges;
  bool _momentRefreshPending = false;

  bool _savingReview = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    void refreshMoments() {
      if (mounted && _tab == 2) unawaited(_loadMoments(force: true));
    }

    _stopMomentChanges = EcoMomentService().subscribeToChanges(
      _activity.id,
      refreshMoments,
    );
  }

  @override
  void dispose() {
    final stopMoments = _stopMomentChanges;
    if (stopMoments != null) unawaited(stopMoments());
    super.dispose();
  }

  bool get _canReview => PermissionService().can(Permission.reviewSubmissions);

  Future<void> _approveActivity() async {
    final organizerId = _activity.organizerId;
    final title = _activity.title;
    setState(() => _savingReview = true);
    try {
      await AdminService().reviewEcoActivity(
        id: _activity.id,
        status: ReviewStatus.aprobado,
      );
      await _notifyOrganizer(organizerId, title, approved: true);
      await _refresh();
      if (!mounted) return;
      AppSnackbar.showSuccess(context, '"$title" quedó publicada.');
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  Future<void> _rejectActivity() async {
    final organizerId = _activity.organizerId;
    final title = _activity.title;
    final reason = await showRejectionReasonDialog(
      context,
      subjectName: title.isEmpty ? 'esta jornada' : title,
    );
    if (reason == null || !mounted) return;
    setState(() => _savingReview = true);
    try {
      await AdminService().reviewEcoActivity(
        id: _activity.id,
        status: ReviewStatus.rechazado,
        reason: reason,
      );
      await _notifyOrganizer(
        organizerId,
        title,
        approved: false,
        reason: reason,
      );
      await _refresh();
      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        'Rechazaste "$title". Le avisamos a quien la organiza.',
      );
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } on PermissionDeniedException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  /// El aviso a quien organiza no puede tumbar la revisión: si falla, se
  /// registra y se sigue — mismo criterio que
  /// `AdminService._notifyReviewed` para negocios.
  Future<void> _notifyOrganizer(
    String? organizerId,
    String title, {
    required bool approved,
    String? reason,
  }) async {
    if (organizerId == null || organizerId.isEmpty) return;
    try {
      await NotificationService().notifyEcoActivityReviewed(
        organizerId: organizerId,
        activityId: _activity.id,
        activityTitle: title,
        approved: approved,
        reason: reason,
      );
    } on NotificationServiceException catch (e) {
      debugPrint(
        '[EcoDetailScreen] _notifyOrganizer: no se pudo avisar — ${e.message}',
      );
    }
  }

  Future<void> _refresh() async {
    try {
      final fresh = await EcoService().getActivityById(_activity.id);
      if (fresh != null && mounted) setState(() => _activity = fresh);
    } on EcoServiceException {
      // Refresco en segundo plano: si falla, se sigue mostrando la copia que ya traía.
    }
  }

  /// Unirse o salir según el estado actual. Los avisos, la confirmación al
  /// salir y los casos especiales viven en [EcoParticipation].
  Future<void> _toggleJoin() =>
      _activity.isJoinedByCurrentUser ? _leave() : _join();

  Future<void> _join() => _runParticipation(
    () => EcoParticipation.join(
      context,
      _activity,
      onRetry: () => unawaited(_join()),
    ),
  );

  Future<void> _leave({bool confirmed = false}) => _runParticipation(
    () => EcoParticipation.leave(
      context,
      _activity,
      confirmed: confirmed,
      // Ya se confirmó la primera vez: reintentar no vuelve a preguntar.
      onRetry: () => unawaited(_leave(confirmed: true)),
    ),
  );

  /// Un solo cambio de participación a la vez. El estado de la pantalla solo
  /// cambia con lo que devuelve el servidor (no se finge antes): al unirse, el
  /// botón pasa a "Abandonar" y suben los cupos ocupados al instante.
  Future<void> _runParticipation(
    Future<EcoActivityModel?> Function() action,
  ) async {
    if (_isJoining) return;
    setState(() => _isJoining = true);
    try {
      final updated = await action();
      if (!mounted || updated == null) return;
      setState(() {
        _activity = updated;
        _participants = null; // quedó viejo tras unirse/salir — se re-pide.
      });
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _loadParticipants() async {
    if (_participants != null || _loadingParticipants) return;
    setState(() => _loadingParticipants = true);
    try {
      final participants = await EcoService().getParticipants(_activity.id);
      if (!mounted) return;
      setState(() {
        _participants = participants;
        _loadingParticipants = false;
      });
    } on EcoServiceException {
      if (!mounted) return;
      setState(() => _loadingParticipants = false);
    }
  }

  Future<void> _loadMoments({bool force = false}) async {
    if (_loadingMoments) {
      if (force) _momentRefreshPending = true;
      return;
    }
    if (_moments != null && !force) return;
    setState(() {
      _loadingMoments = true;
      _momentError = null;
      _momentState = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ReviewService().getForEcoActivity(_activity.id),
        EcoMomentService().getState(_activity.id),
      ]);
      if (!mounted) return;
      setState(() {
        _moments = results[0] as List<ReviewModel>;
        _momentState = results[1] as EcoMomentState?;
        _loadingMoments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMoments = false;
        _momentError = 'No se pudieron cargar los mensajes y sus permisos.';
      });
    } finally {
      if (mounted && _momentRefreshPending) {
        _momentRefreshPending = false;
        unawaited(_loadMoments(force: true));
      }
    }
  }

  Future<void> _manageMoments() async {
    final state = _momentState;
    if (state == null || !state.canManage) return;
    final saved = await showModalBottomSheet<EcoMomentState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xxl),
        ),
      ),
      builder: (_) => EcoMomentPolicySheet(
        state: state,
        onSave: ({required enabled, maxMessages, maxAccounts, maxPerAccount}) =>
            EcoMomentService().savePolicy(
              _activity.id,
              enabled: enabled,
              maxMessages: maxMessages,
              maxAccounts: maxAccounts,
              maxPerAccount: maxPerAccount,
            ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _momentState = saved);
    AppSnackbar.showSuccess(context, 'Configuración de Momentos guardada.');
    await _loadMoments(force: true);
  }

  /// "Comparte tu experiencia": comentario + fotos de quien ya está
  /// participando, publicado en vivo durante la jornada (no una reseña de
  /// cierre). Reusa `ReviewService`/`reviews` con `targetType:
  /// 'eco_activity'` — ver la nota de esa clase.
  Future<void> _openShareMoment() async {
    try {
      final state = await EcoMomentService().getState(_activity.id);
      if (!mounted) return;
      if (state == null || !state.canPost) {
        AppSnackbar.showError(
          context,
          state?.blockedReason ?? 'Inicia sesión para compartir.',
        );
        await _loadMoments(force: true);
        return;
      }
    } on EcoMomentException catch (e) {
      if (mounted) AppSnackbar.showError(context, e.message);
      return;
    }
    if (!await FaceGuard.allow(context, FaceLimitedAction.resena)) return;
    if (!mounted) return;
    final draft = await showModalBottomSheet<_MomentDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ShareMomentSheet(),
    );
    if (draft == null || !mounted) return;
    setState(() => _postingMoment = true);
    try {
      await ReviewService().addReview(
        targetId: _activity.id,
        targetType: ReviewService.ecoActivityTargetType,
        // Sin estrellas en el composer: un "Momento" no califica la jornada,
        // la documenta. El rating queda fijo porque la columna lo exige
        // (`check (rating between 1 and 5)`), no porque se le pida a quien
        // participa.
        rating: 5,
        comment: draft.comment,
        mediaFiles: draft.images,
      );
      await _loadMoments(force: true);
      if (!mounted) return;
      AppSnackbar.showSuccess(context, '¡Gracias por compartir tu momento!');
    } on ReviewServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
      await _loadMoments(force: true);
    } finally {
      if (mounted) setState(() => _postingMoment = false);
    }
  }

  void _openDirections() {
    if (!_activity.hasCoordinates) {
      AppSnackbar.showError(
        context,
        'Esta actividad todavía no tiene ubicación en el mapa.',
      );
      return;
    }
    MapFocusController().startRoutePreview(
      MapRouteRequest(
        destinationId: 'eco-${_activity.id}',
        destinationName: _activity.title,
        latitude: _activity.latitude!,
        longitude: _activity.longitude!,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showComingSoon() {
    AppSnackbar.showInfo(context, 'Próximamente');
  }

  Future<void> _addToRoute() async {
    await AddToRouteBottomSheet.showForEcoActivity(context, _activity);
  }

  DetailQuickInfoItem get _statusInfoItem {
    final activity = _activity;
    return switch (activity.status) {
      EcoActivityStatus.available => DetailQuickInfoItem(
        label: 'Cupo',
        value: activity.spotsAvailable == null
            ? 'Abierto'
            : '${activity.spotsAvailable} disponibles',
        valueColor: AppColors.oliveText,
      ),
      EcoActivityStatus.joined => const DetailQuickInfoItem(
        label: 'Tu estado',
        value: 'Participando',
        valueColor: AppColors.oliveText,
      ),
      EcoActivityStatus.completed => const DetailQuickInfoItem(
        label: 'Estado',
        value: 'Finalizada',
        valueColor: AppColors.settingsTextMuted,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;

    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailCoverImage(
              // Portada única (`eco_activities.image_url`): la lista lleva a lo
              // sumo un elemento, así que el carrusel de DetailCoverImage nunca
              // muestra flechas aquí.
              photos: [?activity.imageUrl],
              height: _coverHeight,
              fallbackIcon: ecoCategoryIcon(activity.category),
              onBack: () => Navigator.of(context).maybePop(),
              caption: _CoverCaption(activity: activity),
              actions: [
                DetailCoverIconButton(
                  icon: Icons.add_road_rounded,
                  onTap: _addToRoute,
                  label: 'Agregar a una ruta',
                ),
                const SizedBox(width: 8),
                DetailCoverIconButton(
                  icon: Icons.ios_share,
                  onTap: _showComingSoon,
                  label: 'Compartir jornada',
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -kDetailQuickInfoOverlap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: DetailQuickInfoCard(
                  items: [
                    DetailQuickInfoItem(
                      label: 'Fecha y hora',
                      value: formatEcoDateTimeShort(activity.startTime),
                    ),
                    _statusInfoItem,
                  ],
                ),
              ),
            ),
            if (_canReview)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: AdminInlineReviewCard(
                  status: activity.reviewStatus,
                  rejectionReason: activity.rejectionReason,
                  saving: _savingReview,
                  onApprove: _approveActivity,
                  onReject: _rejectActivity,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DetailSegmentedTabs(
                    labels: const ['Información', 'Participantes', 'Momentos'],
                    selected: _tab,
                    onChanged: (tab) {
                      setState(() => _tab = tab);
                      if (tab == 1) unawaited(_loadParticipants());
                      if (tab == 2) unawaited(_loadMoments(force: true));
                    },
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: switch (_tab) {
                      0 => _InformationTab(
                        activity: activity,
                        showFullDescription: _showFullDescription,
                        onToggleDescription: () => setState(
                          () => _showFullDescription = !_showFullDescription,
                        ),
                        onDirections: _openDirections,
                      ),
                      1 => _ParticipantsTab(
                        participants: _participants,
                        isLoading: _loadingParticipants,
                      ),
                      _ => _MomentsTab(
                        moments: _moments,
                        isLoading: _loadingMoments,
                        canShare:
                            !_loadingMoments && _momentState?.canPost == true,
                        isPosting: _postingMoment,
                        onShare: _openShareMoment,
                        state: _momentState,
                        error: _momentError,
                        onManage: _manageMoments,
                        onRefresh: () => unawaited(_loadMoments(force: true)),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _EcoActionBar(
        status: activity.status,
        isFull: activity.isFull,
        isJoining: _isJoining,
        onTap: _toggleJoin,
      ),
    );
  }
}

class _CoverCaption extends StatelessWidget {
  const _CoverCaption({required this.activity});

  final EcoActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (activity.category.trim().isNotEmpty)
          DetailCoverTagPill(
            label: activity.category.toUpperCase(),
            background: AppColors.surface100,
            foreground: AppColors.oliveText,
          ),
        const SizedBox(height: 10),
        Text(
          activity.title,
          style: AppTextStyles.detailTitle.copyWith(
            color: AppColors.surface100,
            fontSize: 22,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (activity.location.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                size: 14,
                color: AppColors.surface100,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  activity.location,
                  style: AppTextStyles.detailRatingCount.copyWith(
                    color: AppColors.surface100.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InformationTab extends StatelessWidget {
  const _InformationTab({
    required this.activity,
    required this.showFullDescription,
    required this.onToggleDescription,
    required this.onDirections,
  });

  final EcoActivityModel activity;
  final bool showFullDescription;
  final VoidCallback onToggleDescription;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _ParticipantsPreview(activity: activity),
      _DescriptionSection(
        activity: activity,
        expanded: showFullDescription,
        onToggle: onToggleDescription,
      ),
      DetailSection(
        title: 'Organizador',
        child: DetailProfileCard(
          avatar: EcoOrganizerAvatar(activity: activity, size: 48),
          name: activity.organizerDisplayName,
          // Handle de la fundación si publicó una organización; si no, invitación a ver el perfil personal.
          caption:
              activity.organizerHandle ??
              (activity.isFromOrganization
                  ? 'Organiza actividades ambientales'
                  : 'Toca para ver su perfil'),
          captionColor: AppColors.oliveText,
          verified: activity.organizerIsVerified,
          accent: AppColors.oliveText,
          onTap: () => openEcoOrganizerProfile(context, activity),
        ),
      ),
      if (_activityContacts(activity).isNotEmpty)
        DetailSection(
          title: 'Contacto y redes',
          child: SocialHub(contacts: _activityContacts(activity)),
        ),
      if (activity.requirements.isNotEmpty)
        DetailSection(
          title: 'Requisitos y qué llevar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final requirement in activity.requirements) ...[
                DetailIconRow(
                  icon: ecoRequirementIcon(requirement),
                  label: requirement,
                  iconColor: AppColors.oliveText,
                  iconBackground: AppColors.detailActivityIconBg,
                ),
                if (requirement != activity.requirements.last)
                  const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      DetailSection(
        title: 'Cómo llegar',
        child: DetailMapCard(
          address: activity.location.isEmpty
              ? 'Ubicación por confirmar'
              : activity.location,
          caption: 'Se abrirá en el mapa de Níkara',
          onTap: onDirections,
          pinColor: AppColors.oliveText,
          pinIconColor: AppColors.surface100,
        ),
      ),
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

List<SocialContact> _activityContacts(EcoActivityModel activity) => [
  if ((activity.contactPhone ?? '').trim().isNotEmpty) ...[
    SocialContact.whatsapp(activity.contactPhone!),
    SocialContact.phone(activity.contactPhone!),
  ],
  if ((activity.instagramLink ?? '').trim().isNotEmpty)
    SocialContact.instagram(activity.instagramLink!),
  if ((activity.facebookLink ?? '').trim().isNotEmpty)
    SocialContact.facebook(activity.facebookLink!),
];

class _ParticipantsPreview extends StatelessWidget {
  const _ParticipantsPreview({required this.activity});

  final EcoActivityModel activity;

  @override
  Widget build(BuildContext context) {
    if (activity.participantCount <= 0) {
      return Text(
        'Nadie se ha unido todavía — ¡sé la primera persona!',
        style: AppTextStyles.settingsSubtitle,
      );
    }
    return EcoParticipantAvatars(
      count: activity.participantCount,
      participants: activity.visibleParticipants,
    );
  }
}

/// Fila de participante con foto real y enlace a su perfil público.
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant, required this.onTap});

  final EcoParticipant participant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = participant.avatarUrl;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;

    return Material(
      color: AppColors.surface100,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.detailActivityIconBg,
                ),
                clipBehavior: Clip.antiAlias,
                child: hasPhoto
                    ? LocalImage(path: avatarUrl, fallbackIcon: Icons.person)
                    : Center(
                        child: Text(
                          participant.initials,
                          style: AppTextStyles.mapRowTitle.copyWith(
                            fontSize: 14,
                            color: AppColors.oliveText,
                          ),
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
                      participant.displayName,
                      style: AppTextStyles.mapRowTitle.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (participant.origin.hasCountry)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: OriginBadge(origin: participant.origin),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Se unió el ${formatEcoDateTimeShort(participant.joinedAt)}',
                      style: AppTextStyles.settingsSubtitle.copyWith(
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.neutral400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({
    required this.activity,
    required this.expanded,
    required this.onToggle,
  });

  final EcoActivityModel activity;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final description = activity.description.trim().isEmpty
        ? 'Esta actividad todavía no tiene descripción.'
        : activity.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: AppTextStyles.detailDescriptionText,
          maxLines: expanded ? null : 3,
          overflow: expanded ? null : TextOverflow.ellipsis,
        ),
        if (description.length > 140) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onToggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  expanded ? 'Mostrar menos' : 'Mostrar más',
                  style: AppTextStyles.detailInlineLink.copyWith(
                    color: AppColors.oliveText,
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 15,
                  color: AppColors.oliveText,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ParticipantsTab extends StatelessWidget {
  const _ParticipantsTab({required this.participants, required this.isLoading});

  final List<EcoParticipant>? participants;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
      );
    }
    final list = participants ?? const [];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Text(
          'Nadie se ha unido todavía — ¡sé la primera persona!',
          textAlign: TextAlign.center,
          style: AppTextStyles.settingsSubtitle,
        ),
      );
    }
    return DetailSection(
      title: list.length == 1
          ? '1 persona participa'
          : '${list.length} personas participan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final participant in list) ...[
            _ParticipantRow(
              participant: participant,
              onTap: () => openParticipantProfile(context, participant),
            ),
            if (participant != list.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Siempre presente (nunca se oculta) para que el botón principal no cambie de posición entre estados.
///
/// [isJoining] es el único estado de carga: mientras dura, "Unirme" muestra su
/// spinner (`AppLoadingButton`) y "Abandonar actividad" el equivalente
/// —spinner y deshabilitado—, así que ninguno admite un segundo toque.
class _EcoActionBar extends StatelessWidget {
  const _EcoActionBar({
    required this.status,
    required this.isFull,
    required this.isJoining,
    required this.onTap,
  });

  final EcoActivityStatus status;

  /// Cupo lleno (`EcoActivityModel.isFull`) — solo importa en
  /// [EcoActivityStatus.available]: una jornada sin cupo ya no acepta
  /// "Unirme". El servidor es quien de verdad lo bloquea (trigger
  /// `enforce_eco_capacity`, 039); esto solo evita el viaje de red inútil y
  /// se lo comunica a quien mira antes de que lo intente.
  final bool isFull;
  final bool isJoining;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final blockedByCapacity = status == EcoActivityStatus.available && isFull;
    return DetailBottomBar(
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: switch (status) {
          EcoActivityStatus.completed => FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Actividad finalizada'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.segmentedTrackBg,
              foregroundColor: AppColors.settingsTextMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppTextStyles.detailBottomBarPrimary,
            ),
          ),
          EcoActivityStatus.joined => OutlinedButton(
            onPressed: isJoining ? null : onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.coralPaleFill,
              foregroundColor: AppColors.destructive,
              side: const BorderSide(color: AppColors.coralPaleBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppTextStyles.detailBottomBarSecondary,
            ),
            child: isJoining
                ? const AppSpinner(color: AppColors.destructive)
                : const Text('Abandonar actividad'),
          ),
          EcoActivityStatus.available when blockedByCapacity =>
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.event_busy_rounded, size: 18),
              label: const Text('Cupo lleno'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.segmentedTrackBg,
                foregroundColor: AppColors.settingsTextMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                textStyle: AppTextStyles.detailBottomBarPrimary,
              ),
            ),
          EcoActivityStatus.available => DecoratedBox(
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
            // Dorado sobre fondo claro con tinta oscura: el CTA de ECO (ver
            // CLAUDE.md > Tiers de pantalla, excepción del módulo ECO).
            child: AppLoadingButton(
              label: 'Unirme',
              isLoading: isJoining,
              onPressed: onTap,
            ),
          ),
        },
      ),
    );
  }
}

/// "Momentos": comentarios + fotos que quienes participan comparten durante
/// la jornada, no una reseña de cierre. [canShare] solo mira si la cuenta
/// actual está unida — compartir no depende de que la jornada ya terminara.
class _MomentsTab extends StatelessWidget {
  const _MomentsTab({
    required this.moments,
    required this.isLoading,
    required this.canShare,
    required this.isPosting,
    required this.onShare,
    required this.state,
    required this.error,
    required this.onManage,
    required this.onRefresh,
  });

  final List<ReviewModel>? moments;
  final bool isLoading;
  final bool canShare;
  final bool isPosting;
  final VoidCallback onShare;
  final EcoMomentState? state;
  final String? error;
  final VoidCallback onManage;
  final VoidCallback onRefresh;

  Widget _controls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (state?.canManage == true) ...[
        OutlinedButton.icon(
          onPressed: onManage,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Administrar Momentos'),
        ),
        Text(
          '${state!.messageCount}${state!.maxMessages == null ? "" : "/${state!.maxMessages}"} mensajes · ${state!.accountCount}${state!.maxAccounts == null ? "" : "/${state!.maxAccounts}"} cuentas de participantes',
          style: AppTextStyles.settingsSubtitle,
        ),
      ],
      if (error != null) ...[
        Text(error!, style: AppTextStyles.settingsSubtitle),
        TextButton(onPressed: onRefresh, child: const Text('Reintentar')),
      ] else if (!isLoading && !canShare)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            state?.blockedReason ??
                'Inicia sesión y únete a la actividad para compartir.',
            style: AppTextStyles.settingsSubtitle,
          ),
        ),
      if (state?.canManage == true && state?.enabled == false)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            'Mensajes de participantes cerrados. Puedes seguir publicando como administrador.',
            style: AppTextStyles.settingsSubtitle,
          ),
        ),
      if (canShare) _composer(),
    ],
  );

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        onPressed: isPosting ? null : onShare,
        icon: isPosting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.oliveText,
                ),
              )
            : const Icon(Icons.add_a_photo_outlined, size: 18),
        label: const Text('Comparte tu experiencia'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.oliveText,
          side: const BorderSide(color: AppColors.oliveText),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        children: [
          _controls(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            ),
          ),
        ],
      );
    }
    final list = moments ?? const [];
    if (list.isEmpty) {
      return Column(
        children: [
          _controls(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Text(
              'Todavía no hay momentos compartidos — ¡sé la primera persona!',
              textAlign: TextAlign.center,
              style: AppTextStyles.settingsSubtitle,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _controls(),
        for (final moment in list) ...[
          _MomentCard(moment: moment),
          if (moment != list.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Tarjeta de un "Momento" — misma base visual que la reseña de un negocio
/// (`_ReviewCard` en `business_detail_screen.dart`), sin estrellas porque
/// acá el rating no se le pide a quien participa (ver [_openShareMoment]).
class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});

  final ReviewModel moment;

  String get _relativeDate {
    final days = DateTime.now().difference(moment.date).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'hace 1 día';
    if (days < 7) return 'hace $days días';
    if (days < 30) return 'hace ${(days / 7).floor()} semana(s)';
    return 'hace ${(days / 30).floor()} mes(es)';
  }

  @override
  Widget build(BuildContext context) {
    final initial = moment.authorName.trim().isEmpty
        ? '?'
        : moment.authorName.trim()[0].toUpperCase();
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
              UserAvatar(
                avatarUrl: moment.authorAvatarUrl,
                initials: initial,
                size: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.authorName,
                      style: AppTextStyles.reviewAuthor,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(_relativeDate, style: AppTextStyles.reviewMeta),
                  ],
                ),
              ),
            ],
          ),
          if (moment.authorOrigin.hasCountry)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: OriginBadge(origin: moment.authorOrigin),
            ),
          if (moment.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(moment.comment, style: AppTextStyles.reviewComment),
          ],
          if (moment.mediaPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: moment.mediaPaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: LocalImage(path: moment.mediaPaths[index]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo que devuelve [_ShareMomentSheet]: comentario + fotos sin subir todavía
/// (se suben recién al confirmar, en `_openShareMoment`).
class _MomentDraft {
  const _MomentDraft({required this.comment, required this.images});

  final String comment;
  final List<XFile> images;
}

/// Mismo patrón que `_WriteReviewSheet` de `business_detail_screen.dart`,
/// sin estrellas y limitado a fotos (no video): acá lo que importa es
/// documentar el momento, no calificar la jornada.
class _ShareMomentSheet extends StatefulWidget {
  const _ShareMomentSheet();

  @override
  State<_ShareMomentSheet> createState() => _ShareMomentSheetState();
}

class _ShareMomentSheetState extends State<_ShareMomentSheet> {
  final _commentController = TextEditingController();
  final List<XFile> _images = [];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    setState(() => _images.addAll(picked));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  void _submit() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty && _images.isEmpty) {
      AppSnackbar.showInfo(
        context,
        'Escribe algo o agrega una foto antes de enviar',
      );
      return;
    }
    Navigator.of(context).pop(_MomentDraft(comment: comment, images: _images));
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
                  'Comparte tu experiencia',
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
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Cuéntanos qué está pasando en la jornada...',
                hintStyle: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.neutral600,
                ),
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
                  borderSide: BorderSide(
                    color: AppColors.wizardFocus,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface200.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.oliveText.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.oliveText,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text('Agregar fotos', style: AppTextStyles.subtitle2),
                  ],
                ),
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = _images[index].path;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: LocalImage(path: path),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.oliveFill,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  'Publicar',
                  style: AppTextStyles.buttonLg.copyWith(
                    color: AppColors.textPrimary,
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
