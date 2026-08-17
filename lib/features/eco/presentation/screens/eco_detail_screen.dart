import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

const List<String> _kSpanishMonths = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _formatDateTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'a.m.' : 'p.m.';
  return '${dt.day} ${_kSpanishMonths[dt.month - 1]} · $hour12:$minute $period';
}

/// Full-screen activity detail — Estados 1/2/3 of "fases-pantalla-eco":
/// Disponible ("Unirme", gold), Participando ("Abandonar actividad",
/// outline), Completada (inactive badge, final participant count). Takes
/// the [EcoActivityModel] directly (same convention as
/// `BusinessDetailScreen`) rather than just an id, then quietly refreshes
/// itself once mounted so a stale card (e.g. someone else joined a second
/// ago) doesn't linger.
class EcoDetailScreen extends StatefulWidget {
  const EcoDetailScreen({super.key, required this.activity});

  final EcoActivityModel activity;

  @override
  State<EcoDetailScreen> createState() => _EcoDetailScreenState();
}

class _EcoDetailScreenState extends State<EcoDetailScreen> {
  late EcoActivityModel _activity = widget.activity;
  bool _showFullDescription = false;
  bool _showParticipantsTab = false;
  bool _isSubmitting = false;

  List<({String userId, DateTime joinedAt})>? _participants;
  Map<String, String> _participantNames = const {};
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
      // Background refresh — keep showing the copy the caller already had
      // rather than surfacing an error for something the user didn't ask
      // for directly.
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
      _participants = null; // stale after a join/leave — refetch on demand.
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
      final names = <String, String>{};
      await Future.wait(
        participants.map((p) async {
          final profile = await AuthService().getProfileById(p.userId);
          if (profile != null) names[p.userId] = profile.fullName;
        }),
      );
      if (!mounted) return;
      setState(() {
        _participants = participants;
        _participantNames = names;
        _loadingParticipants = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _loadingParticipants = false);
    }
  }

  /// "Cómo llegar" — switches to the Mapa tab and immediately starts route
  /// preview toward this activity's coordinates (see [MapRouteRequest]).
  void _onDirections() {
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

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final status = activity.status;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _CoverHeader(activity: activity)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        activity.title,
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: AppColors.settingsTextDark,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _StatsRow(activity: activity, status: status),
                      const SizedBox(height: 10),
                      _DirectionsChip(onTap: _onDirections),
                      const SizedBox(height: 18),
                      _TabRow(
                        showingParticipants: _showParticipantsTab,
                        onSelect: (participants) {
                          setState(() => _showParticipantsTab = participants);
                          if (participants) unawaited(_loadParticipants());
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_showParticipantsTab)
                        _ParticipantsTab(
                          activity: activity,
                          participants: _participants,
                          names: _participantNames,
                          isLoading: _loadingParticipants,
                        )
                      else
                        _InfoTab(
                          activity: activity,
                          showFullDescription: _showFullDescription,
                          onToggleDescription: () => setState(
                            () => _showFullDescription = !_showFullDescription,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomAction(
              status: status,
              isSubmitting: _isSubmitting,
              onTap: _toggleJoin,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverHeader extends StatelessWidget {
  const _CoverHeader({required this.activity});

  final EcoActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const LocalImage(
            path: null,
            fallbackIcon: Icons.park_rounded,
            fallbackIconSize: 40,
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CoverCircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  _CoverCircleButton(
                    icon: Icons.ios_share_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                activity.category.toUpperCase(),
                style: AppTextStyles.mapRowTitle.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.3,
                  color: AppColors.ecoActive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverCircleButton extends StatelessWidget {
  const _CoverCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.surface100),
      ),
    );
  }
}

/// "Fecha y hora" + a second stat that changes with [status] — "Cupo"
/// (Disponible), "Tu estado" (Participando), "Estado" (Completada) — same
/// two-column layout across all three, per the reference.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.activity, required this.status});

  final EcoActivityModel activity;
  final EcoActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final (secondLabel, secondValue, valueColor) = switch (status) {
      EcoActivityStatus.available => (
        'Cupo',
        activity.spotsAvailable == null
            ? 'Abierto'
            : '${activity.spotsAvailable} disponibles',
        AppColors.ecoActive,
      ),
      EcoActivityStatus.joined => (
        'Tu estado',
        'Participando',
        AppColors.ecoActive,
      ),
      EcoActivityStatus.completed => (
        'Estado',
        'Finalizada',
        AppColors.settingsTextMuted,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Fecha y hora',
              value: _formatDateTime(activity.startTime),
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.mapControlBorder),
          Expanded(
            child: _Stat(
              label: secondLabel,
              value: secondValue,
              valueColor: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.mapRowCaption),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTextStyles.mapRowTitle.copyWith(
            fontSize: 13,
            color: valueColor ?? AppColors.settingsTextDark,
          ),
        ),
      ],
    );
  }
}

class _DirectionsChip extends StatelessWidget {
  const _DirectionsChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.directions_outlined, size: 16),
        label: const Text('Cómo llegar'),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.settingsBackground,
          foregroundColor: AppColors.settingsTextDark,
          side: const BorderSide(color: AppColors.mapControlBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 12),
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.showingParticipants, required this.onSelect});

  final bool showingParticipants;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabButton(
          label: 'Información',
          selected: !showingParticipants,
          onTap: () => onSelect(false),
        ),
        const SizedBox(width: 10),
        _TabButton(
          label: 'Participantes',
          selected: showingParticipants,
          onTap: () => onSelect(true),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: AppTextStyles.mapRowTitle.copyWith(
            fontSize: 13,
            color: selected
                ? AppColors.settingsTextDark
                : AppColors.settingsTextMuted,
          ),
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({
    required this.activity,
    required this.showFullDescription,
    required this.onToggleDescription,
  });

  final EcoActivityModel activity;
  final bool showFullDescription;
  final VoidCallback onToggleDescription;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ParticipantAvatarsRow(count: activity.participantCount),
        const SizedBox(height: 14),
        Text(
          activity.description,
          style: AppTextStyles.settingsSubtitle.copyWith(height: 1.5),
          maxLines: showFullDescription ? null : 3,
          overflow: showFullDescription ? null : TextOverflow.ellipsis,
        ),
        if (activity.description.length > 140)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: onToggleDescription,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    showFullDescription ? 'Mostrar menos' : 'Mostrar más',
                    style: AppTextStyles.mapRowTitle.copyWith(
                      fontSize: 12,
                      color: AppColors.ecoActive,
                    ),
                  ),
                  Icon(
                    showFullDescription
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: AppColors.ecoActive,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Organizador',
          style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 8),
        _OrganizerCard(activity: activity),
        if (activity.requirements.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Requisitos y qué llevar',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          for (final requirement in activity.requirements)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RequirementRow(text: requirement),
            ),
        ],
      ],
    );
  }
}

