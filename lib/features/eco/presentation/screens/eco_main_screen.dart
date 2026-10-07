import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nikara_app/core/utils/search_normalize.dart';

import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_activity_card.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_discovery_header.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_organizer.dart';
import 'package:nikara_app/features/eco/utils/eco_icons.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/category_icons_row.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/face_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

const String _kAllCategories = 'Todas';

/// El carrusel promociona, no reemplaza el listado: las mismas actividades siguen apareciendo abajo en "Descubre más".
const int _kFeaturedCount = 3;

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
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final _featuredController = PageController();
  int _featuredPage = 0;

  @override
  void initState() {
    super.initState();
    EcoService.revision.addListener(_onChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    EcoService.revision.removeListener(_onChanged);
    _featuredController.dispose();
    _searchController.dispose();
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
      // Se abre solo tras la primera carga exitosa: no tiene sentido un socket abierto para una pantalla que nunca cargó.
      _unsubscribe ??= EcoService().subscribeToChanges(_onChanged);
    } on EcoServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  List<EcoActivityModel> get _filtered => _activities.where((activity) {
    final matchesCategory =
        _selectedCategory == _kAllCategories ||
        activity.category == _selectedCategory;
    final matchesSearch =
        _searchQuery.isEmpty ||
        normalizeForSearch(
          '${activity.title} ${activity.description} ${activity.location} ${activity.category}',
        ).contains(normalizeForSearch(_searchQuery));
    return matchesCategory && matchesSearch;
  }).toList();

  int get _joinedCount =>
      _activities.where((a) => a.isJoinedByCurrentUser).length;

  /// Primero las que aún no se unió (leen como "únete a esta"), luego el resto, siempre en orden de proximidad.
  List<EcoActivityModel> get _featured {
    final filtered = _filtered;
    final ordered = [
      ...filtered.where((a) => !a.isJoinedByCurrentUser),
      ...filtered.where((a) => a.isJoinedByCurrentUser),
    ];
    return ordered.take(_kFeaturedCount).toList();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _featuredPage = 0;
    });
    if (_featuredController.hasClients) _featuredController.jumpToPage(0);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
      _featuredPage = 0;
    });
    if (_featuredController.hasClients) _featuredController.jumpToPage(0);
  }

  Future<void> _openFilterSheet() async {
    final category = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtrar actividades', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              for (final category in [_kAllCategories, ...kEcoCategories])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    category == _kAllCategories
                        ? Icons.grid_view_rounded
                        : ecoCategoryIcon(category),
                  ),
                  title: Text(category, style: AppTextStyles.body),
                  trailing: category == _selectedCategory
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.oliveText,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, category),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && category != null) _selectCategory(category);
  }

  Future<void> _openDetail(EcoActivityModel activity) async {
    await pushSharedAxis(context, EcoDetailScreen(activity: activity));
  }

  Future<void> _toggleJoin(EcoActivityModel activity) async {
    if (!await GuestGuard.allow(context, GuestFeature.eco)) return;
    if (!mounted) return;
    if (!await FaceGuard.allow(context, FaceLimitedAction.ecoJoin)) return;
    if (!mounted) return;
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
      AppSnackbar.showError(context, e.message);
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
    final featured = _featured;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SearchHeaderWidget(
            headerContent: EcoDiscoveryHeader(
              availableCount: _isLoading || _loadError != null
                  ? null
                  : _activities.length,
            ),
            showNotifications: false,
            searchHint: 'Buscar actividades ambientales...',
            controller: _searchController,
            onSearchChanged: _onSearchChanged,
            onFilterTap: _openFilterSheet,
            categoryContent: CategoryIconsRow(
              categories: kEcoCategories,
              iconBuilder: ecoCategoryIcon,
              iconColor: AppColors.oliveText,
              allLabel: _kAllCategories,
              selected: _selectedCategory == _kAllCategories
                  ? null
                  : _selectedCategory,
              onSelect: (category) =>
                  _selectCategory(category ?? _kAllCategories),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.oliveText,
                      ),
                    )
                  : _loadError != null
                  ? _EcoErrorState(message: _loadError!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.oliveText,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.lg,
                          AppSpacing.xl,
                          AppSpacing.xxxl,
                        ),
                        children: [
                          if (_joinedCount > 0) ...[
                            _JoinedBanner(count: _joinedCount),
                            const SizedBox(height: 16),
                          ],
                          if (filtered.isEmpty)
                            const _EcoEmptyState()
                          else ...[
                            if (featured.isNotEmpty) ...[
                              _FeaturedCarousel(
                                activities: featured,
                                controller: _featuredController,
                                page: _featuredPage,
                                onPageChanged: (page) =>
                                    setState(() => _featuredPage = page),
                                onOpen: _openDetail,
                                onJoin: _toggleJoin,
                              ),
                              const SizedBox(height: 22),
                            ],
                            Text(
                              'Descubre más',
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: AppColors.settingsTextDark,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final (index, activity) in filtered.indexed)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child:
                                    EcoActivityCard(
                                          activity: activity,
                                          onTap: () => _openDetail(activity),
                                        )
                                        .animate(
                                          delay:
                                              AppMotion.microDuration * index,
                                        )
                                        .fadeIn(
                                          duration: AppMotion.standardDuration,
                                          curve: AppMotion.enter,
                                        )
                                        .slideY(
                                          begin: 0.08,
                                          duration: AppMotion.standardDuration,
                                          curve: AppMotion.enter,
                                        ),
                              ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.oliveText,
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

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({
    required this.activities,
    required this.controller,
    required this.page,
    required this.onPageChanged,
    required this.onOpen,
    required this.onJoin,
  });

  static const _cardHeight = 340.0;

  final List<EcoActivityModel> activities;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<EcoActivityModel> onOpen;
  final ValueChanged<EcoActivityModel> onJoin;

  @override
  Widget build(BuildContext context) {
    final current = page.clamp(0, activities.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _cardHeight,
          child: PageView.builder(
            controller: controller,
            itemCount: activities.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _FeaturedCard(
                  activity: activity,
                  onTap: () => onOpen(activity),
                  onJoin: () => onJoin(activity),
                ),
              );
            },
          ),
        ),
        if (activities.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < activities.length; i++)
                AnimatedContainer(
                  duration: AppMotion.quickDuration,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == current ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == current
                        ? AppColors.oliveText
                        : AppColors.mapControlBorder,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
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
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                    path: activity.imageUrl,
                    fallbackIcon: ecoCategoryIcon(activity.category),
                    fallbackIconSize: 36,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _OrganizerChip(
                      activity: activity,
                      onTap: () => openEcoOrganizerProfile(context, activity),
                    ),
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
                          color: AppColors.oliveFill,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'Empieza pronto',
                          style: AppTextStyles.mapRowTitle.copyWith(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: Text(
                      activity.title,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.settingsTextDark,
                        fontSize: 18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      activity.description,
                      style: AppTextStyles.settingsSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                              // Mismo par que el CTA del detalle: el estado
                              // "disponible" del modelo especifica "Unirme"
                              // en dorado, y sobre un Fill de marca va tinta
                              // oscura, nunca blanco.
                              backgroundColor: AppColors.primary500,
                              foregroundColor: AppColors.settingsTextDark,
                              disabledBackgroundColor:
                                  AppColors.settingsBackground,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              textStyle: AppTextStyles.mapRowTitle.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            child: Text(
                              activity.isJoinedByCurrentUser
                                  ? 'Unido'
                                  : 'Unirme',
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
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              textStyle: AppTextStyles.mapRowTitle.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            child: const Text(
                              'Más información',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerChip extends StatelessWidget {
  const _OrganizerChip({required this.activity, required this.onTap});

  final EcoActivityModel activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = activity.organizationLogoUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(logo == null ? 10 : 5, 5, 10, 5),
        decoration: BoxDecoration(
          color: AppColors.detailCoverCounterBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo == null || logo.isEmpty)
              const Icon(
                Icons.groups_rounded,
                size: 12,
                color: AppColors.surface100,
              )
            else
              EcoOrganizerAvatar(activity: activity, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                activity.organizerDisplayName.toUpperCase(),
                style: AppTextStyles.mapRowTitle.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.3,
                  color: AppColors.surface100,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (activity.organizerIsVerified) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.verified_rounded,
                size: 12,
                color: AppColors.ecoGreen500,
              ),
            ],
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.destructive,
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
                backgroundColor: AppColors.oliveText,
                foregroundColor: AppColors.textInverted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
