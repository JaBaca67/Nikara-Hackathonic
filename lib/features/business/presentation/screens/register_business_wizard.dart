import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/user_session_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_success_screen.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
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

/// Nicaragua's 15 departments plus its 2 autonomous regions — real
/// administrative divisions, not a placeholder list.
const List<String> _kDepartments = [
  'Managua',
  'Masaya',
  'Granada',
  'Rivas',
  'Carazo',
  'Chinandega',
  'León',
  'Matagalpa',
  'Jinotega',
  'Estelí',
  'Madriz',
  'Nueva Segovia',
  'Boaco',
  'Chontales',
  'Río San Juan',
  'Región Autónoma de la Costa Caribe Norte',
  'Región Autónoma de la Costa Caribe Sur',
];

const List<String> _kActivities = [
  'Senderismo',
  'Kayak',
  'Canopy',
  'Tour de Café',
  'Fotografía',
  'Natación',
  'Gastronomía local',
  'Avistamiento de aves',
];

/// 4-step "Registra tu negocio" wizard. Purely local/mock: on finish it
/// writes a [BusinessModel] straight into [BusinessStorageService] and
/// pops back with the created instance — there's no backend involved.
///
/// Pass [existingBusiness] to reuse the same 4 steps as an editor: every
/// field pre-fills from it, "Finalizar" becomes "Guardar cambios", and
/// finishing calls [BusinessStorageService.updateBusiness] (same id/owner)
/// instead of creating a new listing.
class RegisterBusinessWizard extends StatefulWidget {
  const RegisterBusinessWizard({super.key, this.existingBusiness});

  final BusinessModel? existingBusiness;

  @override
  State<RegisterBusinessWizard> createState() =>
      _RegisterBusinessWizardState();
}

class _RegisterBusinessWizardState extends State<RegisterBusinessWizard> {
  final _storageService = BusinessStorageService();
  final _sessionService = UserSessionService();
  final _pageController = PageController();
  int _step = 0;
  bool _isSaving = false;

  bool get _isEditing => widget.existingBusiness != null;

  final _step1FormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = _kCategories.first;

  final _step2FormKey = GlobalKey<FormState>();
  String _city = _kDepartments.first;
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();

  final Set<String> _selectedAmenities = {};
  final Set<String> _selectedActivities = {};
  final _customActivityController = TextEditingController();
  final _schedulesController = TextEditingController();
  bool _allowsReservations = false;
  final _priceController = TextEditingController();

  final List<XFile> _images = [];

  /// Photo paths already saved on [RegisterBusinessWizard.existingBusiness]
  /// — shown and removable alongside freshly picked [_images], distinct
  /// only because they're [String] paths rather than [XFile]s.
  final List<String> _existingImagePaths = [];

  @override
  void initState() {
    super.initState();
    final business = widget.existingBusiness;
    if (business == null) return;
    _nameController.text = business.name;
    _descriptionController.text = business.description;
    _category = _kCategories.contains(business.category)
        ? business.category
        : _kCategories.first;
    _city = _kDepartments.contains(business.city)
        ? business.city
        : _kDepartments.first;
    _addressController.text = business.locationText;
    _phoneController.text = business.contactPhone;
    _instagramController.text = business.instagramLink;
    _tiktokController.text = business.tiktokLink;
    _selectedAmenities.addAll(business.amenities);
    _selectedActivities.addAll(business.activities);
    _schedulesController.text = business.schedules;
    _allowsReservations = business.allowsReservations;
    if (business.price != null) {
      _priceController.text = business.price!.toStringAsFixed(0);
    }
    _existingImagePaths.addAll(business.localImagePaths);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _customActivityController.dispose();
    _schedulesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addCustomActivity() {
    final text = _customActivityController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedActivities.add(text);
      _customActivityController.clear();
    });
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

