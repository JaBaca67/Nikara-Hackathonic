import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/features/routes/data/route_catalog_service.dart';
import 'package:nikara_app/features/routes/data/route_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/presentation/widgets/dotted_border_box.dart';
import 'package:nikara_app/features/routes/presentation/widgets/route_card.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

const int _kMaxDays = 30;
const int _kMaxCoverPhotos = 3;

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

  int _step = 0;
  late int _days = widget.initialRoute?.days ?? 1;
  late bool _isPublic = widget.initialRoute?.isPublic ?? false;

  /// Se enciende recién al intentar continuar sin nombre — el campo no se
  /// pinta en rojo mientras la persona todavía no intentó avanzar.
  bool _titleTouched = false;

  /// Las paradas que se están armando, siempre reindexadas por día.
  late List<RouteStopModel> _stops = [...?widget.initialRoute?.stops];

  /// Fotos de portada — cada elemento es la ruta local que devuelve
  /// `image_picker` (o, al editar, la URL que ya tenía la ruta). Opcionales:
  /// sin ninguna, la tarjeta cae de vuelta a las fotos de las paradas.
  late final List<String> _coverPhotos = [...?widget.initialRoute?.imageUrls];

  List<RouteStopModel> _catalog = const [];
  bool _loadingCatalog = true;
  String? _catalogWarning;
  RouteStopCategory? _categoryFilter;

  bool _isSaving = false;

  bool get _isEditing => widget.initialRoute != null;

  bool get _titleIsValid => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final catalog = await RouteCatalogService().loadCandidates();
    if (!mounted) return;
    setState(() {
      _catalog = catalog.stops;
      _catalogWarning = catalog.warning;
      _loadingCatalog = false;
    });
  }

  /// El catálogo filtrado por el buscador y el chip de categoría del paso 2.
  List<RouteStopModel> get _visibleCandidates {
    final query = _searchController.text.trim().toLowerCase();
    return _catalog
        .where((stop) {
          if (_categoryFilter != null && stop.category != _categoryFilter) {
            return false;
          }
          if (query.isEmpty) return true;
          return stop.title.toLowerCase().contains(query) ||
              stop.subtitle.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  bool _isAdded(RouteStopModel candidate) =>
      _stops.any((s) => s.sourceKey == candidate.sourceKey);

  void _toggleCandidate(RouteStopModel candidate) {
    setState(() {
      if (_isAdded(candidate)) {
        _stops = RouteModel.reindex(
          _stops.where((s) => s.sourceKey != candidate.sourceKey).toList(),
        );
        return;
      }
      // Toda parada nueva entra al día 1; el paso 3 es donde se reparte
      // entre días.
      final day1 = _stops.where((s) => s.dayNumber == 1).length;
      _stops = RouteModel.reindex([
        ..._stops,
        candidate.copyWith(dayNumber: 1, position: day1),
      ]);
    });
  }

  void _removeStop(RouteStopModel stop) {
    setState(() {
      _stops = RouteModel.reindex(
        _stops.where((s) => s.sourceKey != stop.sourceKey).toList(),
      );
    });
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
    setState(() {
      final others = _stops
          .where((s) => s.sourceKey != stop.sourceKey)
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
    final remaining = _kMaxCoverPhotos - _coverPhotos.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    if (picked.isEmpty || !mounted) return;
    setState(
      () => _coverPhotos.addAll(picked.take(remaining).map((x) => x.path)),
    );
  }

  void _removeCoverPhoto(int index) {
    setState(() => _coverPhotos.removeAt(index));
  }

  void _changeDays(int delta) {
    final next = (_days + delta).clamp(1, _kMaxDays);
    if (next == _days) return;
    setState(() {
      _days = next;
      // Al acortar la ruta, las paradas de los días que dejaron de existir
      // se recuestan en el último día en vez de perderse.
      _stops = RouteModel.reindex([
        for (final stop in _stops)
          stop.dayNumber > next ? stop.copyWith(dayNumber: next) : stop,
      ]);
    });
  }

  void _continue() {
    if (_step == 0) {
      setState(() => _titleTouched = true);
      if (!_titleIsValid) return;
    }
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    unawaited(_save());
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step--);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final initial = widget.initialRoute;
      if (initial == null) {
        await RouteService().createRoute(
          title: _titleController.text.trim(),
          days: _days,
          isPublic: _isPublic,
          stops: _stops,
          imageUrls: _coverPhotos,
        );
      } else {
        await RouteService().updateRoute(
          initial.id,
          title: _titleController.text.trim(),
          days: _days,
          isPublic: _isPublic,
          imageUrls: _coverPhotos,
        );
        await RouteService().replaceStops(initial.id, _stops);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Ruta actualizada' : '¡Ruta guardada!'),
        ),
      );
      Navigator.of(context).pop(true);
    } on RouteServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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

  bool get _primaryEnabled => switch (_step) {
    0 => _titleIsValid,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: Column(
          children: [
            _WizardHeader(
              title: _isEditing ? 'Editar ruta' : 'Nueva ruta',
              subtitle: 'Paso ${_step + 1} de 3 · ${_stepSubtitles[_step]}',
              onBack: _back,
              onExit: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _StepIndicator(current: _step, labels: _steps),
            ),
            Expanded(
              child: switch (_step) {
                0 => _StepName(
                  controller: _titleController,
                  showError: _titleTouched && !_titleIsValid,
                  days: _days,
                  isPublic: _isPublic,
                  coverPhotos: _coverPhotos,
                  onDaysChanged: _changeDays,
                  onPublicChanged: (value) => setState(() => _isPublic = value),
                  onTitleChanged: () => setState(() {}),
                  onPickCoverPhoto: _pickCoverPhotos,
                  onRemoveCoverPhoto: _removeCoverPhoto,
                ),
                1 => _StepPlaces(
                  searchController: _searchController,
                  candidates: _visibleCandidates,
                  isLoading: _loadingCatalog,
                  warning: _catalogWarning,
                  selectedCategory: _categoryFilter,
                  onCategorySelected: (category) =>
                      setState(() => _categoryFilter = category),
                  onSearchChanged: () => setState(() {}),
                  isAdded: _isAdded,
                  onToggle: _toggleCandidate,
                ),
                _ => _StepOrganize(
                  days: _days,
                  stops: _stops,
                  onMove: _moveStop,
                  onRemove: _removeStop,
                  onAddMore: () => setState(() => _step = 1),
                ),
              },
            ),
            _WizardFooter(
              label: _primaryLabel,
              enabled: _primaryEnabled,
              isBusy: _isSaving,
              onPressed: _continue,
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onExit,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.profileDivider,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.settingsTextDark,
              ),
            ),
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
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onExit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Salir',
                style: AppTextStyles.mapRowTitle.copyWith(fontSize: 13),
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(20),
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
            ? AppColors.ecoActive
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
          style: AppTextStyles.wizardStepHeading.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 6),
        Text(
          'Elegí un nombre y cuántos días va a durar.',
          style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface100,
            borderRadius: BorderRadius.circular(20),
            border: showError
                ? Border.all(color: AppColors.wizardDangerLink)
                : null,
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
                style: AppTextStyles.settingsSubtitle.copyWith(
                  fontSize: 15,
                  color: AppColors.settingsTextDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Ej. Fin de semana en Granada',
                  hintStyle: AppTextStyles.settingsSubtitle.copyWith(
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppColors.settingsBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: showError
                          ? AppColors.wizardDangerLink
                          : AppColors.mapControlBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: showError
                          ? AppColors.wizardDangerLink
                          : AppColors.primary500,
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
                        color: AppColors.wizardDangerLink,
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
                        'Ponele un nombre a tu ruta para continuar',
                        style: AppTextStyles.mapRowTitle.copyWith(
                          fontSize: 13,
                          color: AppColors.wizardDangerLink,
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
        borderRadius: BorderRadius.circular(20),
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
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
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
      child: GestureDetector(
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
        borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(20),
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
    required this.searchController,
    required this.candidates,
    required this.isLoading,
    required this.warning,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.isAdded,
    required this.onToggle,
  });

  final TextEditingController searchController;
  final List<RouteStopModel> candidates;
  final bool isLoading;
  final String? warning;
  final RouteStopCategory? selectedCategory;
  final ValueChanged<RouteStopCategory?> onCategorySelected;
  final VoidCallback onSearchChanged;
  final bool Function(RouteStopModel) isAdded;
  final ValueChanged<RouteStopModel> onToggle;

  @override
  Widget build(BuildContext context) {
    final warning = this.warning;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface100,
            borderRadius: BorderRadius.circular(20),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _CategoryFilterChip(
                label: 'Todos',
                selected: selectedCategory == null,
                onTap: () => onCategorySelected(null),
              ),
              for (final category in RouteStopCategory.values)
                _CategoryFilterChip(
                  label: category.label,
                  selected: selectedCategory == category,
                  onTap: () => onCategorySelected(category),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (warning != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.complementario1,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.settingsDanger,
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
          ),
          const SizedBox(height: 16),
        ],
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary500),
            ),
          )
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
              padding: const EdgeInsets.only(bottom: 12),
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
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary500 : AppColors.surface100,
            borderRadius: BorderRadius.circular(999),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: added ? AppColors.detailActivityIconBg : AppColors.primary500,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (added) ...[
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.ecoActive,
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
                      ? AppColors.ecoActive
                      : AppColors.settingsTextDark,
                ),
              ),
            ),
          ],
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
  });

  final int days;
  final List<RouteStopModel> stops;
  final void Function(RouteStopModel stop, {required bool up}) onMove;
  final ValueChanged<RouteStopModel> onRemove;
  final VoidCallback onAddMore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      children: [
        for (var day = 1; day <= days; day++) ...[
          _DayHeader(day: day),
          const SizedBox(height: 12),
          ...() {
            final dayStops = stops
                .where((s) => s.dayNumber == day)
                .toList(growable: false);
            if (dayStops.isEmpty) {
              return [_EmptyDaySlot(onAddMore: onAddMore)];
            }
            return [
              for (final stop in dayStops)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrganizeRow(
                    stop: stop,
                    canMoveUp: !(day == 1 && stop == dayStops.first),
                    canMoveDown: !(day == days && stop == dayStops.last),
                    onMove: onMove,
                    onRemove: () => onRemove(stop),
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
                color: AppColors.ecoActive,
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
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMove,
    required this.onRemove,
  });

  final RouteStopModel stop;
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.drag_indicator_rounded,
            size: 20,
            color: AppColors.neutral400,
          ),
          const SizedBox(width: 6),
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
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.neutral400,
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
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.3,
        child: Icon(icon, size: 22, color: AppColors.settingsTextMuted),
      ),
    );
  }
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.label,
    required this.enabled,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: SizedBox(
        height: 58,
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled && !isBusy ? onPressed : null,
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
          child: isBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.settingsTextDark,
                  ),
                )
              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
