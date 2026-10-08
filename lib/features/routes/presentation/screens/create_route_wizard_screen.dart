import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_stop_location_screen.dart';

import 'package:nikara_app/core/utils/validators.dart';
import 'package:nikara_app/core/models/geographic_destination.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/routes/data/route_catalog_service.dart';
import 'package:nikara_app/features/routes/data/route_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/domain/route_planner.dart';
import 'package:nikara_app/features/routes/presentation/screens/route_overview_screen.dart';
import 'package:nikara_app/features/routes/presentation/widgets/dotted_border_box.dart';
import 'package:nikara_app/features/routes/presentation/widgets/route_card.dart';
import 'package:nikara_app/shared/widgets/app_confirm_dialog.dart';
import 'package:nikara_app/shared/widgets/geographic_filter_bar.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

const int _kMaxDays = 30;
const int _kMaxCoverPhotos = 3;
const int _kMaxTitleLength = 60;

/// Lado mínimo de cualquier zona tocable (Material/WCAG: 48dp).
const double _kMinTouchTarget = 48;

/// Wizard de 3 pasos para armar (o editar) una ruta: nombre y duración,
/// lugares, y organización por día.
///
/// Con [initialRoute] entra en modo edición: precarga la ruta, y al guardar
/// actualiza la cabecera y reemplaza sus paradas en vez de crear una nueva.
class CreateRouteWizardScreen extends StatefulWidget {
  const CreateRouteWizardScreen({super.key, this.initialRoute});

  final RouteModel? initialRoute;

  @override
  State<CreateRouteWizardScreen> createState() =>
      _CreateRouteWizardScreenState();
}

class _CreateRouteWizardScreenState extends State<CreateRouteWizardScreen> {
  static const _steps = ['Nombre', 'Lugares', 'Organizar'];
  static const _stepSubtitles = [
    'Nombre y duración',
    'Agregar lugares',
    'Organizar por día',
  ];

  late final TextEditingController _titleController = TextEditingController(
    text: widget.initialRoute?.title ?? '',
  );
  final _searchController = TextEditingController();
  late final _descriptionController = TextEditingController(
    text: widget.initialRoute?.description ?? '',
  );

  int _step = 0;
  int _addingDay = 1;
  late int _days = widget.initialRoute?.days ?? 1;
  late bool _isPublic = widget.initialRoute?.isPublic ?? false;

  /// Se enciende recién al intentar continuar sin nombre — el campo no se
  /// pinta en rojo mientras la persona todavía no intentó avanzar.
  bool _titleTouched = false;

  /// Las paradas que se están armando, siempre reindexadas por día.
  late List<RouteStopModel> _stops = [...?widget.initialRoute?.stops];

  /// Fotos de portada ya subidas — al editar, las URLs que ya tenía la ruta.
  /// Se suben nuevas recién al guardar (ver [_newCoverPhotos]), no al
  /// elegirlas, para no dejar archivos huérfanos si se abandona el
  /// formulario. Opcionales: sin ninguna, la tarjeta cae de vuelta a las
  /// fotos de las paradas.
  late final List<String> _coverPhotoUrls = [
    ...?widget.initialRoute?.imageUrls,
  ];

  /// Fotos recién elegidas en este formulario, todavía sin subir a Storage.
  final List<XFile> _newCoverPhotos = [];

  /// Lo que se muestra en la grilla: las ya subidas primero, luego las
  /// recién elegidas (mostrando su ruta local hasta que se suban).
  List<String> get _coverPreviewPaths => [
    ..._coverPhotoUrls,
    ..._newCoverPhotos.map((x) => x.path),
  ];

  List<RouteStopModel> _catalog = const [];
  bool _loadingCatalog = true;
  String? _catalogWarning;
  String? _categoryFilter;
  GeographicDestination _destinationFilter = const GeographicDestination();

  bool _isSaving = false;

  bool get _isEditing => widget.initialRoute != null;

  /// Mínimo 3 caracteres y al menos una letra (las reglas de `validateTitle`,
  /// que el resto de la app comparte) y máximo [_kMaxTitleLength]: el campo ya
  /// no deja escribir más, pero un texto pegado se recorta y se revalida aquí.
  /// Se muestra un único mensaje concreto para esta pantalla.
  bool get _titleIsValid {
    final title = _titleController.text;
    return validateTitle(title) == null &&
        title.trim().length <= _kMaxTitleLength;
  }

  /// Evita abrir dos selectores de galería con toques seguidos.
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// También es el "Reintentar" del aviso del paso 2: vuelve a pedir las tres
  /// fuentes, no solo la que falló.
  Future<void> _loadCatalog() async {
    if (!_loadingCatalog) setState(() => _loadingCatalog = true);
    try {
      final catalog = await RouteCatalogService().loadCandidates();
      if (!mounted) return;
      setState(() {
        _catalog = catalog.stops;
        _catalogWarning = catalog.warning;
        _loadingCatalog = false;
      });
    } on Exception {
      // `loadCandidates` ya absorbe los fallos de cada fuente; esto cubre lo
      // inesperado (p. ej. la ubicación) para que el paso 2 nunca quede
      // girando para siempre.
      if (!mounted) return;
      setState(() {
        _catalogWarning = 'No se pudieron cargar los lugares.';
        _loadingCatalog = false;
      });
    }
  }

