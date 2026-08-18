import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/routes/data/route_catalog_service.dart';
import 'package:nikara_app/features/routes/data/route_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/presentation/screens/create_route_wizard_screen.dart';
import 'package:nikara_app/features/routes/presentation/widgets/dotted_border_box.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Selector "Agregar a ruta" — asocia un negocio o una jornada ECO a una
/// ruta activa que ya existe, o abre el wizard para crear una nueva.
///
/// Se abre con [showForBusiness] / [showForEcoActivity], que son las que
/// convierten el negocio o la actividad en una [RouteStopModel]; la hoja en
/// sí ya no distingue de dónde salió la parada.
class AddToRouteBottomSheet extends StatefulWidget {
  const AddToRouteBottomSheet._({required this.stop});

  final RouteStopModel stop;

  /// Abre el selector para un negocio. Devuelve `true` si la parada quedó
  /// agregada a alguna ruta.
  static Future<bool> showForBusiness(
    BuildContext context,
    BusinessModel business,
  ) {
    return _show(context, RouteCatalogService.stopFromBusiness(business));
  }

  /// Abre el selector para una jornada ECO.
  static Future<bool> showForEcoActivity(
    BuildContext context,
    EcoActivityModel activity,
  ) {
    return _show(context, RouteCatalogService.stopFromEcoActivity(activity));
  }

  static Future<bool> _show(BuildContext context, RouteStopModel stop) async {
    // Una ruta necesita `owner_id`: un invitado no tiene dónde guardarla.
    if (!await GuestGuard.allow(context, GuestFeature.rutas)) return false;
    if (!context.mounted) return false;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => AddToRouteBottomSheet._(stop: stop),
    );
    return added ?? false;
  }

  @override
  State<AddToRouteBottomSheet> createState() => _AddToRouteBottomSheetState();
}

class _AddToRouteBottomSheetState extends State<AddToRouteBottomSheet> {
  List<RouteModel> _routes = const [];
  String? _selectedRouteId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final routes = await RouteService().getMyRoutes();
      if (!mounted) return;
      setState(() {
        // Solo rutas activas: agregar una parada a un viaje que ya se dio
        // por terminado no tiene sentido.
        _routes = routes
            .where((r) => r.status == RouteStatus.active)
            .toList(growable: false);
        _selectedRouteId = _routes.isEmpty ? null : _routes.first.id;
        _isLoading = false;
      });
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewRoute() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateRouteWizardScreen()),
    );
    if (created == true && mounted) {
      setState(() => _isLoading = true);
      await _load();
    }
  }

  Future<void> _add() async {
    final routeId = _selectedRouteId;
    if (routeId == null) return;
    setState(() => _isSaving = true);
    try {
      await RouteService().addStop(routeId, widget.stop);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Agregado a tu ruta')));
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.profileDivider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Agregar a ruta',
              style: AppTextStyles.detailTitle.copyWith(fontSize: 21),
            ),
            const SizedBox(height: 4),
            Text(
              'Elegí una ruta existente o creá una nueva.',
              style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary500),
                ),
              )
            else ...[
              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppTextStyles.mapRowCaption.copyWith(
                    color: AppColors.settingsDanger,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final route in _routes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RouteOption(
                          route: route,
                          selected: route.id == _selectedRouteId,
                          onTap: () =>
                              setState(() => _selectedRouteId = route.id),
                        ),
                      ),
                    _CreateNewRouteOption(onTap: _createNewRoute),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _selectedRouteId == null || _isSaving
                      ? null
                      : _add,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: AppColors.settingsTextDark,
                    disabledBackgroundColor: AppColors.segmentedTrackBg,
                    disabledForegroundColor: AppColors.settingsTextMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.settingsTextDark,
                          ),
                        )
                      : const Text('Agregar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final RouteModel route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = route.coverImages(max: 1);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.warmChipBackground
              : AppColors.settingsBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary500 : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: LocalImage(
                  path: cover.isEmpty ? null : cover.first,
                  fallbackIcon: Icons.photo_outlined,
                  fallbackIconSize: 0,
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
                    route.title,
                    style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    route.summaryLine,
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary500 : Colors.transparent,
                shape: BoxShape.circle,
                border: selected
                    ? null
                    : Border.all(color: AppColors.neutral400, width: 1.5),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: AppColors.settingsTextDark,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateNewRouteOption extends StatelessWidget {
  const _CreateNewRouteOption({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.settingsBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 22,
                color: AppColors.settingsTextDark,
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                'Crear una ruta nueva',
                style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
