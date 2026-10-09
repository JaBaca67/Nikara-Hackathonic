import 'dart:async';
import 'route_overview_screen.dart';
import 'route_travel_screen.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/routes/data/route_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/presentation/screens/create_route_wizard_screen.dart';
import 'package:nikara_app/features/routes/presentation/screens/full_screen_map_screen.dart';
import 'package:nikara_app/features/routes/presentation/widgets/route_card.dart';
import 'package:nikara_app/features/routes/presentation/widgets/route_mini_map.dart';
import 'package:nikara_app/features/routes/presentation/widgets/route_stop_avatar.dart';
import 'package:nikara_app/shared/widgets/app_confirm_dialog.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Detalle de una ruta armada: mini-mapa con las paradas numeradas y el
/// timeline del itinerario día por día.
///
/// Si la ruta es de otra persona, en lugar de "Editar / Eliminar" muestra
/// "Copiar / Usar esta ruta", que clona el itinerario completo en la cuenta
/// propia para editarlo sin tocar el original.
class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({super.key, required this.route});

  final RouteModel route;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  late RouteModel _route = widget.route;
  bool _isBusy = false;
  int _mapDay = 1;

  String? get _currentUserId => AuthService().currentAuthUser?.id;

  bool get _isOwner => _route.isOwnedBy(_currentUserId);

  Future<void> _openSource() async {
    final uri = Uri.tryParse(_route.sourceUrl ?? '');
    try {
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const FormatException('Fuente no disponible');
      }
    } on Exception {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'No se pudo abrir la fuente de la ruta.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final fresh = await RouteService().getRouteById(_route.id);
      if (fresh != null && mounted) {
        setState(() {
          _route = fresh;
          if (_mapDay > fresh.days) _mapDay = fresh.days;
        });
      }
    } on RouteServiceException {
      // Refresco en segundo plano: se sigue mostrando lo que ya traía la
      // tarjeta en vez de un error por algo que nadie pidió.
    }
  }

  Future<void> _edit() async {
    final saved = await pushSharedAxis<bool>(
      context,
      CreateRouteWizardScreen(initialRoute: _route),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _clone() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final copy = await RouteService().cloneRoute(_route);
      if (!mounted) return;
      AppSnackbar.showSuccess(context, '"${copy.title}" ya está en tus rutas');
      // Se abre la copia: a partir de acá la persona edita lo suyo, no el
      // itinerario de quien lo publicó.
      await pushSharedAxisReplacement(context, RouteDetailScreen(route: copy));
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _toggleStatus() async {
    final next = _route.status == RouteStatus.active
        ? RouteStatus.completed
        : RouteStatus.active;
    try {
      await RouteService().updateRoute(_route.id, status: next);
      if (!mounted) return;
      setState(() => _route = _route.copyWith(status: next));
      AppSnackbar.showSuccess(
        context,
        next == RouteStatus.completed
            ? 'Ruta marcada como completada'
            : 'Ruta reactivada',
      );
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    }
  }

  Future<void> _togglePublic() async {
    final next = !_route.isPublic;
    try {
      await RouteService().updateRoute(_route.id, isPublic: next);
      if (!mounted) return;
      setState(() => _route = _route.copyWith(isPublic: next));
      AppSnackbar.showSuccess(
        context,
        next
            ? 'Tu ruta ya es visible en la comunidad'
            : 'Tu ruta volvió a ser privada',
      );
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    }
  }

  /// Mientras se elimina: `_isBusy` bloquea Editar/Eliminar/Duplicar y
  /// `_isDeleting` pone el spinner en el botón de eliminar.
  bool _isDeleting = false;

  Future<void> _delete() async {
    if (_isBusy) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar ruta',
      message:
          '¿Seguro que quieres eliminar "${_route.title}"? Esta acción no se '
          'puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _isBusy = true;
      _isDeleting = true;
    });
    try {
      await RouteService().deleteRoute(_route.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } on Exception {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'No se pudo eliminar la ruta. Verifica tu internet e intenta de '
        'nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isDeleting = false;
        });
      }
    }
  }

  /// Abre el mapa a pantalla completa centrado en esta parada — de ahí,
  /// "Cómo llegar" es lo que realmente manda a la pestaña Mapa y arranca la
  /// previsualización de ruta.
  void _openStopOnMap(RouteStopModel stop) {
    if (!stop.hasCoordinates) {
      AppSnackbar.showError(
        context,
        'Esta parada todavía no tiene ubicación en el mapa.',
      );
      return;
    }
    pushSharedAxis(
      context,
      FullScreenMapScreen(
        title: stop.title,
        subtitle: stop.subtitle,
        latitude: stop.latitude!,
        longitude: stop.longitude!,
        locationId: 'route-stop-${stop.id ?? stop.sourceKey}',
        badge: RouteCategoryChip(category: stop.category, compact: true),
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _MenuRow(
              icon: Icons.copy_rounded,
              label: _isOwner ? 'Duplicar ruta' : 'Copiar a mis rutas',
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_clone());
              },
            ),
            if (_isOwner) ...[
              _MenuRow(
                icon: _route.status == RouteStatus.completed
                    ? Icons.restart_alt_rounded
                    : Icons.flag_rounded,
                label: _route.status == RouteStatus.completed
                    ? 'Marcar como activa'
                    : 'Marcar como completada',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_toggleStatus());
                },
              ),
              _MenuRow(
                icon: _route.isPublic
                    ? Icons.lock_outline_rounded
                    : Icons.public_rounded,
                label: _route.isPublic
                    ? 'Quitar de la comunidad'
                    : 'Publicar en la comunidad',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_togglePublic());
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _DetailHeader(
              route: route,
              onBack: () => Navigator.of(context).maybePop(),
              onMore: _showMoreMenu,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                children: [
                  if (route.sourceUrl != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openSource,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.oliveText,
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Consultar fuente del circuito'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (route.description.trim().isNotEmpty) ...[
                    Text(
                      route.description,
                      style: AppTextStyles.settingsSubtitle,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Tu recorrido',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var day = 1; day <= route.days; day++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('Día $day'),
                              selected: day == _mapDay,
                              onSelected: (_) => setState(() => _mapDay = day),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isBusy || route.stops.isEmpty
                        ? null
                        : () => pushSharedAxis(
                            context,
                            RouteTravelScreen(route: route),
                          ),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Empezar recorrido'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size.fromHeight(54),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu progreso se guardará y podrás continuar cuando quieras.',
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RouteMiniMap(
                    stops: route.stopsForDay(_mapDay),
                    interactive: true,
                    onExpand: () => pushSharedAxis(
                      context,
                      RouteOverviewScreen(
                        title: route.title,
                        stops: route.stops,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (var day = 1; day <= route.days; day++)
                    _DaySection(
                      day: day,
                      stops: route.stopsForDay(day),
                      onOpenOnMap: _openStopOnMap,
                    ),
                ],
              ),
            ),
            _DetailActions(
              isOwner: _isOwner,
              isBusy: _isBusy,
              isDeleting: _isDeleting,
              onEdit: _edit,
              onDelete: _delete,
              onClone: _clone,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.route,
    required this.onBack,
    required this.onMore,
  });

  final RouteModel route;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundButton(icon: Icons.arrow_back, onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    route.title,
                    style: AppTextStyles.detailTitle.copyWith(
                      fontSize: 23,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    route.summaryLine,
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _RoundButton(icon: Icons.more_vert, onTap: onMore),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.profileDivider,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: AppColors.settingsTextDark),
      ),
    );
  }
}