  /// El catálogo filtrado por el buscador y el chip de categoría del paso 2.
  List<RouteStopModel> get _visibleCandidates {
    final query = RoutePlanner.searchKey(_searchController.text);
    return _catalog
        .where((stop) {
          final category = _categoryFilter;
          if (category == 'Jornadas ECO') {
            if (stop.kind != RouteStopKind.ecoActivity) return false;
          } else if (category != null) {
            if (stop.kind != RouteStopKind.business ||
                businessCategoryPresetFor(stop.businessCategory ?? '') !=
                    category) {
              return false;
            }
          }
          if (!_destinationFilter.matches(
            municipalityByCode(stop.municipalityCode),
          )) {
            return false;
          }
          if (query.isEmpty) return true;
          return RoutePlanner.searchKey(stop.title).contains(query) ||
              RoutePlanner.searchKey(stop.subtitle).contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _pickCatalogDestination() async {
    final selection = await showGeographicDestinationPicker(
      context,
      initial: _destinationFilter,
    );
    if (selection == null || !mounted) return;
    setState(() => _destinationFilter = selection.destination);
  }

  bool _isAdded(RouteStopModel candidate) => _stops.any(
    (s) => s.sourceKey == candidate.sourceKey && s.dayNumber == _addingDay,
  );

  void _toggleCandidate(RouteStopModel candidate) {
    setState(() {
      if (_isAdded(candidate)) {
        _stops = RouteModel.reindex(
          _stops
              .where(
                (s) =>
                    s.sourceKey != candidate.sourceKey ||
                    s.dayNumber != _addingDay,
              )
              .toList(),
        );
        return;
      }
      // Each selection belongs to the chosen day; a place can be revisited.
      final dayPosition = _stops.where((s) => s.dayNumber == _addingDay).length;
      _stops = RouteModel.reindex([
        ..._stops,
        candidate.copyWith(dayNumber: _addingDay, position: dayPosition),
      ]);
    });
  }

  void _removeStop(RouteStopModel stop) {
    setState(() {
      _stops = RouteModel.reindex(
        _stops.where((s) => s.visitKey != stop.visitKey).toList(),
      );
    });
  }

  Future<void> _locateStop(RouteStopModel stop) async {
    final point = await pushSharedAxis<LatLng>(
      context,
      RouteStopLocationScreen(title: stop.title),
    );
    if (point == null || !mounted) return;
    setState(
      () => _stops = [
        for (final current in _stops)
          current.visitKey == stop.visitKey
              ? current.copyWith(
                  latitude: point.latitude,
                  longitude: point.longitude,
                )
              : current,
      ],
    );
  }

  /// Mueve una parada un lugar arriba o abajo dentro de su día; en los
  /// bordes salta al día anterior/siguiente, que es como el paso 3 reparte
  /// el itinerario sin necesitar drag & drop.
  void _moveStop(RouteStopModel stop, {required bool up}) {
    final sameDay = _stops
        .where((s) => s.dayNumber == stop.dayNumber)
        .toList(growable: false);
    final index = sameDay.indexWhere((s) => s.sourceKey == stop.sourceKey);
    final targetDay = stop.dayNumber + (up ? -1 : 1);

    if (up && index == 0) {
      if (stop.dayNumber == 1) return;
      _reassign(
        stop,
        day: targetDay,
        position: _stops.where((s) => s.dayNumber == targetDay).length,
      );
      return;
    }
    if (!up && index == sameDay.length - 1) {
      if (stop.dayNumber >= _days) return;
      _reassign(stop, day: targetDay, position: -1);
      return;
    }
    // Medio punto por delante de la parada con la que se intercambia: al
    // subir cae justo antes de la anterior, y al bajar justo después de la
    // siguiente. Con `index ± 0.5` el movimiento hacia abajo no cambiaba
    // nada, porque quedaba en su propio hueco.
    _reassign(
      stop,
      day: stop.dayNumber,
      position: up ? index - 1.5 : index + 1.5,
    );
  }

  /// Reubica [stop] en [day] con un orden intermedio ([position] puede ser
  /// fraccionario para colarse entre dos paradas) y renumera todo.
  void _reassign(
    RouteStopModel stop, {
    required int day,
    required num position,
  }) {
    if (_stops.any(
      (s) =>
          s.sourceKey == stop.sourceKey &&
          s.dayNumber == day &&
          s.visitKey != stop.visitKey,
    )) {
      AppSnackbar.showInfo(context, 'Este lugar ya está en ese día.');
      return;
    }
    setState(() {
      final others = _stops
          .where((s) => s.visitKey != stop.visitKey)
          .toList(growable: false);
      final rebuilt = <RouteStopModel>[];
      for (final other in others) {
        rebuilt.add(
          other.copyWith(
            position: other.dayNumber == day && other.position >= position
                ? other.position + 1
                : other.position,
          ),
        );
      }
      rebuilt.add(
        stop.copyWith(
          dayNumber: day,
          position: position < 0 ? 0 : position.ceil(),
        ),
      );
      _stops = RouteModel.reindex(rebuilt);
    });
  }

  Future<void> _pickCoverPhotos() async {
    final remaining = _kMaxCoverPhotos - _coverPreviewPaths.length;
    if (remaining <= 0 || _pickingPhoto) return;
    _pickingPhoto = true;
    try {
      final picked = await ImagePicker().pickMultiImage(limit: remaining);
      if (picked.isEmpty || !mounted) return;
      setState(() => _newCoverPhotos.addAll(picked.take(remaining)));
    } on Exception {
      // Permiso de galería denegado o el selector del sistema falló.
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'No se pudo abrir tu galería. Revisa los permisos de la app e '
        'intenta de nuevo.',
      );
    } finally {
      _pickingPhoto = false;
    }
  }

  /// [index] cae sobre la lista combinada de [_coverPreviewPaths]: primero
  /// las ya subidas, luego las nuevas.
  void _removeCoverPhoto(int index) {
    setState(() {
      if (index < _coverPhotoUrls.length) {
        _coverPhotoUrls.removeAt(index);
      } else {
        _newCoverPhotos.removeAt(index - _coverPhotoUrls.length);
      }
    });
  }

  void _changeDays(int delta) {
    final next = (_days + delta).clamp(1, _kMaxDays);
    if (next == _days) return;
    setState(() {
      _days = next;
      if (_addingDay > next) _addingDay = next;
      // Al acortar la ruta, las paradas de los días que dejaron de existir
      // se recuestan en el último día en vez de perderse.
      _stops = RouteModel.reindex([
        for (final stop in _stops)
          stop.dayNumber > next ? stop.copyWith(dayNumber: next) : stop,
      ]);
    });
  }

  /// El botón principal nunca está deshabilitado: si falta algo, dice qué.
  Future<void> _continue() async {
    if (_step == 0) {
      setState(() => _titleTouched = true);
      if (!_titleIsValid) return;
    }
    if (_step == 1 && _stops.isEmpty) {
      AppSnackbar.showError(
        context,
        'Agrega al menos un lugar a tu ruta para continuar.',
      );
      return;
    }
    if (_step < 2) {
      _goToStep(_step + 1);
      return;
    }
    await _save();
  }

  // Moving between steps keeps the draft, including assignments and order.
  void _goToStep(int next) => setState(() => _step = next);
  bool _dialogOpen = false;

  /// Pregunta y devuelve `true` solo si se confirmó. Un cierre de cualquier
  /// otra forma (atrás del sistema sobre la alerta) deja a la persona donde
  /// está.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = true,
  }) async {
    _dialogOpen = true;
    try {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      );
      return confirmed && mounted;
    } finally {
      _dialogOpen = false;
    }
  }

  /// Salida real a Rutas: `pop()` explícito (el `PopScope` no lo bloquea) y
  /// solo después de una confirmación.
  void _leave() => Navigator.of(context).pop();

  /// Flecha de la cabecera y atrás del sistema. En el paso 1 no hay a dónde
  /// retroceder, así que sale (con confirmación); en los pasos 2 y 3
  /// retrocede un paso — directo si no se cambió nada, con confirmación si
  /// se perdería algo.
  Future<void> _onBack() async {
    if (_isSaving || _dialogOpen) return;
    if (_step == 0) {
      final exit = await _confirm(
        title: '¿Salir sin guardar?',
        message: 'Perderás el progreso de tu ruta.',
        confirmLabel: 'Salir',
        cancelLabel: 'Continuar',
      );
      if (exit) _leave();
      return;
    }
    _goBackOneStep();
  }

  /// La X de los pasos 2 y 3: siempre pregunta, haya cambios o no.
  Future<void> _onExit() async {
    if (_isSaving || _dialogOpen) return;
    final exit = await _confirm(
      title: '¿Salir de crear ruta?',
      message: 'Perderás todo el progreso de tu ruta y volverás a Rutas.',
      confirmLabel: 'Salir',
      cancelLabel: 'Continuar',
    );
    if (exit) _leave();
  }

  void _goBackOneStep() => setState(() => _step--);

  Future<void> _save() async {
    if (_isSaving) return;
    // En el paso 3 todavía se pueden quitar paradas: una ruta sin ninguna no
    // se guarda (los días vacíos sueltos sí, ver `_EmptyDaysNotice`).
    if (_stops.isEmpty) {
      AppSnackbar.showError(
        context,
        'Tu ruta necesita al menos un lugar. Agrega uno para guardarla.',
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      // Las fotos nuevas suben antes del insert/update: si Storage falla, no
      // queda una ruta guardada apuntando a una imagen que nunca se subió.
      final uploadedUrls = [
        for (final image in _newCoverPhotos)
          await RouteService().uploadImage(image),
      ];
      final imageUrls = [..._coverPhotoUrls, ...uploadedUrls];

      final initial = widget.initialRoute;
      if (initial == null) {
        await RouteService().createRoute(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          days: _days,
          isPublic: _isPublic,
          stops: _stops,
          imageUrls: imageUrls,
        );
      } else {
        await RouteService().updateRoute(
          initial.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          days: _days,
          isPublic: _isPublic,
          imageUrls: imageUrls,
        );
        await RouteService().replaceStops(initial.id, _stops);
      }
      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        _isEditing ? 'Ruta actualizada' : '¡Ruta guardada!',
      );
      Navigator.of(context).pop(true);
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } on Exception {
      // El servicio traduce lo suyo; esto cubre lo que escape de él (p. ej.
      // leer el archivo de una foto) para no dejar la pantalla sin respuesta.
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'No se pudo guardar tu ruta. Verifica tu internet e intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _primaryLabel => switch (_step) {
    0 => 'Continuar',
    1 =>
      _stops.isEmpty ? 'Continuar' : 'Continuar · ${_stops.length} agregados',
    _ => _isEditing ? 'Guardar cambios' : 'Guardar ruta',
  };

  @override
  Widget build(BuildContext context) {
    // `canPop: false`: el atrás del sistema hace lo mismo que la flecha de la
    // cabecera (`_onBack`); la salida real a Rutas es el `Navigator.pop()`
    // explícito de `_leave`, que PopScope no bloquea.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _WizardHeader(
                title: _isEditing ? 'Editar ruta' : 'Nueva ruta',
                subtitle: 'Paso ${_step + 1} de 3 · ${_stepSubtitles[_step]}',
                onBack: () => unawaited(_onBack()),
                backLabel: _step == 0
                    ? 'Salir de crear ruta'
                    : 'Volver al paso anterior',
                enabled: !_isSaving,
                onExit: _step == 0 ? null : () => unawaited(_onExit()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _StepIndicator(current: _step, labels: _steps),
              ),
              Expanded(
                child: switch (_step) {
                  0 => _StepName(
                    controller: _titleController,
                    descriptionController: _descriptionController,
                    showError: _titleTouched && !_titleIsValid,
                    days: _days,
                    isPublic: _isPublic,
                    coverPhotos: _coverPreviewPaths,
                    onDaysChanged: _changeDays,
                    onPublicChanged: (value) =>
                        setState(() => _isPublic = value),
                    onTitleChanged: () => setState(() {}),
                    onPickCoverPhoto: _pickCoverPhotos,
                    onRemoveCoverPhoto: _removeCoverPhoto,
                  ),
                  1 => _StepPlaces(
                    days: _days,
                    addingDay: _addingDay,
                    selectedCount: _stops.length,
                    onAddingDayChanged: (day) =>
                        setState(() => _addingDay = day),
                    searchController: _searchController,
                    candidates: _visibleCandidates,
                    isLoading: _loadingCatalog,
                    warning: _catalogWarning,
                    selectedCategory: _categoryFilter,
                    onCategorySelected: (category) =>
                        setState(() => _categoryFilter = category),
                    destination: _destinationFilter,
                    onDestinationFilterChanged: (destination) =>
                        setState(() => _destinationFilter = destination),
                    onPickDestination: _pickCatalogDestination,
                    onSearchChanged: () => setState(() {}),
                    isAdded: _isAdded,
                    onToggle: _toggleCandidate,
                    onRetry: () => unawaited(_loadCatalog()),
                  ),
                  _ => _StepOrganize(
                    days: _days,
                    stops: _stops,
                    onMove: _moveStop,
                    onRemove: _removeStop,
                    onLocate: _locateStop,
                    onAddMore: (day) {
                      _addingDay = day;
                      _goToStep(1);
                    },
                    onAssignDay: (stop, day) => _reassign(
                      stop,
                      day: day,
                      position: _stops.where((s) => s.dayNumber == day).length,
                    ),
                    onSuggestOrder: (day) => setState(
                      () => _stops = RoutePlanner.suggestOrder(_stops, day),
                    ),
                    onPreview: () => pushSharedAxis(
                      context,
                      RouteOverviewScreen(
                        title: _titleController.text.trim(),
                        stops: _stops,
                      ),
                    ),
                  ),
                },
              ),
              _WizardFooter(
                label: _primaryLabel,
                isBusy: _isSaving,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera del wizard: flecha de la izquierda y, desde el paso 2, una X para
/// salir. Son dos acciones distintas (retroceder un paso / abandonar), cada
/// la salida pide confirmar antes de descartar el borrador.
class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.backLabel,
    required this.enabled,
    this.onExit,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  /// Qué hace la flecha en este paso: en el primero sale del wizard, en los
  /// demás vuelve al paso anterior.
  final String backLabel;

  /// Falso mientras se guarda: los botones se ven atenuados y no responden.
  final bool enabled;

  /// `null` en el paso 1, donde la flecha ya es la salida.
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.arrow_back,
            label: backLabel,
            enabled: enabled,
            onTap: onBack,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.wizardAppBarTitle.copyWith(fontSize: 21),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onExit != null) ...[
            const SizedBox(width: 10),
            _HeaderIconButton(
              icon: Icons.close_rounded,
              label: 'Salir de crear ruta',
              enabled: enabled,
              onTap: onExit!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Botón circular de la cabecera: círculo de 44 dentro de una zona tocable de
/// 48, con tooltip (long-press / hover) y etiqueta para lectores de pantalla.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox.square(
            dimension: _kMinTouchTarget,
            child: Center(
              child: Opacity(
                opacity: enabled ? 1 : 0.4,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.profileDivider,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: AppColors.settingsTextDark,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicador 1-2-3: el paso actual en dorado, los ya hechos en olivo con
/// check, los que faltan con el aro punteado en crema.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.labels});

  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i != 0)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: AppColors.profileDivider,
                    ),
                  ),
                _StepBubble(index: i, current: current),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: i == 0
                        ? TextAlign.start
                        : (i == labels.length - 1
                              ? TextAlign.end
                              : TextAlign.center),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.mapRowTitle.copyWith(
                      fontSize: 12,
                      color: i == current
                          ? AppColors.settingsTextDark
                          : AppColors.settingsTextMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBubble extends StatelessWidget {
  const _StepBubble({required this.index, required this.current});

  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final isDone = index < current;
    final isCurrent = index == current;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.oliveText
            : (isCurrent ? AppColors.primary500 : AppColors.surface100),
        shape: BoxShape.circle,
        border: isDone || isCurrent
            ? null
            : Border.all(color: AppColors.wizardStepInactiveBorder),
      ),
      child: isDone
          ? const Icon(
              Icons.check_rounded,
              size: 20,
              color: AppColors.surface100,
            )
          : Text(
              '${index + 1}',
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 15,
                color: isCurrent
                    ? AppColors.settingsTextDark
                    : AppColors.settingsTextMuted,
              ),
            ),
    );
  }
}

