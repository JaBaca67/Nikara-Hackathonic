import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_form_fields.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/map_location_picker.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Formulario "Registrar actividad"; al guardar refresca el feed ECO vía
/// `EcoService.revision`, mismo patrón que `BusinessStorageService.revision`.
///
/// Comparte estructura visual con `RegisterBusinessWizard` (tarjetas blancas
/// sobre crema, labels en mayúsculas, mapa con pin fijo al centro), pero en una
/// sola pantalla scrolleable: una jornada tiene un tercio de los campos de un
/// negocio, así que partirla en pasos solo agregaría fricción.
class CreateEcoActivityScreen extends StatefulWidget {
  const CreateEcoActivityScreen({super.key, this.existingActivity});

  /// Null = registrar una jornada nueva. Con valor, el mismo formulario edita
  /// esa jornada: se precargan todos los campos y "Publicar" pasa a "Guardar
  /// cambios". Mismo patrón que `RegisterBusinessWizard.existingBusiness`.
  final EcoActivityModel? existingActivity;

  @override
  State<CreateEcoActivityScreen> createState() =>
      _CreateEcoActivityScreenState();
}

class _CreateEcoActivityScreenState extends State<CreateEcoActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _requirementController = TextEditingController();

  String _category = kEcoCategories.first;
  DateTime? _date;
  TimeOfDay? _time;
  final List<String> _requirements = [];

  /// Portada única: la misma imagen que verán la tarjeta del feed, la tarjeta
  /// hero y el detalle. Se sube a Storage recién al publicar, no al elegirla,
  /// para no dejar archivos huérfanos si el usuario abandona el formulario.
  XFile? _coverImage;

  /// Editando: portada ya guardada en Storage. Se muestra hasta que el usuario
  /// elija otra ([_coverImage]) o la quite ([_removeExistingImage]).
  String? _existingImageUrl;
  bool _removeExistingImage = false;

  GoogleMapController? _mapController;
  LatLng _mapCenter = kNikaraMapCenter;

  /// El punto que realmente se guarda. Null hasta que el usuario presiona
  /// "Confirmar esta ubicación": arrastrar el mapa sin confirmar no debe
  /// cambiar las coordenadas de la jornada por accidente.
  LatLng? _confirmedLocation;
  bool _locatingUser = false;

  bool _isSaving = false;

  bool get _isEditing => widget.existingActivity != null;

  /// [_selectedOrganization] null = "Mi perfil personal" (default siempre); publicar como fundación es decisión explícita.
  List<OrganizationModel> _organizations = const [];
  OrganizationModel? _selectedOrganization;
  String _personalName = 'Mi perfil personal';

  @override
  void initState() {
    super.initState();
    _prefillFromExisting();
    unawaited(_loadPublishAsOptions());
  }

  void _prefillFromExisting() {
    final activity = widget.existingActivity;
    if (activity == null) return;
    _titleController.text = activity.title;
    _descriptionController.text = activity.description;
    _locationController.text = activity.location;
    _capacityController.text = activity.maxCapacity?.toString() ?? '';
    _requirements.addAll(activity.requirements);
    _existingImageUrl = activity.imageUrl;
    // La categoría guardada puede no estar en kEcoCategories (texto libre en
    // la tabla, ver EcoActivityModel): se respeta la del feed en ese caso.
    _category = activity.category;
    final start = activity.startTime.toLocal();
    _date = DateTime(start.year, start.month, start.day);
    _time = TimeOfDay(hour: start.hour, minute: start.minute);
    if (activity.hasCoordinates) {
      final point = LatLng(activity.latitude!, activity.longitude!);
      _mapCenter = point;
      _confirmedLocation = point;
    }
  }

  Future<void> _loadPublishAsOptions() async {
    try {
      final organizations = await OrganizationService().getMyOrganizations();
      final profile = await AuthService().getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _organizations = organizations;
        final name = profile?.fullName.trim() ?? '';
        if (name.isNotEmpty) _personalName = name;
        // Editando: se marca la fundación con la que ya está publicada. Si esa
        // fundación ya no es suya, queda en "a título personal" y guardar la
        // desvincula, que es el único resultado honesto posible.
        final existingOrganizationId = widget.existingActivity?.organizationId;
        if (existingOrganizationId != null) {
          for (final organization in organizations) {
            if (organization.id == existingOrganizationId) {
              _selectedOrganization = organization;
              break;
            }
          }
        }
      });
    } on OrganizationServiceException {
      // Sin fundaciones el formulario sigue funcionando, publicando a título personal.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _requirementController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  DateTime? get _startTime {
    final date = _date;
    final time = _time;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _date;
    // Editando una jornada que ya pasó, `now` como firstDate dejaría la fecha
    // guardada fuera del rango y el picker se abriría en otra distinta.
    final firstDate = current != null && current.isBefore(now) ? current : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  // ==================== Portada ====================

  Future<void> _pickCoverImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.ecoActive,
              ),
              title: Text(
                'Elegir de la galería',
                style: AppTextStyles.settingsRowTitle,
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.ecoActive,
              ),
              title: Text(
                'Tomar una foto',
                style: AppTextStyles.settingsRowTitle,
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    // maxWidth + imageQuality mantienen la subida bajo el límite de 5 MB del
    // bucket (ver supabase/sql/014_eco_activity_image.sql).
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _coverImage = picked;
      _removeExistingImage = false;
    });
  }

  void _clearCoverImage() {
    setState(() {
      _coverImage = null;
      // Solo cuenta como "quitar" si había una portada guardada; descartar una
      // recién elegida no debe borrar la que ya estaba en Storage.
      if (_existingImageUrl != null) _removeExistingImage = true;
    });
  }

  // ==================== Ubicación ====================

  Future<void> _useCurrentLocation() async {
    setState(() => _locatingUser = true);
    try {
      final position = await LocationService().getCurrentPosition(
        forceRefresh: true,
      );
      if (!mounted) return;
      if (position == null) {
        _snack(
          'No se pudo obtener tu ubicación actual. Ubica la jornada tocando '
          'el mapa.',
        );
        return;
      }
      // Solo mueve la cámara: el punto guardado sigue siendo el que el usuario
      // confirme, así el GPS es un atajo y no la única fuente posible.
      final here = LatLng(position.latitude, position.longitude);
      setState(() => _mapCenter = here);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(here, 15));
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  void _confirmLocation() {
    setState(() => _confirmedLocation = _mapCenter);
    _snack('Ubicación confirmada en el mapa.');
  }

  void _zoomMap(double delta) {
    _mapController?.animateCamera(
      delta > 0 ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
    );
  }

  // ==================== Requisitos ====================

  void _addRequirement() {
    final text = _requirementController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _requirements.add(text);
      _requirementController.clear();
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final startTime = _startTime;
    if (startTime == null) {
      _snack('Elige la fecha y hora de la actividad.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // La imagen se sube antes del insert/update: si Storage falla, no queda
      // una jornada guardada sin la portada que el usuario eligió.
      final cover = _coverImage;
      final imageUrl = cover == null
          ? null
          : await EcoService().uploadActivityImage(cover);

      final location = _confirmedLocation;
      final existing = widget.existingActivity;
      if (existing == null) {
        await EcoService().createActivity(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          location: _locationController.text.trim(),
          latitude: location?.latitude,
          longitude: location?.longitude,
          imageUrl: imageUrl,
          startTime: startTime,
          maxCapacity: int.tryParse(_capacityController.text.trim()),
          requirements: _requirements,
          organizationId: _selectedOrganization?.id,
        );
      } else {
        await EcoService().updateActivity(
          id: existing.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          location: _locationController.text.trim(),
          latitude: location?.latitude,
          longitude: location?.longitude,
          imageUrl: imageUrl,
          removeImage: _removeExistingImage && imageUrl == null,
          startTime: startTime,
          maxCapacity: int.tryParse(_capacityController.text.trim()),
          requirements: _requirements,
          organizationId: _selectedOrganization?.id,
          // Quitó la fundación (o ya no la administra): hay que escribir null
          // explícitamente, si no el update dejaría el vínculo anterior.
          clearOrganization:
              _selectedOrganization == null && existing.isFromOrganization,
        );
      }
      if (!mounted) return;
      final organization = _selectedOrganization;
      if (existing != null) {
        _snack('Cambios guardados.');
      } else {
        _snack(
          organization == null
              ? '¡Actividad registrada!'
              : '¡Actividad publicada como ${organization.name}!',
        );
      }
      Navigator.of(context).pop(true);
    } on EcoServiceException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              EcoFormHeader(
                title: _isEditing
                    ? 'Editar actividad ECO'
                    : 'Registrar actividad ECO',
                subtitle: _isEditing
                    ? 'Actualiza los datos de tu jornada'
                    : 'Organiza una jornada ambiental',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoverSection(),
                      _buildDetailsSection(),
                      _buildLocationSection(),
                      _buildScheduleSection(),
                      _buildRequirementsSection(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Ruta o URL que se está mostrando como portada: la foto recién elegida
  /// gana sobre la ya guardada, y nada si se pidió quitarla.
  String? get _coverPreviewPath {
    final picked = _coverImage;
    if (picked != null) return picked.path;
    if (_removeExistingImage) return null;
    return _existingImageUrl;
  }

  String get _coverHint {
    if (_coverImage != null) {
      return _isEditing
          ? 'Reemplazará la portada actual al guardar.'
          : 'Se subirá al publicar la jornada. Horizontal se ve mejor.';
    }
    if (_coverPreviewPath != null) {
      return 'Portada actual. Toca el ícono de recargar para cambiarla.';
    }
    return 'Opcional. Sin portada se muestra el ícono de la categoría.';
  }

  Widget _buildCoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EcoSectionIntro(
          title: 'Portada de la jornada',
          subtitle:
              'Es la imagen que se ve en el feed ECO, en el mapa y en el '
              'detalle.',
        ),
        EcoFormCard(
          children: [
            const EcoFieldLabel('Imagen principal'),
            _CoverPicker(
              previewPath: _coverPreviewPath,
              onPick: _pickCoverImage,
              onRemove: _clearCoverImage,
            ),
            const SizedBox(height: 10),
            _HintRow(icon: Icons.info_outline, text: _coverHint),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EcoSectionIntro(
          title: 'Sobre la jornada',
          subtitle: 'Qué se va a hacer, quién la organiza y por qué importa.',
        ),
        EcoFormCard(
          children: [
            if (_organizations.isNotEmpty) ...[
              const EcoFieldLabel('Publicar como'),
              _PublishAsPicker(
                organizations: _organizations,
                personalName: _personalName,
                selected: _selectedOrganization,
                onChanged: (organization) =>
                    setState(() => _selectedOrganization = organization),
              ),
              const SizedBox(height: 18),
            ],
            const EcoFieldLabel('Título'),
            EcoTextField(
              controller: _titleController,
              hint: 'Ej. Reforestación Lago Cocibolca',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título.' : null,
            ),
            const SizedBox(height: 18),
            const EcoFieldLabel('Categoría'),
            _CategoryPicker(
              selected: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 8),
            _HintRow(
              icon: Icons.filter_alt_outlined,
              text:
                  'Define el ícono de la jornada y el filtro donde aparece en '
                  'el feed ECO.',
            ),
            const SizedBox(height: 18),
            const EcoFieldLabel('Descripción'),
            EcoTextField(
              controller: _descriptionController,
              hint: 'Describe la jornada, qué se va a hacer y por qué importa.',
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe una descripción.'
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    final confirmed = _confirmedLocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EcoSectionIntro(
          title: '¿Dónde es?',
          subtitle: 'Marca el punto exacto de encuentro en el mapa.',
        ),
        EcoFormCard(
          children: [
            const EcoFieldLabel('Referencia'),
            EcoTextField(
              controller: _locationController,
              hint: 'Ej. Cerro Apante, Managua',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe una ubicación.'
                  : null,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Punto en el mapa',
                    style: AppTextStyles.wizardCardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _locatingUser ? null : _useCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.settingsBackground,
                      border: Border.all(color: AppColors.mapControlBorder),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_locatingUser)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.my_location,
                            size: 14,
                            color: AppColors.settingsTextDark,
                          ),
                        const SizedBox(width: 5),
                        Text(
                          'Usar mi ubicación',
                          style: AppTextStyles.detailPillAction,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MapLocationPicker(
              initialCenter: _mapCenter,
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: (center) => _mapCenter = center,
              onTap: (point) =>
                  _mapController?.animateCamera(CameraUpdate.newLatLng(point)),
              onZoomIn: () => _zoomMap(1),
              onZoomOut: () => _zoomMap(-1),
            ),
            const SizedBox(height: 10),
            _HintRow(
              icon: Icons.touch_app,
              iconColor: AppColors.accent300,
              text:
                  'Arrastra el mapa o toca cualquier punto para dejar el pin '
                  'sobre el lugar de encuentro.',
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _confirmLocation,
              child: Container(
                width: double.infinity,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.settingsBackground,
                  border: Border.all(
                    color: AppColors.primary500.withValues(alpha: 0.45),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.push_pin,
                      size: 17,
                      color: AppColors.wizardAmber,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Confirmar esta ubicación',
                        style: AppTextStyles.detailBottomBarSecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (confirmed != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.detailActivityIconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.ecoActive,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Punto guardado: '
                        '${confirmed.latitude.toStringAsFixed(5)}, '
                        '${confirmed.longitude.toStringAsFixed(5)}',
                        style: AppTextStyles.wizardCaption.copyWith(
                          color: AppColors.settingsTextDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EcoSectionIntro(
          title: 'Cuándo y cuántos',
          subtitle: 'La fecha define si la jornada aparece como próxima.',
        ),
        EcoFormCard(
          children: [
            const EcoFieldLabel('Fecha y hora'),
            Row(
              children: [
                Expanded(
                  child: EcoPickerButton(
                    icon: Icons.calendar_today_rounded,
                    isSet: _date != null,
                    label: _date == null
                        ? 'Elegir fecha'
                        : '${_date!.day}/${_date!.month}/${_date!.year}',
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EcoPickerButton(
                    icon: Icons.access_time_rounded,
                    isSet: _time != null,
                    label: _time == null
                        ? 'Elegir hora'
                        : _time!.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const EcoFieldLabel('Cupo límite (opcional)'),
            EcoTextField(
              controller: _capacityController,
              hint: 'Ej. 25',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const _HintRow(
              icon: Icons.groups_outlined,
              text: 'Déjalo vacío si no hay límite de participantes.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EcoSectionIntro(
          title: 'Qué llevar',
          subtitle: 'Aparece como checklist en el detalle de la jornada.',
        ),
        EcoFormCard(
          children: [
            const EcoFieldLabel('Requisitos'),
            Row(
              children: [
                Expanded(
                  child: EcoTextField(
                    controller: _requirementController,
                    hint: 'Ej. Botas cerradas',
                    onSubmitted: (_) => _addRequirement(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addRequirement,
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    foregroundColor: AppColors.settingsTextDark,
                  ),
                ),
              ],
            ),
            if (_requirements.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final requirement in _requirements)
                    Chip(
                      label: Text(
                        requirement,
                        style: AppTextStyles.wizardChipLabel.copyWith(
                          color: AppColors.detailBodyBrown,
                        ),
                      ),
                      onDeleted: () =>
                          setState(() => _requirements.remove(requirement)),
                      deleteIconColor: AppColors.settingsTextMuted,
                      backgroundColor: AppColors.settingsBackground,
                      side: const BorderSide(color: AppColors.mapControlBorder),
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface100,
        boxShadow: [
          BoxShadow(
            color: AppColors.detailBottomBarShadow,
            offset: Offset(0, -2),
            blurRadius: 14,
          ),
        ],
      ),
      child: EcoPrimaryButton(
        label: _isEditing ? 'Guardar cambios' : 'Publicar actividad',
        isBusy: _isSaving,
        onPressed: _save,
      ),
    );
  }
}

/// Zona de subida de la portada: mismo tratamiento que la "FOTO DE PORTADA"
/// del wizard de negocios, pero de una sola imagen.
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.previewPath,
    required this.onPick,
    required this.onRemove,
  });

  /// Ruta local de `image_picker` o URL http(s) de Storage — [LocalImage]
  /// distingue una de otra sola.
  final String? previewPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final picked = previewPath;
    if (picked == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 158,
          decoration: BoxDecoration(
            color: AppColors.wizardUploadZoneBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary500.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_a_photo,
                  color: AppColors.settingsTextDark,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Subir imagen de portada',
                style: AppTextStyles.wizardCardTitle,
              ),
              const SizedBox(height: 2),
              Text(
                'Una sola foto, horizontal',
                style: AppTextStyles.wizardCaption,
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 158,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LocalImage(path: picked),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  _CoverAction(icon: Icons.autorenew_rounded, onTap: onPick),
                  const SizedBox(width: 8),
                  _CoverAction(icon: Icons.delete_outline, onTap: onRemove),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverAction extends StatelessWidget {
  const _CoverAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.detailCoverCounterBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: AppColors.surface100),
      ),
    );
  }
}

/// Línea de ayuda bajo un campo (ícono + texto), el equivalente ECO de los
/// captions del wizard.
class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 14,
            color: iconColor ?? AppColors.settingsTextMuted,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: AppTextStyles.wizardCaption)),
      ],
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // `selected` va en el set porque `eco_activities.category` es texto
        // libre: editando una jornada sembrada ("Reforestación y Restauración
        // de Ecosistemas Degradados") su categoría no está en kEcoCategories, y
        // sin esto no habría ninguna pastilla marcada.
        for (final category in {...kEcoCategories, selected})
          GestureDetector(
            onTap: () => onChanged(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: category == selected
                    ? AppColors.ecoActive
                    : AppColors.settingsBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: category == selected
                      ? AppColors.ecoActive
                      : AppColors.settingsTextDark.withValues(alpha: 0.07),
                ),
              ),
              child: Text(
                category,
                style: AppTextStyles.wizardChipLabel.copyWith(
                  color: category == selected
                      ? AppColors.surface100
                      : AppColors.detailBodyBrown,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pastillas en vez de `SegmentedButton`/`DropdownButton` porque cada opción lleva avatar y nombre completo, y hereda el estilo de los chips de categoría.
class _PublishAsPicker extends StatelessWidget {
  const _PublishAsPicker({
    required this.organizations,
    required this.personalName,
    required this.selected,
    required this.onChanged,
  });

  final List<OrganizationModel> organizations;
  final String personalName;
  final OrganizationModel? selected;
  final ValueChanged<OrganizationModel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PublishAsOption(
          label: personalName,
          caption: 'A título personal',
          selected: selected == null,
          onTap: () => onChanged(null),
          avatar: const _PublishAsAvatar(icon: Icons.person_rounded),
        ),
        for (final organization in organizations) ...[
          const SizedBox(height: 8),
          _PublishAsOption(
            label: organization.name,
            caption: organization.handleTag,
            selected: selected?.id == organization.id,
            onTap: () => onChanged(organization),
            verified: organization.isVerified,
            avatar: _PublishAsAvatar(
              icon: Icons.eco_rounded,
              imagePath: organization.logoUrl,
            ),
          ),
        ],
      ],
    );
  }
}

class _PublishAsOption extends StatelessWidget {
  const _PublishAsOption({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
    required this.avatar,
    this.verified = false,
  });

  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;
  final Widget avatar;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.detailActivityIconBg
              : AppColors.settingsBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.ecoActive
                : AppColors.settingsTextDark.withValues(alpha: 0.07),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            avatar,
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
                          label,
                          style: AppTextStyles.wizardCardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: AppColors.ecoActive,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: AppTextStyles.wizardCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.ecoActive : AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishAsAvatar extends StatelessWidget {
  const _PublishAsAvatar({required this.icon, this.imagePath});

  final IconData icon;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 40,
        height: 40,
        child: path == null || path.isEmpty
            ? Container(
                color: AppColors.detailActivityIconBg,
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.ecoActive),
              )
            : LocalImage(path: path, fallbackIcon: icon),
      ),
    );
  }
}