class _ParticipantAvatarsRow extends StatelessWidget {
  const _ParticipantAvatarsRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const shown = 4;
    final overlapCount = count > shown ? shown : count;
    return Row(
      children: [
        SizedBox(
          height: 32,
          width: overlapCount == 0 ? 0 : 20.0 * (overlapCount - 1) + 32,
          child: Stack(
            children: [
              for (var i = 0; i < overlapCount; i++)
                Positioned(
                  left: i * 20.0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ecoGreen500.withValues(alpha: 0.5),
                      border: Border.all(color: AppColors.surface100, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '+$count',
          style: AppTextStyles.mapRowTitle.copyWith(
            fontSize: 12,
            color: AppColors.settingsTextMuted,
          ),
        ),
      ],
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard({required this.activity});

  final EcoActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.ecoGreen500.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.park_rounded,
              size: 20,
              color: AppColors.ecoActive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        activity.organizerDisplayName,
                        style: AppTextStyles.mapRowTitle.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (activity.organizerVerified) ...[
                      const SizedBox(width: 6),
                      const _VerifiedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Organiza actividades ambientales',
                  style: AppTextStyles.mapRowCaption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.ecoActive.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 11,
            color: AppColors.ecoActive,
          ),
          const SizedBox(width: 3),
          Text(
            'VERIFICADO',
            style: AppTextStyles.mapRowTitle.copyWith(
              fontSize: 9,
              letterSpacing: 0.2,
              color: AppColors.ecoActive,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: AppColors.ecoActive,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsTab extends StatelessWidget {
  const _ParticipantsTab({
    required this.activity,
    required this.participants,
    required this.names,
    required this.isLoading,
  });

  final EcoActivityModel activity;
  final List<({String userId, DateTime joinedAt})>? participants;
  final Map<String, String> names;
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
          'Nadie se ha unido todavía — ¡sé el primero!',
          textAlign: TextAlign.center,
          style: AppTextStyles.settingsSubtitle,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${list.length} ${list.length == 1 ? 'persona participa' : 'personas participan'}',
          style: AppTextStyles.mapRowTitle.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final participant in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.mapControlBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ecoGreen500.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.ecoActive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      names[participant.userId] ?? 'Voluntario',
                      style: AppTextStyles.mapRowTitle.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sticky bottom action — "Unirme" (gold, Disponible), "Abandonar
/// actividad" (outline, Participando), or nothing at all once
/// [EcoActivityStatus.completed].
class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.status,
    required this.isSubmitting,
    required this.onTap,
  });

  final EcoActivityStatus status;
  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (status == EcoActivityStatus.completed) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.backgroundCream,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            height: 52,
            child: status == EcoActivityStatus.joined
                ? OutlinedButton(
                    onPressed: isSubmitting ? null : onTap,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.complementario1,
                      foregroundColor: AppColors.settingsDanger,
                      side: const BorderSide(color: AppColors.complementario2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: AppTextStyles.mapRowTitle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    child: isSubmitting
                        ? const _ButtonSpinner(color: AppColors.settingsDanger)
                        : const Text('Abandonar actividad'),
                  )
                : ElevatedButton(
                    onPressed: isSubmitting ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.settingsTextDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: AppTextStyles.mapRowTitle.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    child: isSubmitting
                        ? const _ButtonSpinner(
                            color: AppColors.settingsTextDark,
                          )
                        : const Text('Unirme'),
                  ),
          ),
        ),
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