/// Paso 1 — nombre, contador de días y el switch de publicación.
class _StepName extends StatelessWidget {
  const _StepName({
    required this.controller,
    required this.descriptionController,
    required this.showError,
    required this.days,
    required this.isPublic,
    required this.coverPhotos,
    required this.onDaysChanged,
    required this.onPublicChanged,
    required this.onTitleChanged,
    required this.onPickCoverPhoto,
    required this.onRemoveCoverPhoto,
  });

  final TextEditingController controller;
  final TextEditingController descriptionController;
  final bool showError;
  final int days;
  final bool isPublic;
  final List<String> coverPhotos;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<bool> onPublicChanged;
  final VoidCallback onTitleChanged;
  final VoidCallback onPickCoverPhoto;
  final ValueChanged<int> onRemoveCoverPhoto;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      children: [
        Text(
          '¿Cómo se llama tu ruta?',
          style: AppTextStyles.wizardStepHeading.copyWith(
            fontSize: 22,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Diseña tu viaje por días, elige tus paradas y recórrelas a tu ritmo.',
          style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface100,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: showError ? Border.all(color: AppColors.error) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'NOMBRE DE LA RUTA',
                style: AppTextStyles.settingsSectionLabel,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                onChanged: (_) => onTitleChanged(),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_kMaxTitleLength),
                ],
                style: AppTextStyles.settingsSubtitle.copyWith(
                  fontSize: 15,
                  color: AppColors.settingsTextDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Ej. Fin de semana en Granada',
                  helperText: 'Un nombre para encontrar tu viaje fácilmente',
                  hintStyle: AppTextStyles.settingsSubtitle.copyWith(
                    fontSize: 15,
                    color: AppColors.settingsTextMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.settingsBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: showError
                          ? AppColors.error
                          : AppColors.mapControlBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: showError ? AppColors.error : AppColors.primary500,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (showError) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        size: 12,
                        color: AppColors.surface100,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ponle un nombre a tu ruta (mínimo 3 letras).',
                        style: AppTextStyles.mapRowTitle.copyWith(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text('DURACIÓN', style: AppTextStyles.settingsSectionLabel),
              const SizedBox(height: 10),
              _DayStepper(days: days, onChanged: onDaysChanged),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface100,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DESCRIPCIÓN BREVE',
                style: AppTextStyles.settingsSectionLabel,
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('route-description'),
                controller: descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: RouteModel.maxDescriptionLength,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.settingsSubtitle.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '¿Qué descubrirán quienes recorran esta ruta?',
                  helperText: 'Opcional · Se mostrará junto a tu ruta',
                  helperMaxLines: 2,
                  filled: true,
                  fillColor: AppColors.settingsBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.mapControlBorder,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CoverPhotosCard(
          photos: coverPhotos,
          onPick: onPickCoverPhoto,
          onRemove: onRemoveCoverPhoto,
        ),
        const SizedBox(height: 16),
        _PublishToggle(value: isPublic, onChanged: onPublicChanged),
      ],
    );
  }
}

/// Fotos de portada de la ruta — hasta [_kMaxCoverPhotos]. Ninguna es
/// obligatoria: sin fotos propias, `RouteModel.coverImages` cae de vuelta a
/// las de las paradas agregadas, así que el aviso es una sugerencia, no un
/// error de validación.
class _CoverPhotosCard extends StatelessWidget {
  const _CoverPhotosCard({
    required this.photos,
    required this.onPick,
    required this.onRemove,
  });

