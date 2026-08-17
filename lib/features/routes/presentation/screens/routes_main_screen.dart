import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/features/routes/data/route_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/presentation/screens/create_route_wizard_screen.dart';
import 'package:nikara_app/features/routes/presentation/screens/route_detail_screen.dart';
import 'package:nikara_app/features/routes/presentation/widgets/route_card.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Las 3 pestañas pill de `RoutesMainScreen` — las dos primeras filtran las
/// rutas propias por [RouteStatus]; "Comunidad" es una fuente de datos
/// aparte (las rutas públicas de otras personas, ver
/// `RouteService.getPublicRoutes`), no un estado de una ruta propia.
enum _RoutesTab {
  active('Activas'),
  completed('Completadas'),
  community('Comunidad');

  const _RoutesTab(this.label);

  final String label;
}

/// Pestaña "Rutas" — los itinerarios propios, separados por las pastillas
/// Activas/Completadas, más una tercera "Comunidad" con las rutas públicas
/// de otras personas para copiar. Estado vacío "Armá tu primera ruta"
/// cuando todavía no hay ninguna.
class RoutesMainScreen extends StatefulWidget {
  const RoutesMainScreen({super.key});

  @override
  State<RoutesMainScreen> createState() => _RoutesMainScreenState();
}

class _RoutesMainScreenState extends State<RoutesMainScreen> {
  /// El espacio que deja libre la barra de navegación flotante de
  /// [MainLayout] — sin esto la última tarjeta y el botón "+" quedarían
  /// debajo de ella (el shell usa `extendBody: true`).
  static const _navBarClearance = 108.0;

  bool _isLoading = true;
  String? _loadError;
  List<RouteModel> _myRoutes = const [];
  List<RouteModel> _communityRoutes = const [];
  _RoutesTab _tab = _RoutesTab.active;

  @override
  void initState() {
    super.initState();
    RouteService.revision.addListener(_onChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    RouteService.revision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => unawaited(_load(silent: true));

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      // Las dos consultas van en paralelo: la pestaña Comunidad no depende
      // de que las propias hayan cargado, y viceversa.
      final results = await Future.wait([
        RouteService().getMyRoutes(),
        RouteService().getPublicRoutes(),
      ]);
      if (!mounted) return;
      setState(() {
        _myRoutes = results[0];
        _communityRoutes = results[1];
        _loadError = null;
        _isLoading = false;
      });
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  List<RouteModel> get _filtered => switch (_tab) {
    _RoutesTab.active =>
      _myRoutes
          .where((r) => r.status == RouteStatus.active)
          .toList(growable: false),
    _RoutesTab.completed =>
      _myRoutes
          .where((r) => r.status == RouteStatus.completed)
          .toList(growable: false),
    _RoutesTab.community => _communityRoutes,
  };

  Future<void> _openWizard() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateRouteWizardScreen()));
  }

  Future<void> _openDetail(RouteModel route) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)));
  }

  /// "Copiar ruta" de la tarjeta de Comunidad — clona sin salir del listado,
  /// para que copiar una ruta ajena sea un solo tap.
  Future<void> _quickCopy(RouteModel route) async {
    try {
      final copy = await RouteService().cloneRoute(route);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${copy.title}" ya está en tus rutas')),
      );
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final isCommunity = _tab == _RoutesTab.community;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary500),
              )
            : Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.primary500,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        _navBarClearance + 32,
                      ),
                      children: [
                        _RoutesHeader(count: _myRoutes.length),
                        const SizedBox(height: 18),
                        _TabPills(
                          selected: _tab,
                          onSelected: (tab) => setState(() => _tab = tab),
                        ),
                        const SizedBox(height: 18),
                        if (_loadError != null)
                          _RoutesErrorState(
                            message: _loadError!,
                            onRetry: _load,
                          )
                        else if (filtered.isEmpty)
                          _RoutesEmptyState(tab: _tab, onCreate: _openWizard)
                        else
                          for (final route in filtered)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: RouteCard(
                                route: route,
                                onTap: () => _openDetail(route),
                                showCreator: isCommunity,
                                onCopy: isCommunity
                                    ? () => _quickCopy(route)
                                    : null,
                              ),
                            ),
                      ],
                    ),
                  ),
                  // El "+" solo aparece cuando ya hay rutas propias: en el
                  // estado vacío la acción vive en el botón central "Crear
                  // ruta", y dos botones para lo mismo compiten entre sí.
                  if (_myRoutes.isNotEmpty)
                    Positioned(
                      right: 4,
                      bottom: _navBarClearance,
                      child: _CreateRouteFab(onTap: _openWizard),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RoutesHeader extends StatelessWidget {
  const _RoutesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Rutas',
            style: AppTextStyles.headingXL.copyWith(
              color: AppColors.settingsTextDark,
              fontSize: 30,
            ),
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$count ${count == 1 ? 'ruta' : 'rutas'}',
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 13,
                color: AppColors.settingsTextMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _TabPills extends StatelessWidget {
  const _TabPills({required this.selected, required this.onSelected});

  final _RoutesTab selected;
  final ValueChanged<_RoutesTab> onSelected;

  @override
  Widget build(BuildContext context) {
    // Scroll horizontal en vez de una Row fija: en un teléfono angosto (y
    // con el texto escalado) las tres pastillas no siempre entran a lo
    // ancho, y desbordar sería peor que poder deslizarlas.
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final tab in _RoutesTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _StatusPill(
                label: tab.label,
                selected: tab == selected,
                onTap: () => onSelected(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.surface100,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: AppColors.mapControlBorder),
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

/// "Armá tu primera ruta" — ilustración central, copy y el botón de acción.
/// El copy y el ícono cambian según [tab]; "Completadas" es la única que se
/// queda sin botón (marcar una ruta como completada pasa por el detalle,
/// no por acá).
class _RoutesEmptyState extends StatelessWidget {
  const _RoutesEmptyState({required this.tab, required this.onCreate});

  final _RoutesTab tab;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle, showButton) = switch (tab) {
      _RoutesTab.active => (
        Icons.route_rounded,
        'Armá tu primera ruta',
        'Combiná lugares y actividades ECO en un itinerario por días.',
        true,
      ),
      _RoutesTab.completed => (
        Icons.flag_rounded,
        'Todavía no completás ninguna ruta',
        'Cuando termines una ruta, marcala como completada y la vas a '
            'encontrar acá.',
        false,
      ),
      _RoutesTab.community => (
        Icons.groups_rounded,
        'Todavía no hay rutas públicas',
        'Sé la primera persona en publicar una ruta para que otros '
            'viajeros la copien.',
        true,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 72),
      child: Column(
        children: [
          Container(
            width: 148,
            height: 148,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.warmChipBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: AppColors.primary500),
          ),
          const SizedBox(height: 26),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle.copyWith(
              color: AppColors.settingsTextDark,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 14),
          ),
          if (showButton) ...[
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.detailPrimaryButtonGlow,
                    offset: Offset(0, 6),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.settingsTextDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 15),
                ),
                child: const Text('Crear ruta'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateRouteFab extends StatelessWidget {
  const _CreateRouteFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primary500,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.detailPrimaryButtonGlow,
              offset: Offset(0, 6),
              blurRadius: 18,
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 30,
          color: AppColors.settingsTextDark,
        ),
      ),
    );
  }
}

class _RoutesErrorState extends StatelessWidget {
  const _RoutesErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 56),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: AppColors.settingsDanger,
          ),
          const SizedBox(height: 12),
          Text(
            'No se pudieron cargar tus rutas',
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
    );
  }
}
