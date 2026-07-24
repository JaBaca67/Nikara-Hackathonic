import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/theme/app_theme.dart';

const List<String> _kCategories = [
  'Eco Turismo',
  'Hospedaje',
  'Restaurante',
  'Aventura',
  'Cultura',
  'Transporte',
  'Otro',
];

const List<String> _kAmenities = [
  'Wifi',
  'Estacionamiento',
  'Piscina',
  'Restaurante',
  'Guías locales',
  'Área de camping',
  'Mascotas permitidas',
  'Accesible',
  'Aire acondicionado',
  'Desayuno incluido',
];

/// 4-step "Registra tu negocio" wizard. Purely local/mock: on finish it
/// writes a [BusinessModel] straight into [BusinessStorageService] and
/// pops back with the created instance — there's no backend involved.
class RegisterBusinessWizard extends StatefulWidget {
  const RegisterBusinessWizard({super.key});

  @override
  State<RegisterBusinessWizard> createState() =>
      _RegisterBusinessWizardState();
}

class _RegisterBusinessWizardState extends State<RegisterBusinessWizard> {
  final _storageService = BusinessStorageService();
  final _pageController = PageController();
  int _step = 0;
  bool _isSaving = false;

  final _step1FormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hostNameController = TextEditingController();
  String _category = _kCategories.first;

  final _step2FormKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _socialController = TextEditingController();

  final Set<String> _selectedAmenities = {};
  final _schedulesController = TextEditingController();
  bool _allowsReservations = false;
  final _priceController = TextEditingController();

  final List<XFile> _images = [];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _hostNameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _socialController.dispose();
    _schedulesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextFromStep1() {
    if (!(_step1FormKey.currentState?.validate() ?? false)) return;
    _goToStep(1);
  }

  void _nextFromStep2() {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;
    _goToStep(2);
  }