  /// Removes the photo at [index] in the combined existing+new gallery —
  /// see the indexing note on the grid in `_buildStep4`.
  void _removeImageAt(int index) {
    setState(() {
      if (index < _existingImagePaths.length) {
        _existingImagePaths.removeAt(index);
      } else {
        _images.removeAt(index - _existingImagePaths.length);
      }
    });
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final existing = widget.existingBusiness;
    // hostName/ownerId always come from the active session, never typed in
    // manually — this is always re-stamped with the CURRENT session on
    // every save (create or edit), so a business stays attributed to
    // whoever is actually signed in even if they've since renamed
    // themselves in Settings.
    final sessionUser = await _sessionService.getUserData();
    final ownerId = sessionUser?.email ?? existing?.ownerId ?? '';
    final hostName = sessionUser != null && sessionUser.fullName.trim().isNotEmpty
        ? sessionUser.fullName
        : (existing?.hostName ?? '');

    // Instagram/TikTok are collected as bare @handles, never full URLs —
    // SocialContact rebuilds the canonical profile link from whichever of
    // these it finds set. Strip a leading "@" if the user typed one so the
    // stored value is always just the handle.
    final instagramHandle = _instagramController.text.trim().replaceFirst(
      '@',
      '',
    );
    final tiktokHandle = _tiktokController.text.trim().replaceFirst('@', '');

    final business = BusinessModel(
      id: existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      city: _city,
      locationText: _addressController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      instagramLink: instagramHandle,
      tiktokLink: tiktokHandle,
      facebookLink: existing?.facebookLink ?? '',
      socialMediaLink: existing?.socialMediaLink ?? '',
      allowsReservations: _allowsReservations,
      price: _allowsReservations
          ? double.tryParse(_priceController.text.trim())
          : null,
      amenities: _selectedAmenities.toList(),
      activities: _selectedActivities.toList(),
      hostName: hostName,
      ownerId: ownerId,
      schedules: _schedulesController.text.trim(),
      accessDetails: existing?.accessDetails ?? '',
      otherNotes: existing?.otherNotes ?? '',
      localImagePaths: [
        ..._existingImagePaths,
        ..._images.map((x) => x.path),
      ],
      reviews: existing?.reviews ?? const [],
    );

    if (existing != null) {
      await _storageService.updateBusiness(business);
      if (!mounted) return;
      Navigator.of(context).pop(business);
      return;
    }

    await _storageService.addBusiness(business);
    // PedidosYa Partner-style elevation: finishing registration as a
    // client instantly promotes the active Dev Mode persona to owner of
    // this new business — reactive, no restart needed.
    AuthService().elevateToOwner(business.id);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BusinessSuccessScreen(businessName: business.name),
      ),
      (route) => false,
    );
  }

  String? _required(String? value, String message) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      appBar: AppBar(
        backgroundColor: AppColors.settingsBackground,
        elevation: 0,
        foregroundColor: AppColors.neutral1100,
        title: Text(
          _isEditing ? 'Editar negocio' : 'Registra tu negocio',
          style: AppTextStyles.h6,
        ),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
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
          _FieldLabel('Ciudad / Municipio'),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: _decoration('Selecciona un departamento'),
            items: [
              for (final department in _kDepartments)
                DropdownMenuItem(value: department, child: Text(department)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _city = value);
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Se muestra en las tarjetas de resumen (ej: "Masaya").',
            style: AppTextStyles.legend.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Dirección exacta'),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: _decoration(
              'ej: De la iglesia San Jerónimo, 2c al lago',
            ),
            validator: (v) => _required(v, 'Ingresa la dirección exacta'),
          ),
          const SizedBox(height: 4),
          Text(
            'Se usa en el mapa y las indicaciones del perfil del negocio.',
            style: AppTextStyles.legend.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Número de WhatsApp'),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _decoration('ej: +505 8123 4567'),
            validator: (v) => _required(v, 'Ingresa un número de WhatsApp'),
          ),
          const SizedBox(height: 4),
          Text(
            'Los viajeros te escribirán directamente por WhatsApp.',
            style: AppTextStyles.legend.copyWith(color: AppColors.neutral600),
          ),
          const SizedBox(height: 16),
          _FieldLabel('Instagram (opcional)'),
          TextFormField(
            controller: _instagramController,
            decoration: _decoration('tunegocio').copyWith(prefixText: '@ '),
          ),
          const SizedBox(height: 16),
          _FieldLabel('TikTok (opcional)'),
          TextFormField(
            controller: _tiktokController,
            decoration: _decoration('tunegocio').copyWith(prefixText: '@ '),
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
                avatar: Icon(
                  amenityIcon(amenity),
                  size: 16,
                  color: AppColors.chipContentDark,
                ),
                label: Text(amenity),
                selected: _selectedAmenities.contains(amenity),
                onSelected: (selected) => setState(() {
                  selected
                      ? _selectedAmenities.add(amenity)
                      : _selectedAmenities.remove(amenity);
                }),
                backgroundColor: AppColors.warmChipBackground,
                selectedColor: AppColors.warmChipBackground,
                checkmarkColor: AppColors.chipContentDark,
                side: BorderSide(color: AppColors.warmChipBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: AppColors.warmChipBorder),
                ),
                labelStyle: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.chipContentDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _ActivitiesSection(
          selected: _selectedActivities,
          customController: _customActivityController,
          onToggle: (activity, selected) => setState(() {
            selected
                ? _selectedActivities.add(activity)
                : _selectedActivities.remove(activity);
          }),
          onRemoveCustom: (activity) =>
              setState(() => _selectedActivities.remove(activity)),
          onAddCustom: _addCustomActivity,
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
        Builder(
          builder: (context) {
            // Existing (edit mode) photos come first, newly picked ones
            // after — _removeImageAt relies on that same ordering to know
            // which backing list an index belongs to.
            final allPaths = [
              ..._existingImagePaths,
              ..._images.map((x) => x.path),
            ];
            if (allPaths.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allPaths.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LocalImage(path: allPaths[index]),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImageAt(index),
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
            );
          },
        ),
      ],
      backButton: _SecondaryButton(
        label: 'Atrás',
        onPressed: () => _goToStep(2),
      ),
      bottomButton: _PrimaryButton(
        label: _isSaving
            ? 'Guardando...'
            : (_isEditing ? 'Guardar cambios' : 'Finalizar'),
        onPressed: _isSaving ? null : _finish,
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.neutral600),
      filled: true,
      fillColor: AppColors.surface200.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.neutral600.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.neutral600.withValues(alpha: 0.35)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.wizardFocus, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFD64545), fontSize: 11),
    );
  }
}

