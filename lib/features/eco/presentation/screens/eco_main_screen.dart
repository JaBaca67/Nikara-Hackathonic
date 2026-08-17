import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_status_badge.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

const String _kAllCategories = 'Todas';

/// "Actividades Ambientales" tab — category filters, a "ya te uniste a X"
/// banner, one featured Hero card (the soonest upcoming activity), and a
/// list of the rest. Ports the "Pantallaecomockgeneral" reference exactly:
/// same section order, same badge language ("Unido"/"Disponible"/
/// "Completada" via [EcoStatusBadge]).
class EcoMainScreen extends StatefulWidget {
  const EcoMainScreen({super.key});

  @override
  State<EcoMainScreen> createState() => _EcoMainScreenState();
}

class _EcoMainScreenState extends State<EcoMainScreen> {
  bool _isLoading = true;
  String? _loadError;
  List<EcoActivityModel> _activities = const [];
  String _selectedCategory = _kAllCategories;
  Future<void> Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    EcoService.revision.addListener(_onChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    EcoService.revision.removeListener(_onChanged);
    unawaited(_unsubscribe?.call() ?? Future<void>.value());
    super.dispose();
  }

  void _onChanged() => unawaited(_load(silent: true));

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final activities = await EcoService().getUpcomingActivities();
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _loadError = null;
        _isLoading = false;
      });
      // Opened after the first successful load, same reasoning as
      // BusinessStorageService's realtime subscription — no point holding
      // a socket open for a screen that never managed to load.
      _unsubscribe ??= EcoService().subscribeToChanges(_onChanged);
    } on EcoServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  List<EcoActivityModel> get _filtered => _selectedCategory == _kAllCategories
      ? _activities
      : _activities.where((a) => a.category == _selectedCategory).toList();

  int get _joinedCount =>
      _activities.where((a) => a.isJoinedByCurrentUser).length;

  /// The single featured card — the soonest-starting activity the user
  /// hasn't already joined stands out more ("join this one next") than
  /// re-featuring one they're already committed to; falls back to
  /// whichever is soonest if every filtered activity is already joined.
  EcoActivityModel? get _hero {
    final filtered = _filtered;
    if (filtered.isEmpty) return null;
    for (final activity in filtered) {
      if (!activity.isJoinedByCurrentUser) return activity;
    }
    return filtered.first;
  }

  Future<void> _openDetail(EcoActivityModel activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EcoDetailScreen(activity: activity)),
    );
  }

  Future<void> _toggleJoin(EcoActivityModel activity) async {
    if (!await GuestGuard.allow(context, GuestFeature.eco)) return;
    final joining = !activity.isJoinedByCurrentUser;
    _applyOptimistic(activity.id, joining: joining);
    try {
      if (joining) {
        await EcoService().joinActivity(activity.id);
      } else {
        await EcoService().leaveActivity(activity.id);
      }
    } on EcoServiceException catch (e) {
      _applyOptimistic(activity.id, joining: !joining);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _applyOptimistic(String activityId, {required bool joining}) {
    setState(() {
      _activities = [
        for (final a in _activities)
          if (a.id == activityId)
            a.withParticipation(
              isJoined: joining,
              participantCount: a.participantCount + (joining ? 1 : -1),
            )
          else
            a,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hero = _hero;
    final rest = hero == null
        ? filtered
        : filtered.where((a) => a.id != hero.id).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary500),
              )
            : _loadError != null
            ? _EcoErrorState(message: _loadError!, onRetry: _load)
            : RefreshIndicator(
                color: AppColors.ecoActive,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    const _EcoHeader(),
                    const SizedBox(height: 18),
                    _CategoryFilterRow(
                      selected: _selectedCategory,
                      onSelected: (category) =>
                          setState(() => _selectedCategory = category),
                    ),
                    const SizedBox(height: 16),
                    if (_joinedCount > 0) ...[
                      _JoinedBanner(count: _joinedCount),
                      const SizedBox(height: 16),
                    ],
                    if (filtered.isEmpty)
                      const _EcoEmptyState()
                    else ...[
                      if (hero != null) ...[
                        _EcoHeroCard(
                          activity: hero,
                          onTap: () => _openDetail(hero),
                          onJoin: () => _toggleJoin(hero),
                        ),
                        const SizedBox(height: 20),
                      ],
                      for (final activity in rest)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _EcoListCard(
                            activity: activity,
                            onTap: () => _openDetail(activity),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _EcoHeader extends StatelessWidget {
  const _EcoHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.ecoGreen500.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.eco_rounded,
            color: AppColors.ecoActive,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Actividades Ambientales',
                style: AppTextStyles.homeGreeting,
              ),
              const SizedBox(height: 2),
              Text(
                'Iniciativas verificadas cerca de ti',
                style: AppTextStyles.settingsSubtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  static const _categories = [_kAllCategories, ...kEcoCategories];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.ecoActive
                      : AppColors.surface100,
                  borderRadius: BorderRadius.circular(999),
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.mapControlBorder),
                ),
                child: Text(
                  category,
                  style: AppTextStyles.mapRowTitle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.surface100
                        : AppColors.settingsTextMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JoinedBanner extends StatelessWidget {
  const _JoinedBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.ecoGreen500.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ecoActive,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.surface100,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? 'Ya te uniste a 1 actividad'
                  : 'Ya te uniste a $count actividades',
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 13,
                color: AppColors.settingsTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The single featured card — cover, organizer chip, "Empieza pronto" tag
/// when [EcoActivityModel.startsSoon], title/description, and the two
/// primary actions ("Unirme"/"Más información").
class _EcoHeroCard extends StatelessWidget {
  const _EcoHeroCard({
    required this.activity,
    required this.onTap,
    required this.onJoin,
  });

  final EcoActivityModel activity;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.mapControlBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.mapCardShadow,
            offset: Offset(0, 8),
            blurRadius: 26,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LocalImage(
                    path: null,
                    fallbackIcon: Icons.park_rounded,
                    fallbackIconSize: 36,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _OrganizerChip(activity: activity, dark: true),
                  ),
                  if (activity.startsSoon)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary500,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Empieza pronto',
                          style: AppTextStyles.mapRowTitle.copyWith(
                            fontSize: 11,
                            color: AppColors.settingsTextDark,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  activity.title,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.settingsTextDark,
                    fontSize: 18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  activity.description,
                  style: AppTextStyles.settingsSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed:
                              activity.status == EcoActivityStatus.completed
                              ? null
                              : onJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                            foregroundColor: AppColors.settingsTextDark,
                            disabledBackgroundColor:
                                AppColors.settingsBackground,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: AppTextStyles.mapRowTitle.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          child: Text(
                            activity.isJoinedByCurrentUser ? 'Unido' : 'Unirme',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.settingsBackground,
                            foregroundColor: AppColors.settingsTextDark,
                            side: const BorderSide(
                              color: AppColors.mapControlBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: AppTextStyles.mapRowTitle.copyWith(
                              fontSize: 13,
                            ),
                          ),
                          child: const Text('Más información'),
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

class _EcoListCard extends StatelessWidget {
  const _EcoListCard({required this.activity, required this.onTap});

  final EcoActivityModel activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.mapControlBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: const SizedBox(
                width: 64,
                height: 64,
                child: LocalImage(path: null, fallbackIcon: Icons.eco_outlined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _OrganizerChip(activity: activity, dark: false),
                  const SizedBox(height: 4),
                  Text(
                    activity.title,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.settingsTextDark,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.description,
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EcoStatusBadge(status: activity.status),
          ],
        ),
      ),
    );
  }
}

/// "VOLUNTARIOS DEL PACÍFICO" small-caps organizer label, with the people
/// icon from the mock — [dark] swaps to a light-on-dark chip for use over
/// the hero card's cover image vs. a plain muted label in a list row.
class _OrganizerChip extends StatelessWidget {
  const _OrganizerChip({required this.activity, required this.dark});

  final EcoActivityModel activity;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      activity.organizerDisplayName.toUpperCase(),
      style: AppTextStyles.mapRowTitle.copyWith(
        fontSize: 10,
        letterSpacing: 0.3,
        color: dark ? AppColors.surface100 : AppColors.settingsTextMuted,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final icon = Icon(
      Icons.groups_rounded,
      size: 12,
      color: dark ? AppColors.surface100 : AppColors.settingsTextMuted,
    );
    if (!dark) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Flexible(child: label),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 5),
          Flexible(child: label),
        ],
      ),
    );
  }
}

class _EcoEmptyState extends StatelessWidget {
  const _EcoEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.eco_outlined, size: 40, color: AppColors.neutral400),
          const SizedBox(height: 12),
          Text(
            'No hay actividades en esta categoría todavía.',
            textAlign: TextAlign.center,
            style: AppTextStyles.settingsSubtitle,
          ),
        ],
      ),
    );
  }
}

class _EcoErrorState extends StatelessWidget {
  const _EcoErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.settingsDanger,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar las actividades',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.mapRowCaption,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