  final List<String> photos;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FOTOS DE PORTADA', style: AppTextStyles.settingsSectionLabel),
          const SizedBox(height: 4),
          Text(
            'Opcional — hasta $_kMaxCoverPhotos. Sin fotos propias usamos '
            'las de los lugares que agregues.',
            style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < photos.length; i++) ...[
                if (i != 0) const SizedBox(width: 10),
                Expanded(
                  child: _CoverPhotoTile(
                    path: photos[i],
                    onRemove: () => onRemove(i),
                  ),
                ),
              ],
              if (photos.length < _kMaxCoverPhotos) ...[
                if (photos.isNotEmpty) const SizedBox(width: 10),
                Expanded(child: _AddCoverPhotoTile(onTap: onPick)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverPhotoTile extends StatelessWidget {
  const _CoverPhotoTile({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.expand(
              child: LocalImage(
                path: path,
                fallbackIcon: Icons.photo_outlined,
                fallbackIconSize: 0,
              ),
            ),
          ),
          // Zona tocable de 48dp aunque el círculo visible siga siendo de
          // ~20: cabe dentro de la foto (las miniaturas miden ~90).
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              button: true,
              label: 'Quitar foto',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox.square(
                  dimension: _kMinTouchTarget,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.removeButtonBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.surface100,
                        ),
                      ),
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

class _AddCoverPhotoTile extends StatelessWidget {
  const _AddCoverPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Semantics(
        button: true,
        label: 'Agregar foto de portada',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.settingsBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.mapControlBorder),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 24,
              color: AppColors.settingsTextMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayStepper extends StatelessWidget {
  const _DayStepper({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            enabled: days > 1,
            filled: false,
            onTap: () => onChanged(-1),
          ),
          Expanded(
            child: Text(
              '$days ${days == 1 ? 'día' : 'días'}',
              textAlign: TextAlign.center,
              style: AppTextStyles.mapRowTitle.copyWith(fontSize: 16),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            enabled: days < _kMaxDays,
            filled: true,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary500 : AppColors.surface100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: AppColors.settingsTextDark),
        ),
      ),
    );
  }
}

class _PublishToggle extends StatelessWidget {
  const _PublishToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Publicar en la comunidad',
                  style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  'Otras personas van a poder verla y copiarla.',
                  style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.surface100,
            activeTrackColor: AppColors.primary500,
          ),
        ],
      ),
    );
  }
}

