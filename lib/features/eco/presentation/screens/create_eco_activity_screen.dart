import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
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
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Actividad registrada!')));
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
            _FieldLabel('Título'),
            _NikaraTextField(
              controller: _titleController,
              hint: 'Ej. Reforestación Lago Cocibolca',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un título.' : null,
            ),
            const SizedBox(height: 16),
            _FieldLabel('Categoría'),
            _CategoryPicker(
              selected: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Descripción'),
            _NikaraTextField(
              controller: _descriptionController,
              hint: 'Describe la jornada, qué se va a hacer y por qué importa.',
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escribe una descripción.'
                  : null,
            ),
            const SizedBox(height: 16),
            _FieldLabel('Ubicación'),
            _NikaraTextField(
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
            _FieldLabel('Fecha y hora'),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.calendar_today_rounded,
                    label: _date == null
                        ? 'Elegir fecha'
                        : '${_date!.day}/${_date!.month}/${_date!.year}',
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerButton(
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
            _FieldLabel('Cupo límite (opcional)'),
            _NikaraTextField(
              controller: _capacityController,
              hint: 'Ej. 25',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _FieldLabel('Requisitos'),
            Row(
              children: [
                Expanded(
                  child: _NikaraTextField(
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
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.settingsTextDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: AppTextStyles.mapRowTitle.copyWith(fontSize: 15),
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
                    : const Text('Publicar actividad'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.mapRowTitle.copyWith(fontSize: 13),
      ),
    );
  }
}

class _NikaraTextField extends StatelessWidget {
  const _NikaraTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: AppTextStyles.settingsSubtitle.copyWith(
        color: AppColors.settingsTextDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.mapControlBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.mapControlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
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

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.settingsTextDark,
        side: const BorderSide(color: AppColors.mapControlBorder),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
