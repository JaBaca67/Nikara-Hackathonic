import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_organizer.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_participant_avatars.dart';
import 'package:nikara_app/features/eco/utils/eco_format.dart';
import 'package:nikara_app/features/eco/utils/eco_icons.dart';
import 'package:nikara_app/features/routes/presentation/widgets/add_to_route_bottom_sheet.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/detail_sections.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
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
  bool _isSubmitting = false;

  List<EcoParticipant>? _participants;
  bool _loadingParticipants = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final fresh = await EcoService().getActivityById(_activity.id);
      if (fresh != null && mounted) setState(() => _activity = fresh);
    } on EcoServiceException {
      // Refresco en segundo plano: si falla, se sigue mostrando la copia que ya traía.
    }
  }

  Future<void> _toggleJoin() async {
    if (!await GuestGuard.allow(context, GuestFeature.eco)) return;
    final joining = !_activity.isJoinedByCurrentUser;
    setState(() {
      _isSubmitting = true;
      _activity = _activity.withParticipation(
        isJoined: joining,
        participantCount: _activity.participantCount + (joining ? 1 : -1),
      );
    });
    try {
      if (joining) {
        await EcoService().joinActivity(_activity.id);
      } else {
        await EcoService().leaveActivity(_activity.id);
      }
      _participants = null; // quedó viejo tras unirse/salir — se re-pide.
    } on EcoServiceException catch (e) {
      setState(() {
        _activity = _activity.withParticipation(
          isJoined: !joining,
          participantCount: _activity.participantCount + (joining ? -1 : 1),
        );
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta actividad todavía no tiene ubicación en el mapa.',
          ),
        ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Próximamente')));
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
        valueColor: AppColors.ecoActive,
      ),
      EcoActivityStatus.joined => const DetailQuickInfoItem(
        label: 'Tu estado',
        value: 'Participando',
        valueColor: AppColors.ecoActive,
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
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
        isSubmitting: _isSubmitting,
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
            foreground: AppColors.ecoActive,
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
          captionColor: AppColors.ecoActive,
          verified: activity.organizerIsVerified,
          accent: AppColors.ecoActive,
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
                  iconColor: AppColors.ecoActive,
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
          pinColor: AppColors.ecoActive,
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
      participants: activity.participants,
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                            color: AppColors.ecoActive,
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
                    color: AppColors.ecoActive,
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 15,
                  color: AppColors.ecoActive,
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
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary500),
        ),
      );
    }
    final list = participants ?? const [];
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
class _EcoActionBar extends StatelessWidget {
  const _EcoActionBar({
    required this.status,
    required this.isSubmitting,
    required this.onTap,
  });

  final EcoActivityStatus status;
  final bool isSubmitting;
  final VoidCallback onTap;

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
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: AppTextStyles.detailBottomBarPrimary,
            ),
          ),
          EcoActivityStatus.joined => OutlinedButton(
            onPressed: isSubmitting ? null : onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.complementario1,
              foregroundColor: AppColors.settingsDanger,
              side: const BorderSide(color: AppColors.complementario2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: AppTextStyles.detailBottomBarSecondary,
            ),
            child: isSubmitting
                ? const _ButtonSpinner(color: AppColors.settingsDanger)
                : const Text('Abandonar actividad'),
          ),
          EcoActivityStatus.available => DecoratedBox(
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
            child: FilledButton(
              onPressed: isSubmitting ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.settingsTextDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: AppTextStyles.detailBottomBarPrimary,
              ),
              child: isSubmitting
                  ? const _ButtonSpinner(color: AppColors.settingsTextDark)
                  : const Text('Unirme'),
            ),
          ),
        },
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