/// Paso 2 — buscador, chips de categoría y el listado de lugares con su
/// botón "Agregar a ruta" / "✔ Agregado".
class _StepPlaces extends StatelessWidget {
  const _StepPlaces({
    required this.days,
    required this.addingDay,
    required this.selectedCount,
    required this.onAddingDayChanged,
    required this.searchController,
    required this.candidates,
    required this.isLoading,
    required this.warning,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.destination,
    required this.onDestinationFilterChanged,
    required this.onPickDestination,
    required this.onSearchChanged,
    required this.isAdded,
    required this.onToggle,
    required this.onRetry,
  });

  final VoidCallback onRetry;
  final int days;
  final int addingDay;
  final int selectedCount;
  final ValueChanged<int> onAddingDayChanged;
  final TextEditingController searchController;
  final List<RouteStopModel> candidates;
  final bool isLoading;
  final String? warning;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final GeographicDestination destination;
  final ValueChanged<GeographicDestination> onDestinationFilterChanged;
  final VoidCallback onPickDestination;
  final VoidCallback onSearchChanged;
  final bool Function(RouteStopModel) isAdded;
  final ValueChanged<RouteStopModel> onToggle;

  @override
  Widget build(BuildContext context) {
    final warning = this.warning;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Text(
          'Elige tus paradas',
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$selectedCount lugares seleccionados. Agrega cada lugar al día en que quieres visitarlo.',
          style: AppTextStyles.settingsSubtitle,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var day = 1; day <= days; day++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Día $day'),
                    selected: addingDay == day,
                    onSelected: (_) => onAddingDayChanged(day),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface100,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 22,
                color: AppColors.settingsTextMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  style: AppTextStyles.settingsSubtitle.copyWith(
                    fontSize: 15,
                    color: AppColors.settingsTextDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar lugares o actividades...',
                    hintStyle: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Filtrar por departamento o municipio',
                onPressed: onPickDestination,
                icon: Icon(
                  Icons.tune_rounded,
                  color: destination.isActive
                      ? AppColors.oliveText
                      : AppColors.settingsTextDark,
                ),
              ),
            ],
          ),
        ),
        if (destination.isActive) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              avatar: const Icon(Icons.place_rounded, size: 16),
              label: Text(destination.label),
              onDeleted: () =>
                  onDestinationFilterChanged(const GeographicDestination()),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: _kMinTouchTarget,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _CategoryFilterChip(
                label: 'Todos',
                selected: selectedCategory == null,
                onTap: () => onCategorySelected(null),
              ),
              _CategoryFilterChip(
                label: 'Jornadas ECO',
                selected: selectedCategory == 'Jornadas ECO',
                onTap: () => onCategorySelected('Jornadas ECO'),
              ),
              for (final category in kBusinessCategoryPresets)
                _CategoryFilterChip(
                  label: category,
                  selected: selectedCategory == category,
                  onTap: () => onCategorySelected(category),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (warning != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.coralPaleFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.destructive,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        warning,
                        style: AppTextStyles.settingsSubtitle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : onRetry,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        _kMinTouchTarget,
                        _kMinTouchTarget,
                      ),
                      foregroundColor: AppColors.oliveText,
                    ),
                    child: Text('Reintentar', style: AppTextStyles.buttonMd),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (isLoading)
          const AppSectionLoader(message: 'Cargando lugares…')
        else if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No encontramos lugares con ese filtro.',
              textAlign: TextAlign.center,
              style: AppTextStyles.settingsSubtitle,
            ),
          )
        else
          for (final candidate in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _CandidateRow(
                stop: candidate,
                added: isAdded(candidate),
                onToggle: () => onToggle(candidate),
              ),
            ),
      ],
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      // Zona tocable de 48dp con el píldora visible de 40.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: AppMotion.respect(context, AppMotion.microDuration),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary500 : AppColors.surface100,
              borderRadius: BorderRadius.circular(AppRadius.pill),
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
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.stop,
    required this.added,
    required this.onToggle,
  });

  final RouteStopModel stop;
  final bool added;
  final VoidCallback onToggle;

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
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 68,
              height: 68,
              child: LocalImage(
                path: stop.imagePath,
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
                RouteCategoryChip(category: stop.category, compact: true),
                if (!stop.hasCoordinates)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Sin ubicación para navegar',
                      style: AppTextStyles.settingsSubtitle.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  stop.title,
                  style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stop.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    stop.subtitle,
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _AddToRouteButton(added: added, onTap: onToggle),
        ],
      ),
    );
  }
}