class _ActivitiesSection extends StatelessWidget {
  const _ActivitiesSection({
    required this.selected,
    required this.customController,
    required this.onToggle,
    required this.onRemoveCustom,
    required this.onAddCustom,
  });

  final Set<String> selected;
  final TextEditingController customController;
  final void Function(String activity, bool selected) onToggle;
  final ValueChanged<String> onRemoveCustom;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final customActivities = selected
        .where((a) => !_kActivities.contains(a))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Actividades que ofrece el lugar'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final activity in _kActivities)
              FilterChip(
                avatar: Icon(
                  activityIcon(activity),
                  size: 16,
                  color: AppColors.chipContentDark,
                ),
                label: Text(activity),
                selected: selected.contains(activity),
                onSelected: (isSelected) => onToggle(activity, isSelected),
                backgroundColor: AppColors.warmChipBackgroundAlt,
                selectedColor: AppColors.warmChipBackgroundAlt,
                checkmarkColor: AppColors.chipContentDark,
                side: BorderSide(color: AppColors.warmChipBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: AppColors.warmChipBorder),
                ),
                labelStyle: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.chipContentDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            for (final custom in customActivities)
              InputChip(
                avatar: Icon(
                  activityIcon(custom),
                  size: 16,
                  color: AppColors.chipContentDark,
                ),
                label: Text(custom),
                onDeleted: () => onRemoveCustom(custom),
                backgroundColor: AppColors.warmChipBackgroundAlt,
                side: BorderSide(color: AppColors.warmChipBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: AppColors.warmChipBorder),
                ),
                labelStyle: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.chipContentDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customController,
                decoration: InputDecoration(
                  hintText: 'Agregar otra actividad',
                  hintStyle: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.neutral600,
                  ),
                  filled: true,
                  fillColor: AppColors.surface200.withValues(alpha: 0.35),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.neutral600.withValues(alpha: 0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.neutral600.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(
                      color: AppColors.wizardFocus,
                      width: 1.5,
                    ),
                  ),
                ),
                onSubmitted: (_) => onAddCustom(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                onPressed: onAddCustom,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.wizardFocus,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rounded step-dot + connector indicator (replaces the earlier thin
/// segmented bars) inside a soft white card, matching the Perfil redesign's
/// card language.
class _WizardStepper extends StatelessWidget {
  const _WizardStepper({required this.step});

  final int step;

  static const _labels = ['Datos', 'Contacto', 'Servicios', 'Fotos'];
  static const _dotSize = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i != 0)
              Expanded(
                child: SizedBox(
                  height: _dotSize,
                  child: Center(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? AppColors.wizardFocus
                            : AppColors.warmChipBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepDot(index: i, currentStep: step, size: _dotSize),
                const SizedBox(height: 6),
                Text(
                  _labels[i],
                  style: AppTextStyles.legend.copyWith(
                    color: i <= step
                        ? AppColors.wizardFocus
                        : AppColors.neutral500,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.currentStep,
    required this.size,
  });

  final int index;
  final int currentStep;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDone = index < currentStep;
    final isActive = index <= currentStep;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.wizardFocus : Colors.white,
        border: isActive
            ? null
            : Border.all(color: AppColors.warmChipBorder, width: 1.5),
      ),
      child: isDone
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text(
              '${index + 1}',
              style: AppTextStyles.legend.copyWith(
                color: isActive ? Colors.white : AppColors.neutral500,
                fontWeight: FontWeight.w700,
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