/// Un día del timeline: la burbuja numerada, la línea punteada vertical y
/// las paradas de ese día.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.stops,
    required this.onOpenOnMap,
  });

  final int day;
  final List<RouteStopModel> stops;
  final ValueChanged<RouteStopModel> onOpenOnMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$day',
                style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Día $day',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.settingsTextDark,
                fontSize: 17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: 34,
                child: CustomPaint(
                  painter: _TimelineRailPainter(),
                  size: Size.infinite,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    if (stops.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Sin paradas este día.',
                          style: AppTextStyles.settingsSubtitle.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      for (final stop in stops)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _StopTile(
                            stop: stop,
                            onOpenOnMap: () => onOpenOnMap(stop),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// La línea punteada que baja al costado de las paradas de un día.
///
/// Pintada a mano y no con una columna de trocitos: el riel vive dentro de
/// un [IntrinsicHeight], y ahí un [LayoutBuilder] (que sería la forma
/// natural de saber cuántos trocitos entran) no se puede usar — Flutter no
/// permite calcular dimensiones intrínsecas de un callback de layout.
class _TimelineRailPainter extends CustomPainter {
  const _TimelineRailPainter();

  static const _dash = 5.0;
  static const _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.profileDivider
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += _dash + _gap) {
      final end = (y + _dash).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StopTile extends StatelessWidget {
  const _StopTile({required this.stop, required this.onOpenOnMap});

  final RouteStopModel stop;
  final VoidCallback onOpenOnMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          RouteStopAvatar(stop: stop, size: 62),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RouteCategoryChip(category: stop.category, compact: true),
                const SizedBox(height: 6),
                Text(
                  stop.title,
                  style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onOpenOnMap,
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.settingsBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 19,
                color: AppColors.settingsTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El par de acciones del pie: "Editar / Eliminar" en una ruta propia,
/// "Copiar / Usar esta ruta" en la de otra persona.
class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.isOwner,
    required this.isBusy,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
    required this.onClone,
  });

  final bool isOwner;
  final bool isBusy;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: const [
              BoxShadow(
                color: AppColors.detailPrimaryButtonGlow,
                offset: Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: SizedBox(
            height: 58,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onClone,
              icon: const Icon(Icons.copy_rounded, size: 20),
              label: const Text('Copiar / Usar esta ruta'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.settingsTextDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 16),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: isBusy ? null : onEdit,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface100,
                  foregroundColor: AppColors.settingsTextDark,
                  side: const BorderSide(color: AppColors.mapControlBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 15),
                ),
                child: const Text('Editar ruta'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: isBusy ? null : onDelete,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface100,
                  foregroundColor: AppColors.wizardDangerLink,
                  side: const BorderSide(color: AppColors.wizardDangerLink),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 15),
                ),
                child: isDeleting
                    ? const AppSpinner(color: AppColors.wizardDangerLink)
                    : const Text('Eliminar ruta'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: AppColors.settingsTextDark),
      title: Text(
        label,
        style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
      ),
    );
  }
}