class _AddToRouteButton extends StatelessWidget {
  const _AddToRouteButton({required this.added, required this.onTap});

  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 148),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: added ? AppColors.detailActivityIconBg : AppColors.primary500,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: SizedBox(
          height: _kMinTouchTarget,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (added) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.oliveText,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  added ? 'Agregado' : 'Agregar a ruta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mapRowTitle.copyWith(
                    fontSize: 13,
                    color: added
                        ? AppColors.oliveText
                        : AppColors.settingsTextDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paso 3 — las paradas agrupadas por día, con los controles para moverlas
/// entre posiciones y días.
class _StepOrganize extends StatelessWidget {
  const _StepOrganize({
    required this.days,
    required this.stops,
    required this.onMove,
    required this.onRemove,
    required this.onAddMore,
    required this.onAssignDay,
    required this.onSuggestOrder,
    required this.onPreview,
    required this.onLocate,
  });

  final int days;
  final List<RouteStopModel> stops;
  final void Function(RouteStopModel stop, {required bool up}) onMove;
  final ValueChanged<RouteStopModel> onRemove;
  final ValueChanged<int> onAddMore;
  final void Function(RouteStopModel, int) onAssignDay;
  final ValueChanged<int> onSuggestOrder;
  final VoidCallback onPreview;
  final ValueChanged<RouteStopModel> onLocate;

  @override
  Widget build(BuildContext context) {
    final emptyDays = [
      for (var day = 1; day <= days; day++)
        if (!stops.any((s) => s.dayNumber == day)) day,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Text(
          'Revisa tu recorrido',
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${stops.length} paradas · ${stops.where((s) => s.hasCoordinates).length} con ubicación. '
          'Ordena cada día y deja espacio para visitas y descansos.',
          style: AppTextStyles.settingsSubtitle,
        ),
        TextButton.icon(
          onPressed: onPreview,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Revisar mapa por día'),
        ),
        const SizedBox(height: 12),
        // Solo advierte: una ruta con días vacíos se puede guardar igual.
        if (emptyDays.isNotEmpty) ...[
          _EmptyDaysNotice(emptyDays: emptyDays),
          const SizedBox(height: 18),
        ],
        for (var day = 1; day <= days; day++) ...[
          _DayHeader(day: day),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => onAddMore(day),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar lugares'),
              ),
              if (stops
                      .where((s) => s.dayNumber == day && s.hasCoordinates)
                      .length >
                  2)
                TextButton.icon(
                  onPressed: () => onSuggestOrder(day),
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: const Text('Ordenar por cercanía'),
                ),
            ],
          ),
          if (stops
                  .where((s) => s.dayNumber == day && s.hasCoordinates)
                  .length >
              2)
            Text(
              'Mantiene la primera parada. Es una sugerencia geográfica; revisa horarios y accesos.',
              style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
            ),
          const SizedBox(height: 12),
          ...() {
            final dayStops = stops
                .where((s) => s.dayNumber == day)
                .toList(growable: false);
            if (dayStops.isEmpty) {
              return [_EmptyDaySlot(onAddMore: () => onAddMore(day))];
            }
            return [
              for (final stop in dayStops)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrganizeRow(
                    stop: stop,
                    days: days,
                    onAssignDay: (day) => onAssignDay(stop, day),
                    canMoveUp: !(day == 1 && stop == dayStops.first),
                    canMoveDown: !(day == days && stop == dayStops.last),
                    onMove: onMove,
                    onRemove: () => onRemove(stop),
                    onLocate: () => onLocate(stop),
                  ),
                ),
            ];
          }(),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

/// Aviso informativo (no bloquea) de los días que quedaron sin paradas.
class _EmptyDaysNotice extends StatelessWidget {
  const _EmptyDaysNotice({required this.emptyDays});

  final List<int> emptyDays;

  String get _message {
    if (emptyDays.length == 1) {
      return 'El día ${emptyDays.first} no tiene paradas. '
          'Puedes guardar la ruta así o agregar lugares.';
    }
    final head = emptyDays.sublist(0, emptyDays.length - 1).join(', ');
    return 'Los días $head y ${emptyDays.last} no tienen paradas. '
        'Puedes guardar la ruta así o agregar lugares.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_rounded,
            size: 24,
            color: AppColors.oliveText,
            semanticLabel: 'Aviso',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _message,
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _EmptyDaySlot extends StatelessWidget {
  const _EmptyDaySlot({required this.onAddMore});

  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddMore,
      child: DottedBorderBox(
        child: Column(
          children: [
            Text(
              'Todavía no hay paradas este día',
              style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              '+ Agregar parada',
              style: AppTextStyles.mapRowTitle.copyWith(
                fontSize: 13,
                color: AppColors.oliveText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizeRow extends StatelessWidget {
  const _OrganizeRow({
    required this.stop,
    required this.days,
    required this.onAssignDay,
    required this.onLocate,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onRemove,
  });

  final RouteStopModel stop;
  final int days;
  final ValueChanged<int> onAssignDay;
  final VoidCallback onLocate;
  final bool canMoveUp;
  final bool canMoveDown;
  final void Function(RouteStopModel stop, {required bool up}) onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 56,
              height: 56,
              child: LocalImage(
                path: stop.imagePath,
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
                  stop.title,
                  style: AppTextStyles.mapRowTitle.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                RouteCategoryChip(category: stop.category, compact: true),
                if (!stop.hasCoordinates)
                  TextButton.icon(
                    onPressed: onLocate,
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('Ubicar en mapa'),
                  ),
                if (days > 1)
                  DropdownButton<int>(
                    value: stop.dayNumber,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var day = 1; day <= days; day++)
                        DropdownMenuItem(value: day, child: Text('Día $day')),
                    ],
                    onChanged: (day) {
                      if (day != null && day != stop.dayNumber) {
                        onAssignDay(day);
                      }
                    },
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MoveButton(
                icon: Icons.keyboard_arrow_up_rounded,
                enabled: canMoveUp,
                onTap: () => onMove(stop, up: true),
              ),
              _MoveButton(
                icon: Icons.keyboard_arrow_down_rounded,
                enabled: canMoveDown,
                onTap: () => onMove(stop, up: false),
              ),
            ],
          ),
          IconButton(
            onPressed: onRemove,
            constraints: const BoxConstraints.tightFor(
              width: _kMinTouchTarget,
              height: _kMinTouchTarget,
            ),
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.settingsTextMuted,
            ),
            tooltip: 'Quitar de la ruta',
          ),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: icon == Icons.keyboard_arrow_up_rounded
          ? 'Subir parada'
          : 'Bajar parada',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox.square(
          dimension: _kMinTouchTarget,
          child: Opacity(
            opacity: enabled ? 1 : 0.3,
            child: Icon(icon, size: 24, color: AppColors.settingsTextMuted),
          ),
        ),
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: SizedBox(
        height: 58,
        width: double.infinity,
        // `AppLoadingButton` ya se protege solo del doble toque mientras el
        // `Future` de `onPressed` no termina (y `isBusy` cubre el guardado
        // disparado desde otro lado).
        child: AppLoadingButton(
          label: label,
          isLoading: isBusy,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