  void _nextFromStep3() {
    if (_allowsReservations) {
      final price = double.tryParse(_priceController.text.trim());
      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un precio válido')),
        );
        return;
      }
    }
    _goToStep(3);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    setState(() => _images.addAll(picked));
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final business = BusinessModel(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      locationText: _locationController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      socialMediaLink: _socialController.text.trim(),
      allowsReservations: _allowsReservations,
      price: _allowsReservations
          ? double.tryParse(_priceController.text.trim())
          : null,
      amenities: _selectedAmenities.toList(),
      hostName: _hostNameController.text.trim(),
      schedules: _schedulesController.text.trim(),
      localImagePaths: _images.map((x) => x.path).toList(),
    );

    await _storageService.addBusiness(business);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (route) => false,
    );
  }

  String? _required(String? value, String message) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface100,
      appBar: AppBar(
        backgroundColor: AppColors.surface100,
        elevation: 0,
        foregroundColor: AppColors.neutral1100,
        title: Text('Registra tu negocio', style: AppTextStyles.h6),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: _WizardStepper(step: _step),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepScaffold({
    required String title,
    required String subtitle,
    required List<Widget> children,
    required Widget bottomButton,
    Widget? backButton,
  }) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h5),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.bodyText2.copyWith(
            color: AppColors.neutral600,
          )),
          const SizedBox(height: 20),
          ...children,
          const SizedBox(height: 24),
          Row(
            children: [
              if (backButton != null) ...[
                backButton,
                const SizedBox(width: 12),
              ],
              Expanded(child: bottomButton),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: _stepScaffold(
        title: 'Datos básicos',
        subtitle: 'Cuéntanos qué ofreces y quién está detrás.',
        children: [
          _FieldLabel('Nombre del negocio'),
          TextFormField(
            controller: _nameController,
            decoration: _decoration('ej: Laguna de Apoyo Tours'),
            validator: (v) => _required(v, 'Ingresa el nombre del negocio'),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Categoría'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in _kCategories)
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                  selectedColor: AppColors.primary500.withValues(alpha: 0.25),
                  labelStyle: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.neutral1100,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldLabel('Descripción'),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: _decoration('Describe tu negocio en pocas líneas'),
            validator: (v) => _required(v, 'Ingresa una descripción'),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Nombre del anfitrión'),
          TextFormField(
            controller: _hostNameController,
            decoration: _decoration('ej: Cooperativa Laguna Verde'),
            validator: (v) => _required(v, 'Ingresa el nombre del anfitrión'),
          ),
        ],
        bottomButton: _PrimaryButton(label: 'Siguiente', onPressed: _nextFromStep1),
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: _stepScaffold(
        title: 'Ubicación y contacto',
        subtitle: 'Así te encontrarán los viajeros.',
        children: [
          _FieldLabel('Ubicación'),
          TextFormField(
            controller: _locationController,
            decoration: _decoration('ej: Masaya, Nicaragua'),
            validator: (v) => _required(v, 'Ingresa la ubicación'),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Teléfono de contacto'),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _decoration('ej: +505 8123 4567'),
            validator: (v) => _required(v, 'Ingresa un teléfono'),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Enlace de redes sociales (opcional)'),
          TextFormField(
            controller: _socialController,
            keyboardType: TextInputType.url,
            decoration: _decoration('ej: https://instagram.com/tunegocio'),
          ),
        ],
        backButton: _SecondaryButton(
          label: 'Atrás',
          onPressed: () => _goToStep(0),
        ),
        bottomButton: _PrimaryButton(label: 'Siguiente', onPressed: _nextFromStep2),
      ),
    );
  }

  Widget _buildStep3() {
    return _stepScaffold(
      title: 'Servicios y reservas',
      subtitle: 'Qué incluye tu experiencia y cómo se reserva.',
      children: [
        _FieldLabel('Comodidades / servicios'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amenity in _kAmenities)
              FilterChip(
                label: Text(amenity),
                selected: _selectedAmenities.contains(amenity),
                onSelected: (selected) => setState(() {
                  selected
                      ? _selectedAmenities.add(amenity)
                      : _selectedAmenities.remove(amenity);
                }),
                selectedColor: AppColors.ecoGreen500.withValues(alpha: 0.35),
                labelStyle: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.neutral1100,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldLabel('Horarios / reglas'),
        TextFormField(
          controller: _schedulesController,
          maxLines: 2,
          decoration: _decoration('ej: Todos los días, 7:00 am – 6:00 pm'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface200.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Permitir reservas', style: AppTextStyles.subtitle2),
              ),
              Switch(
                value: _allowsReservations,
                onChanged: (v) => setState(() => _allowsReservations = v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary500,
              ),
            ],
          ),
        ),
        if (_allowsReservations) ...[
          const SizedBox(height: 16),
          _FieldLabel('Precio por persona (C\$)'),
          TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration('ej: 350'),
          ),
        ],
      ],
      backButton: _SecondaryButton(
        label: 'Atrás',
        onPressed: () => _goToStep(1),
      ),
      bottomButton: _PrimaryButton(label: 'Siguiente', onPressed: _nextFromStep3),
    );
  }

  Widget _buildStep4() {
    return _stepScaffold(
      title: 'Fotos del negocio',
      subtitle: 'Las buenas fotos son la mejor carta de presentación.',
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surface200.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary500.withValues(alpha: 0.4),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.primary500,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text('Abrir galería', style: AppTextStyles.subtitle2),
              ],
            ),
          ),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final image = _images[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(image.path, fit: BoxFit.cover)
                        : Image.file(File(image.path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
      backButton: _SecondaryButton(
        label: 'Atrás',
        onPressed: () => _goToStep(2),
      ),
      bottomButton: _PrimaryButton(
        label: _isSaving ? 'Guardando...' : 'Finalizar',
        onPressed: _isSaving ? null : _finish,
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.neutral600),
      filled: true,
      fillColor: AppColors.surface100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.neutral600.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.neutral600.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFD64545), fontSize: 11),
    );
  }
}

class _WizardStepper extends StatelessWidget {
  const _WizardStepper({required this.step});

  final int step;

  static const _labels = ['Datos', 'Contacto', 'Servicios', 'Fotos'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? AppColors.primary500
                        : AppColors.surface200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _labels[i],
                  style: AppTextStyles.legend.copyWith(
                    color: i <= step
                        ? AppColors.neutral1100
                        : AppColors.neutral500,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (i != _labels.length - 1) const SizedBox(width: 6),
        ],
      ],
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
        text.toUpperCase(),
        style: AppTextStyles.inputLabel,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary500,
          disabledBackgroundColor: AppColors.primary500.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonLg.copyWith(
            color: enabled ? const Color(0xFF1A1510) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: AppColors.neutral600.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonLg.copyWith(color: AppColors.neutral1100),
        ),
      ),
    );
  }
}
