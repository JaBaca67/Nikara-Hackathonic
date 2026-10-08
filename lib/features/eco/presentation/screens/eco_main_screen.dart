import 'dart:async';
import 'package:nikara_app/core/models/geographic_destination.dart';
import 'package:nikara_app/core/services/discovery_destination_service.dart';
import 'package:nikara_app/shared/widgets/geographic_filter_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:nikara_app/core/utils/search_normalize.dart';

import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_activity_card.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_discovery_header.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_organizer.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_participation.dart';
import 'package:nikara_app/features/eco/utils/eco_icons.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/category_icons_row.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

const String _kAllCategories = 'Todas';

enum _EcoActivityFilter { available, participating, finished }

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
  _EcoActivityFilter _activityFilter = _EcoActivityFilter.available;
  Future<void> Function()? _unsubscribe;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  GeographicDestination _destination = const GeographicDestination();

  final _featuredController = PageController();
  int _featuredPage = 0;

  @override
  void initState() {
    super.initState();
    _destination = DiscoveryDestinationService().destination.value;
    DiscoveryDestinationService().destination.addListener(
      _onDestinationChanged,
    );
    EcoService.revision.addListener(_onChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    DiscoveryDestinationService().destination.removeListener(
      _onDestinationChanged,
    );
    EcoService.revision.removeListener(_onChanged);
    _featuredController.dispose();
    _searchController.dispose();
    unawaited(_unsubscribe?.call() ?? Future<void>.value());
    super.dispose();
  }

  void _onChanged() => unawaited(_load(silent: true));

  void _onDestinationChanged() {
    setState(() {
      _destination = DiscoveryDestinationService().destination.value;
      _featuredPage = 0;
    });
    if (_featuredController.hasClients) _featuredController.jumpToPage(0);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        EcoService().getUpcomingActivities(),
        EcoService().getPastActivities(),
      ]);
      final activities = [...results[0], ...results[1]];
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
    final matchesFilter = switch (_activityFilter) {
      _EcoActivityFilter.available => !activity.isPast,
      _EcoActivityFilter.participating =>
        !activity.isPast && activity.isJoinedByCurrentUser,
      _EcoActivityFilter.finished => activity.isPast,
    };
    final matchesCategory =
        _selectedCategory == _kAllCategories ||
        activity.category == _selectedCategory;
    final matchesSearch =
        _searchQuery.isEmpty ||
        normalizeForSearch(
          '${activity.title} ${activity.description} ${activity.location} ${activity.category}',
        ).contains(normalizeForSearch(_searchQuery));
    return matchesFilter &&
        matchesCategory &&
        matchesSearch &&
        _destination.matches(
          municipalityByCode(activity.municipalityCode) ??
              resolveLegacyEcoMunicipality(activity.location),
        );
  }).toList();

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

  void _selectActivityFilter(_EcoActivityFilter filter) {
    setState(() {
      _activityFilter = filter;
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
    final result = await showGeographicDestinationPicker(
      context,
      initial: _destination,
    );
    if (!mounted || result == null) return;
    DiscoveryDestinationService().destination.value = result.destination;
  }

  Future<void> _openDetail(EcoActivityModel activity) async {
    await pushSharedAxis(context, EcoDetailScreen(activity: activity));
  }

  /// Actividades cuyo "Unirme"/"Unido" está en curso: bloquean el segundo
  /// toque de esa tarjeta y muestran su spinner.
  final Set<String> _joiningIds = {};

  /// Unirse o salir según el estado actual. Los avisos, la confirmación al
  /// salir y los casos especiales viven en [EcoParticipation]. El estado de la
  /// tarjeta solo cambia con lo que devuelve el servidor: no se finge antes.
  Future<void> _toggleJoin(
    EcoActivityModel activity, {
    bool confirmedLeave = false,
  }) async {
    if (_joiningIds.contains(activity.id)) return;
    setState(() => _joiningIds.add(activity.id));
    try {
      // El reintento parte de la copia más reciente, no de la que se tocó.
      void retry({bool leaving = false}) {
        final latest = _activities.firstWhere(
          (a) => a.id == activity.id,
          orElse: () => activity,
        );
        unawaited(_toggleJoin(latest, confirmedLeave: leaving));
      }

      final updated = activity.isJoinedByCurrentUser
          ? await EcoParticipation.leave(
              context,
              activity,
              confirmed: confirmedLeave,
              onRetry: () => retry(leaving: true),
            )
          : await EcoParticipation.join(context, activity, onRetry: retry);
      if (!mounted || updated == null) return;
      _replaceActivity(updated);
    } finally {
      if (mounted) setState(() => _joiningIds.remove(activity.id));
    }
  }

  void _replaceActivity(EcoActivityModel updated) {
    setState(() {
      _activities = [
        for (final a in _activities)
          if (a.id == updated.id) updated else a,
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
                  : _activities.where((activity) => !activity.isPast).length,
            ),
            showNotifications: false,
            searchHint: _destination.isActive
                ? 'Buscar en ${_destination.label}...'
                : 'Buscar actividades ambientales...',
            controller: _searchController,
            onSearchChanged: _onSearchChanged,
            onFilterTap: _openFilterSheet,
            categoryContent: CategoryIconsRow(
              categories: kEcoCategories,
              labelBuilder: ecoCategoryLabel,
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
                          AppSpacing.xxl,
                          AppSpacing.xl,
                          AppSpacing.xxxl,
                        ),
                        children: [
                          _ActivityFilterButtons(
                            selected: _activityFilter,
                            onSelected: _selectActivityFilter,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          if (filtered.isEmpty)
                            _destination.isActive
                                ? Text(
                                    'No hay próximas jornadas que coincidan en ${_destination.label}.',
                                  )
                                : _EcoEmptyState(filter: _activityFilter)
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
                                joiningIds: _joiningIds,
                              ),
                              const SizedBox(height: AppSpacing.xxxl),
                            ],
                            Text(
                              'Descubre más',
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: AppColors.settingsTextDark,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
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

class _ActivityFilterButtons extends StatelessWidget {
  const _ActivityFilterButtons({
    required this.selected,
    required this.onSelected,
  });

  final _EcoActivityFilter selected;
  final ValueChanged<_EcoActivityFilter> onSelected;

  static const _items = [
    (_EcoActivityFilter.available, 'Disponibles'),
    (_EcoActivityFilter.participating, 'Participando'),
    (_EcoActivityFilter.finished, 'Finalizadas'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ecoGreen500.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final (filter, label) in _items)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == filter,
                child: GestureDetector(
                  onTap: () => onSelected(filter),
                  child: AnimatedContainer(
                    duration: AppMotion.quickDuration,
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected == filter
                          ? AppColors.oliveText
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: AppTextStyles.mapRowTitle.copyWith(
                        fontSize: 11,
                        color: selected == filter
                            ? AppColors.surface100
                            : AppColors.settingsTextDark,
                      ),
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

class _FeaturedCarousel extends StatelessWidget {
  const _FeaturedCarousel({
    required this.activities,
    required this.controller,
    required this.page,
    required this.onPageChanged,
    required this.onOpen,
    required this.onJoin,
    required this.joiningIds,
  });

  static const _cardHeight = 360.0;

  final List<EcoActivityModel> activities;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<EcoActivityModel> onOpen;
  final Future<void> Function(EcoActivityModel) onJoin;

  /// Actividades con un "Unirme"/"Unido" en curso (spinner y sin segundo toque).
  final Set<String> joiningIds;

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
                  isJoining: joiningIds.contains(activity.id),
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
    required this.isJoining,
  });

  final EcoActivityModel activity;
  final VoidCallback onTap;
  final Future<void> Function() onJoin;
  final bool isJoining;

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
              height: 145,
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
                  Text(
                    activity.title,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.settingsTextDark,
                      fontSize: 18,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
                          // Mismo CTA que el detalle: dorado con tinta oscura
                          // (el módulo ECO puede combinar Gold y Olive), con
                          // spinner y sin segundo toque mientras se guarda.
                          child: AppLoadingButton(
                            label:
                                activity.isFull &&
                                    !activity.isJoinedByCurrentUser
                                ? 'Cupo lleno'
                                : activity.isJoinedByCurrentUser
                                ? 'Unido'
                                : 'Unirme',
                            isLoading: isJoining,
                            onPressed:
                                activity.status ==
                                        EcoActivityStatus.completed ||
                                    (activity.isFull &&
                                        !activity.isJoinedByCurrentUser)
                                ? null
                                : onJoin,
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
  const _EcoEmptyState({required this.filter});

  final _EcoActivityFilter filter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.eco_outlined, size: 40, color: AppColors.neutral400),
          const SizedBox(height: 12),
          Text(
            switch (filter) {
              _EcoActivityFilter.available =>
                'No hay actividades disponibles en esta categoría.',
              _EcoActivityFilter.participating =>
                'Aún no participas en actividades de esta categoría.',
              _EcoActivityFilter.finished =>
                'Todavía no hay actividades finalizadas en esta categoría.',
            },
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
