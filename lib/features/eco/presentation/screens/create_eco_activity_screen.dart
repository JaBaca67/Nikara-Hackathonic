import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/data/organization_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/widgets/eco_form_fields.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// "Registrar actividad" form, reachable from Perfil/Ajustes — collects
/// everything [EcoService.createActivity] needs (título, categoría,
/// descripción, ubicación, fecha/hora, cupo, requisitos) and refreshes the
/// ECO feed on save via `EcoService.revision` (EcoMainScreen already
/// listens to it, same pattern `BusinessStorageService.revision` uses for
/// "Registra tu negocio").
class CreateEcoActivityScreen extends StatefulWidget {
  const CreateEcoActivityScreen({super.key});

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
  double? _latitude;
  double? _longitude;
  bool _locatingUser = false;
  final List<String> _requirements = [];

  bool _isSaving = false;

  /// "Publicar como": las fundaciones de esta cuenta y cuál está elegida.
  /// [_selectedOrganization] en null significa "Mi perfil personal", que es
  /// como arranca siempre — publicar en nombre de una fundación es una
  /// decisión explícita, nunca el default.
  List<OrganizationModel> _organizations = const [];
  OrganizationModel? _selectedOrganization;
  String _personalName = 'Mi perfil personal';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPublishAsOptions());
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
      });
    } on OrganizationServiceException {
      // Sin fundaciones que ofrecer el formulario funciona igual, publicando
      // a título personal — no vale la pena interrumpir con un error.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _requirementController.dispose();
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
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

  Future<void> _useCurrentLocation() async {
    setState(() => _locatingUser = true);
    try {
      final position = await LocationService().getCurrentPosition(
        forceRefresh: true,
      );
      if (!mounted) return;
      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener tu ubicación actual.'),
          ),
        );
        return;
      }
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  void _addRequirement() {
    final text = _requirementController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _requirements.add(text);
      _requirementController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final startTime = _startTime;
    if (startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige la fecha y hora de la actividad.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await EcoService().createActivity(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        location: _locationController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        startTime: startTime,
        maxCapacity: int.tryParse(_capacityController.text.trim()),
        requirements: _requirements,
        organizationId: _selectedOrganization?.id,
      );
      if (!mounted) return;
      final organization = _selectedOrganization;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            organization == null
                ? '¡Actividad registrada!'
                : '¡Actividad publicada como ${organization.name}!',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on EcoServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundCream,
        elevation: 0,
        title: Text(
          'Registrar actividad ECO',
          style: AppTextStyles.sectionTitle.copyWith(fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
              const SizedBox(height: 20),
            ],
            const EcoFieldLabel('Título'),
            EcoTextField(
              controller: _titleController,
              hint: 'Ej. Reforestación Lago Cocibolca',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título.' : null,
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Categoría'),
            _CategoryPicker(
              selected: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Descripción'),
            EcoTextField(
              controller: _descriptionController,
              hint: 'Describe la jornada, qué se va a hacer y por qué importa.',
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe una descripción.'
                  : null,
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Ubicación'),
            EcoTextField(
              controller: _locationController,
              hint: 'Ej. Cerro Apante, Managua',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe una ubicación.'
                  : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _locatingUser ? null : _useCurrentLocation,
              icon: _locatingUser
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _latitude != null
                          ? Icons.check_circle
                          : Icons.my_location,
                      size: 16,
                      color: _latitude != null ? AppColors.ecoActive : null,
                    ),
              label: Text(
                _latitude != null
                    ? 'Coordenadas capturadas'
                    : 'Usar mi ubicación actual',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.settingsTextDark,
                side: const BorderSide(color: AppColors.mapControlBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Fecha y hora'),
            Row(
              children: [
                Expanded(
                  child: EcoPickerButton(
                    icon: Icons.calendar_today_rounded,
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
                    label: _time == null
                        ? 'Elegir hora'
                        : _time!.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const EcoFieldLabel('Cupo límite (opcional)'),
            EcoTextField(
              controller: _capacityController,
              hint: 'Ej. 25',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final requirement in _requirements)
                    Chip(
                      label: Text(requirement),
                      onDeleted: () =>
                          setState(() => _requirements.remove(requirement)),
                      backgroundColor: AppColors.settingsBackground,
                      side: const BorderSide(color: AppColors.mapControlBorder),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            EcoPrimaryButton(
              label: 'Publicar actividad',
              isBusy: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
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
        for (final category in kEcoCategories)
          GestureDetector(
            onTap: () => onChanged(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: category == selected
                    ? AppColors.ecoActive
                    : AppColors.surface100,
                borderRadius: BorderRadius.circular(999),
                border: category == selected
                    ? null
                    : Border.all(color: AppColors.mapControlBorder),
              ),
              child: Text(
                category,
                style: AppTextStyles.mapRowTitle.copyWith(
                  fontSize: 12,
                  color: category == selected
                      ? AppColors.surface100
                      : AppColors.settingsTextMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Selector "Publicar como" — la primera decisión del formulario cuando la
/// cuenta tiene fundaciones registradas: la jornada sale a nombre de la
/// persona (opción por defecto, `organization_id` nulo) o de una de sus
/// fundaciones.
///
/// Es un segmentado de pastillas y no un `SegmentedButton`/`DropdownButton`
/// de Material porque cada opción lleva su avatar y su nombre completo, y
/// porque así hereda el mismo lenguaje visual de los chips de categoría de
/// esta misma pantalla.
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
              : AppColors.surface100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.ecoActive : AppColors.mapControlBorder,
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
                          style: AppTextStyles.mapRowTitle.copyWith(
                            fontSize: 13,
                            color: AppColors.settingsTextDark,
                          ),
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
                    style: AppTextStyles.settingsSubtitle.copyWith(
                      fontSize: 11.5,
                    ),
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
