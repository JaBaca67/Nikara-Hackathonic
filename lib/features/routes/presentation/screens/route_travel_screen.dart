import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/directions_service.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_theme.dart';
import '../../data/route_service.dart';
import '../../data/route_travel_service.dart';
import '../../domain/models/route_model.dart';
import '../../domain/models/route_stop_model.dart';
import '../widgets/route_mini_map.dart';
import '../widgets/route_stop_avatar.dart';
import 'route_overview_screen.dart';

/// A tourist's personal checklist and entry point into existing GPS guidance.
class RouteTravelScreen extends StatefulWidget {
  const RouteTravelScreen({super.key, required this.route, this.travelService});
  final RouteModel route;
  final RouteTravelService? travelService;
  @override
  State<RouteTravelScreen> createState() => _RouteTravelScreenState();
}

class _RouteTravelScreenState extends State<RouteTravelScreen> {
  late final _service = widget.travelService ?? RouteTravelService.instance;
  late final String _accountId = AuthService().currentAuthUser?.id ?? 'guest';
  int _day = 1;
  TravelMode _mode = TravelMode.driving;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.open(widget.route, accountId: _accountId);
      if (!mounted) return;
      final session = _service.active.value!;
      _day =
          session.route.stops.where(session.isPending).firstOrNull?.dayNumber ??
          session.route.stops.firstOrNull?.dayNumber ??
          1;
    } catch (_) {
      if (mounted) _error = 'No se pudo cargar el progreso de tu ruta.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _sameAccount =>
      (AuthService().currentAuthUser?.id ?? 'guest') == _accountId;

  Future<void> _mark(RouteStopModel stop, StopVisitStatus? status) async {
    if (_busy || !_sameAccount) return;
    setState(() => _busy = true);
    try {
      await _service.setStatus(
        accountId: _accountId,
        routeId: widget.route.id,
        visitKey: stop.visitKey,
        status: status,
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'No se pudo guardar el progreso. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    if (_busy || !_sameAccount) return;
    setState(() => _busy = true);
    try {
      await _service.deactivate(
        accountId: _accountId,
        routeId: widget.route.id,
      );
      if (!mounted) return;
      AppSnackbar.showInfo(
        context,
        'Modo ruta desactivado. Tu progreso se conservó.',
      );
      await Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(context, 'No se pudo desactivar el modo ruta.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _navigate(RouteStopModel stop) {
    if (_busy || !_sameAccount || !stop.hasCoordinates) return;
    MapFocusController().startRoutePreview(
      MapRouteRequest(
        destinationId: stop.kind == RouteStopKind.business
            ? stop.sourceId
            : 'route-stop-${stop.visitKey}',
        destinationName: stop.title,
        latitude: stop.latitude!,
        longitude: stop.longitude!,
        routeId: widget.route.id,
        stopVisitKey: stop.visitKey,
        accountId: _accountId,
        mode: _mode,
        category: stop.category.label,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _finish() async {
    if (_busy || !_sameAccount) return;
    setState(() => _busy = true);
    try {
      await RouteService().updateRoute(
        widget.route.id,
        status: RouteStatus.completed,
      );
      if (mounted) {
        setState(() => _completed = true);
        AppSnackbar.showSuccess(context, 'Ruta completada');
      }
    } on RouteServiceException catch (e) {
      if (mounted) AppSnackbar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      title: Text(
        'Modo ruta',
        style: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Desactivar modo ruta',
          onPressed: _busy ? null : _deactivate,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          )
        : ValueListenableBuilder<RouteTravelSession?>(
            valueListenable: _service.active,
            builder: (context, session, _) {
              if (session == null ||
                  session.route.id != widget.route.id ||
                  session.accountId != _accountId ||
                  !_sameAccount) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Modo ruta desactivado.'),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Volver al itinerario'),
                      ),
                    ],
                  ),
                );
              }
              final stops = session.route.stopsForDay(_day);
              final next = session.nextForDay(_day);
              final skipped = session.progress.values
                  .where((s) => s == StopVisitStatus.skipped)
                  .length;
              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.mapControlBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.route.title,
                            style: AppTextStyles.detailTitle.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${session.visitedCount} de ${session.route.stopCount} paradas visitadas',
                            style: AppTextStyles.settingsSubtitle,
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: session.route.stopCount == 0
                                  ? 0
                                  : session.visitedCount /
                                        session.route.stopCount,
                              color: AppColors.oliveText,
                              backgroundColor: AppColors.profileDivider,
                              minHeight: 8,
                            ),
                          ),
                          if (skipped > 0) ...[
                            const SizedBox(height: 6),
                            Text(
                              '$skipped omitidas',
                              style: AppTextStyles.settingsSubtitle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Elige el día', style: AppTextStyles.mapRowTitle),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var day = 1; day <= session.route.days; day++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('Día $day'),
                                selected: day == _day,
                                onSelected: (_) => setState(() => _day = day),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.warmChipBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.mapControlBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            next == null
                                ? (stops.isEmpty
                                      ? 'Día libre'
                                      : 'Día finalizado')
                                : 'Siguiente parada',
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (next != null) ...[
                            Row(
                              children: [
                                RouteStopAvatar(stop: next, size: 56),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        next.title,
                                        style: AppTextStyles.detailTitle
                                            .copyWith(
                                              color: AppColors.textPrimary,
                                              fontSize: 20,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (next.subtitle.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          next.subtitle,
                                          style: AppTextStyles.settingsSubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!next.hasCoordinates)
                              Text(
                                'Esta parada no tiene ubicación para navegar.',
                                style: AppTextStyles.settingsSubtitle,
                              ),
                            const SizedBox(height: 12),
                            SegmentedButton<TravelMode>(
                              showSelectedIcon: false,
                              segments: [
                                for (final mode in TravelMode.values)
                                  ButtonSegment(
                                    value: mode,
                                    icon: Icon(
                                      mode == TravelMode.driving
                                          ? Icons.directions_car_rounded
                                          : Icons.directions_walk_rounded,
                                    ),
                                    label: Text(mode.label),
                                  ),
                              ],
                              selected: {_mode},
                              onSelectionChanged: (selection) =>
                                  setState(() => _mode = selection.first),
                            ),
                            FilledButton.icon(
                              onPressed: _busy || !next.hasCoordinates
                                  ? null
                                  : () => _navigate(next),
                              icon: const Icon(Icons.navigation_rounded),
                              label: const Text('Ir a esta parada'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary500,
                                foregroundColor: AppColors.textPrimary,
                                minimumSize: const Size.fromHeight(50),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'En el mapa podrás revisar e iniciar la navegación.',
                              style: AppTextStyles.settingsSubtitle.copyWith(
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: _busy
                                        ? null
                                        : () => _mark(
                                            next,
                                            StopVisitStatus.visited,
                                          ),
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                    ),
                                    label: const Text('Registrar visita'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      textStyle: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _mark(
                                            next,
                                            StopVisitStatus.skipped,
                                          ),
                                    icon: const Icon(Icons.skip_next_rounded),
                                    label: const Text('Omitir'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      foregroundColor:
                                          AppColors.settingsTextDark,
                                      textStyle: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              'Selecciona otro día cuando quieras continuar.',
                              style: AppTextStyles.settingsSubtitle,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    RouteMiniMap(
                      stops: stops,
                      interactive: true,
                      onExpand: () => pushSharedAxis(
                        context,
                        RouteOverviewScreen(
                          title: session.route.title,
                          stops: stops,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final stop in stops)
                      Card(
                        color: AppColors.surface100,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  RouteStopAvatar(stop: stop, size: 46),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stop.title,
                                          style: AppTextStyles.mapRowTitle,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          switch (session.progress[stop
                                              .visitKey]) {
                                            StopVisitStatus.visited =>
                                              'Visitada',
                                            StopVisitStatus.skipped =>
                                              'Omitida',
                                            null =>
                                              stop.hasCoordinates
                                                  ? 'Pendiente · Con ubicación'
                                                  : 'Pendiente · Sin ubicación',
                                          },
                                          style: AppTextStyles.settingsSubtitle
                                              .copyWith(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 4,
                                children: session.isPending(stop)
                                    ? [
                                        TextButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _mark(
                                                  stop,
                                                  StopVisitStatus.visited,
                                                ),
                                          icon: const Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Marcar visita'),
                                        ),
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _mark(
                                                  stop,
                                                  StopVisitStatus.skipped,
                                                ),
                                          child: const Text('Omitir parada'),
                                        ),
                                      ]
                                    : [
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _mark(stop, null),
                                          child: const Text('Deshacer'),
                                        ),
                                      ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (session.isFinished) ...[
                      Text(
                        skipped == 0
                            ? '¡Visitaste todas las paradas!'
                            : 'Recorrido finalizado con $skipped paradas omitidas.',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (session.route.isOwnedBy(_accountId) &&
                          !_completed &&
                          session.route.status != RouteStatus.completed)
                        FilledButton(
                          onPressed: _busy ? null : _finish,
                          child: const Text('Marcar ruta como completada'),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
  );
}
