import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/permission_service.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/features/admin/presentation/widgets/rejection_reason_dialog.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
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

  bool _savingReview = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
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
              offset: const Offset(0, -18),
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
                    labels: const ['Información', 'Participantes'],
                    selected: _tab,
                    onChanged: (tab) {
                      setState(() => _tab = tab);
                      if (tab == 1) unawaited(_loadParticipants());
                    },
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: _tab == 0
                        ? _InformationTab(
                            activity: activity,
                            showFullDescription: _showFullDescription,
                            onToggleDescription: () => setState(
                              () =>
                                  _showFullDescription = !_showFullDescription,
                            ),
                            onDirections: _openDirections,
                          )
                        : _ParticipantsTab(
                            participants: _participants,
                            isLoading: _loadingParticipants,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _EcoActionBar(
        status: activity.status,
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
    required this.isJoining,
    required this.onTap,
  });

  final EcoActivityStatus status;
  final bool isJoining;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
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
