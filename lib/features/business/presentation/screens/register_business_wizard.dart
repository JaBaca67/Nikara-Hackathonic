import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/business_success_screen.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_theme.dart';

const List<String> _kCategoryPresets = [
  'Eco-destino',
  'Restaurante',
  'Hospedaje',
  'Tour',
  'Cultura',
  'Transporte',
];

const List<String> _kAmenityPresets = [
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

const List<String> _kActivityPresets = [
  'Senderismo',
  'Tour de café',
  'Tour en lancha',
  'Kayak',
  'Gastronomía local',
  'Fotografía',
];

const List<String> _kEcoPractices = [
  'Atendido por familias de la comunidad',
  'Manejo de residuos y reciclaje',
  'Productos locales o de temporada',
  'Conservación de flora y fauna del sitio',
];

/// Nicaragua primero/default, luego vecinos centroamericanos y US/Canadá.
const List<String> _kCountryCodes = [
  '+505',
  '+506',
  '+504',
  '+503',
  '+502',
  '+1',
];

/// El dropdown "Departamento" es solo un filtro en cascada de UI; únicamente el municipio elegido se persiste en `businesses.city`.
const Map<String, List<String>> _kMunicipalitiesByDepartment = {
  'Managua': [
    'Managua',
    'Ciudad Sandino',
    'El Crucero',
    'Mateare',
    'San Francisco Libre',
    'San Rafael del Sur',
    'Tipitapa',
    'Ticuantepe',
    'Villa El Carmen',
  ],
  'Masaya': [
    'Masaya',
    'Catarina',
    'La Concepción',
    'Masatepe',
    'Nandasmo',
    'Nindirí',
    'Niquinohomo',
    'San Juan de Oriente',
    'Tisma',
  ],
  'Granada': ['Granada', 'Diriá', 'Diriomo', 'Nandaime'],
  'Rivas': [
    'Rivas',
    'Altagracia',
    'Belén',
    'Buenos Aires',
    'Cárdenas',
    'Moyogalpa',
    'Potosí',
    'San Jorge',
    'San Juan del Sur',
    'Tola',
  ],
  'Carazo': [
    'Jinotepe',
    'Diriamba',
    'Dolores',
    'El Rosario',
    'La Conquista',
    'La Paz de Carazo',
    'San Marcos',
    'Santa Teresa',
  ],
  'Chinandega': [
    'Chinandega',
    'Chichigalpa',
    'Corinto',
    'El Realejo',
    'El Viejo',
    'Posoltega',
    'Puerto Morazán',
    'San Francisco del Norte',
    'San Pedro del Norte',
    'Santo Tomás del Norte',
    'Somotillo',
    'Villanueva',
  ],
  'León': [
    'León',
    'Achuapa',
    'El Jicaral',
    'El Sauce',
    'La Paz Centro',
    'Larreynaga',
    'Nagarote',
    'Quezalguaque',
    'Santa Rosa del Peñón',
    'Telica',
  ],
  'Matagalpa': [
    'Matagalpa',
    'Ciudad Darío',
    'Esquipulas',
    'Terrabona',
    'San Isidro',
    'Sébaco',
    'San Ramón',
    'Matiguás',
    'Río Blanco',
    'Muy Muy',
    'Rancho Grande',
    'Tuma-La Dalia',
    'San Dionisio',
  ],
  'Jinotega': [
    'Jinotega',
    'San Rafael del Norte',
    'San Sebastián de Yalí',
    'La Concordia',
    'El Cuá',
    'San José de Bocay',
    'Santa María de Pantasma',
    'Wiwilí de Jinotega',
  ],
  'Estelí': [
    'Estelí',
    'Condega',
    'La Trinidad',
    'Pueblo Nuevo',
    'San Juan de Limay',
    'San Nicolás',
  ],
  'Madriz': [
    'Somoto',
    'Las Sabanas',
    'Palacagüina',
    'San José de Cusmapa',
    'San Juan de Río Coco',
    'San Lucas',
    'Telpaneca',
    'Totogalpa',
    'Yalagüina',
  ],
  'Nueva Segovia': [
    'Ocotal',
    'Ciudad Antigua',
    'Dipilto',
    'El Jícaro',
    'Jalapa',
    'Macuelizo',
    'Mozonte',
    'Murra',
    'Quilalí',
    'San Fernando',
    'Santa María',
    'Wiwilí',
  ],
  'Boaco': [
    'Boaco',
    'Camoapa',
    'San José de los Remates',
    'San Lorenzo',
    'Santa Lucía',
    'Teustepe',
  ],
  'Chontales': [
    'Juigalpa',
    'Acoyapa',
    'Comalapa',
    'Cuapa',
    'El Coral',
    'La Libertad',
    'San Pedro de Lóvago',
    'Santo Domingo',
    'Santo Tomás',
    'Villa Sandino',
  ],
  'Río San Juan': [
    'San Carlos',
    'El Almendro',
    'El Castillo',
    'Morrito',
    'San Juan de Nicaragua',
    'San Miguelito',
  ],
  'Región Autónoma de la Costa Caribe Norte': [
    'Bilwi (Puerto Cabezas)',
    'Bonanza',
    'Mulukukú',
    'Prinzapolka',
    'Rosita',
    'Siuna',
    'Waslala',
    'Waspán',
  ],
  'Región Autónoma de la Costa Caribe Sur': [
    'Bluefields',
    'Corn Island',
    'Desembocadura de Río Grande',
    'El Ayote',
    'El Rama',
    'El Tortuguero',
    'Kukra Hill',
    'La Cruz de Río Grande',
    'Laguna de Perlas',
    'Muelle de los Bueyes',
    'Nueva Guinea',
    'Paiwas',
  ],
};

List<String> get _kDepartments => _kMunicipalitiesByDepartment.keys.toList();

/// Si [city] no está en ningún departamento (valor recién tipeado o de antes del picker en cascada), cae al primer departamento.
String _departmentForCity(String city) {
  for (final entry in _kMunicipalitiesByDepartment.entries) {
    if (entry.value.contains(city)) return entry.key;
  }
  return _kDepartments.first;
}

const LatLng _kDefaultMapCenter = LatLng(12.1363, -86.2513);

final LatLngBounds _kMapBounds = LatLngBounds(
  southwest: const LatLng(7.0, -92.0),
  northeast: const LatLng(18.5, -77.0),
);

/// [weekdays] queda vacío en entradas de texto libre porque no se puede mapear texto arbitrario a días reales de forma confiable.
class _ScheduleEntry {
  _ScheduleEntry({
    required this.daysLabel,
    required this.weekdays,
    required this.start,
    required this.end,
  });

  String daysLabel;
  Set<int> weekdays;
  TimeOfDay start;
  TimeOfDay end;

  static _ScheduleEntry weekdays9to6() => _ScheduleEntry(
    daysLabel: 'Lunes a viernes',
    weekdays: {1, 2, 3, 4, 5},
    start: const TimeOfDay(hour: 7, minute: 0),
    end: const TimeOfDay(hour: 18, minute: 0),
  );

  static _ScheduleEntry weekend() => _ScheduleEntry(
    daysLabel: 'Sábado y domingo',
    weekdays: {6, 7},
    start: const TimeOfDay(hour: 6, minute: 0),
    end: const TimeOfDay(hour: 19, minute: 0),
  );

  static const Map<String, Set<int>> _knownDayLabels = {
    'Lunes a viernes': {1, 2, 3, 4, 5},
    'Sábado y domingo': {6, 7},
    'Todos los días': {1, 2, 3, 4, 5, 6, 7},
  };

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get hoursLabel => '${_fmt(start)}–${_fmt(end)}';

  String toLine() => '$daysLabel: $hoursLabel';

  static _ScheduleEntry? _parseLine(String line) {
    final parts = line.split(': ');
    if (parts.length != 2) return null;
    final hours = RegExp(
      r'^(\d{1,2}):(\d{2})–(\d{1,2}):(\d{2})$',
    ).firstMatch(parts[1]);
    if (hours == null) return null;
    return _ScheduleEntry(
      daysLabel: parts[0],
      weekdays: _knownDayLabels[parts[0]] ?? {},
      start: TimeOfDay(
        hour: int.parse(hours.group(1)!),
        minute: int.parse(hours.group(2)!),
      ),
      end: TimeOfDay(
        hour: int.parse(hours.group(3)!),
        minute: int.parse(hours.group(4)!),
      ),
    );
  }

  /// Preserva el texto crudo como entrada libre si el formato no matchea, para no perder el horario de negocios guardados antes de este picker estructurado.
  static List<_ScheduleEntry> parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return [weekdays9to6(), weekend()];
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    final parsed = <_ScheduleEntry>[];
    for (final line in lines) {
      final entry = _parseLine(line);
      if (entry != null) parsed.add(entry);
    }
    if (parsed.isNotEmpty) return parsed;
    return [
      _ScheduleEntry(
        daysLabel: text,
        weekdays: const {},
        start: const TimeOfDay(hour: 8, minute: 0),
        end: const TimeOfDay(hour: 17, minute: 0),
      ),
    ];
  }

  static String format(List<_ScheduleEntry> entries) =>
      entries.map((e) => e.toLine()).join('\n');

  /// Solo cuenta entradas con [weekdays] reconocidos; una etiqueta de día libre nunca reclama un estado que no puede respaldar.
  static bool isOpenNow(List<_ScheduleEntry> entries) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (final entry in entries) {
      if (!entry.weekdays.contains(DateTime.now().weekday)) continue;
      final startMinutes = entry.start.hour * 60 + entry.start.minute;
      final endMinutes = entry.end.hour * 60 + entry.end.minute;
      if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) return true;
    }
    return false;
  }
}

/// 4-step "Registra tu negocio" wizard — Pantallas 4a-4d ("Datos", "Ubicación",
/// "Galería", "Publicar"). Con [existingBusiness] reutiliza los mismos 4 pasos como editor (pre-llena, "Guardar cambios", `updateBusiness`); [initialStep] permite saltar directo a una sección desde el hub "Editar negocio".
class RegisterBusinessWizard extends StatefulWidget {
  const RegisterBusinessWizard({
    super.key,
    this.existingBusiness,
    this.initialStep = 0,
  });

  final BusinessModel? existingBusiness;
  final int initialStep;

  @override
  State<RegisterBusinessWizard> createState() => _RegisterBusinessWizardState();
}

class _RegisterBusinessWizardState extends State<RegisterBusinessWizard> {
  final _storageService = BusinessStorageService();
  final _authService = AuthService();
  late final _pageController = PageController(initialPage: widget.initialStep);
  bool _isSaving = false;

  bool get _isEditing => widget.existingBusiness != null;

  // --- Paso 1 (4a): Datos generales y contacto ---
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = _kCategoryPresets.first;
  String _countryCode = _kCountryCodes.first;
  final _phoneController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  late List<_ScheduleEntry> _schedule = _ScheduleEntry.parse('');

  // --- Paso 2 (4b): Ubicación y pin en el mapa ---
  late String _department = _kDepartments.first;
  late String _city = _kMunicipalitiesByDepartment[_department]!.first;
  final _addressController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng _mapCenter = _kDefaultMapCenter;
  LatLng? _confirmedLocation;
  bool _locatingUser = false;

  // --- Paso 3 (4c): Galería y atributos ECO ---
  final List<XFile> _images = [];
  final List<String> _existingImagePaths = [];
  bool _ecoSealRequested = false;
  final Set<String> _ecoPractices = {};
  final Set<String> _selectedActivities = {};
  final Set<String> _selectedAmenities = {};
  final _customActivityController = TextEditingController();
  String _customActivityIconKey = 'explore';

  List<String> get _allPhotoPaths => [
    ..._existingImagePaths,
    ..._images.map((x) => x.path),
  ];

  @override
  void initState() {
    super.initState();
    final business = widget.existingBusiness;
    if (business == null) {
      _schedule = _ScheduleEntry.parse('');
      _locateUser();
      return;
    }
    _nameController.text = business.name;
    _descriptionController.text = business.description;
    _category = business.category.isEmpty
        ? _kCategoryPresets.first
        : business.category;
    _department = _departmentForCity(business.city);
    _city = business.city.isEmpty
        ? _kMunicipalitiesByDepartment[_department]!.first
        : business.city;
    _addressController.text = business.locationText;
    final phoneParts = _splitPhone(business.contactPhone);
    _countryCode = phoneParts.$1;
    _phoneController.text = phoneParts.$2;
    _instagramController.text = business.instagramLink;
    _facebookController.text = business.facebookLink;
    _schedule = _ScheduleEntry.parse(business.schedules);
    if (business.latitude != null && business.longitude != null) {
      final existingLocation = LatLng(business.latitude!, business.longitude!);
      _mapCenter = existingLocation;
      _confirmedLocation = existingLocation;
    }
    _existingImagePaths.addAll(business.localImagePaths);
    _ecoSealRequested = business.ecoSealRequested;
    _ecoPractices.addAll(business.ecoPractices);
    _selectedActivities.addAll(business.activities);
    _selectedAmenities.addAll(business.amenities);
  }

  /// Un número guardado antes del picker de código (o con código no reconocido) queda entero en el campo número bajo el código default, sin truncarlo.
  (String, String) _splitPhone(String phone) {
    final trimmed = phone.trim();
    for (final code in _kCountryCodes) {
      if (trimmed.startsWith(code)) {
        return (code, trimmed.substring(code.length).trim());
      }
    }
    return (_kCountryCodes.first, trimmed);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _addressController.dispose();
    _customActivityController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    setState(() => _locatingUser = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() => _mapCenter = here);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(here, 15));
    } catch (_) {
      // Se queda en el default de Managua, igual que MapScreen.
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  void _confirmLocation() {
    setState(() => _confirmedLocation = _mapCenter);
  }

  void _zoomMap(double delta) {
    _mapController?.animateCamera(
      delta > 0 ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
    );
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
    if (_nameController.text.trim().isEmpty) {
      _snack('Ingresa el nombre del negocio');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _snack('Ingresa una descripción corta');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _snack('El número de WhatsApp es obligatorio');
      return;
    }
    _goToStep(1);
  }

  void _nextFromStep2() {
    if (_addressController.text.trim().isEmpty) {
      _snack('Ingresa una dirección o referencia');
      return;
    }
    if (_confirmedLocation == null) {
      _snack(
        'Ubica tu negocio en el mapa y presiona "Confirmar esta ubicación" '
        'antes de continuar.',
      );
      return;
    }
    _goToStep(2);
  }

  void _nextFromStep3() {
    if (_allPhotoPaths.isEmpty) {
      _snack('Agrega al menos una foto antes de continuar');
      return;
    }
    _goToStep(3);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addCustomActivity() {
    final text = _customActivityController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedActivities.add(encodeActivity(_customActivityIconKey, text));
      _customActivityController.clear();
      _customActivityIconKey = 'explore';
    });
  }

  Future<void> _pickActivityIcon() async {
    final key = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ActivityIconPickerSheet(),
    );
    if (key == null || !mounted) return;
    setState(() => _customActivityIconKey = key);
  }

  Future<void> _pickCoverOrGalleryPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty || !mounted) return;
    setState(() => _images.addAll(picked));
  }

  /// El índice 0 siempre es la portada.
  void _removeImageAt(int index) {
    setState(() {
      if (index < _existingImagePaths.length) {
        _existingImagePaths.removeAt(index);
      } else {
        _images.removeAt(index - _existingImagePaths.length);
      }
    });
  }

  void _makeCover(int index) {
    if (index == 0) return;
    setState(() {
      final paths = _allPhotoPaths;
      final target = paths.removeAt(index);
      paths.insert(0, target);
      // Re-separa en las listas existing/new preservando el orden, igual que _allPhotoPaths.
      final existing = paths.where(_existingImagePaths.contains).toList();
      final imagesByPath = {for (final x in _images) x.path: x};
      final newOnes = paths.where((p) => !_existingImagePaths.contains(p));
      _existingImagePaths
        ..clear()
        ..addAll(existing);
      _images
        ..clear()
        ..addAll(newOnes.map((p) => imagesByPath[p]!));
    });
  }

  /// Solo para "Vista previa" (nunca se guarda).
  BusinessModel _draftBusiness() {
    final existing = widget.existingBusiness;
    return BusinessModel(
      id: existing?.id ?? 'draft',
      name: _nameController.text.trim().isEmpty
          ? 'Tu negocio'
          : _nameController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      city: _city,
      locationText: _addressController.text.trim(),
      latitude: _confirmedLocation?.latitude,
      longitude: _confirmedLocation?.longitude,
      contactPhone: '$_countryCode ${_phoneController.text.trim()}'.trim(),
      instagramLink: _instagramController.text.trim().replaceFirst('@', ''),
      facebookLink: _facebookController.text.trim().replaceFirst('@', ''),
      tiktokLink: existing?.tiktokLink ?? '',
      allowsReservations: false,
      amenities: _selectedAmenities.toList(),
      activities: _selectedActivities.toList(),
      ecoSealRequested: _ecoSealRequested,
      ecoPractices: _ecoPractices.toList(),
      hostName: existing?.hostName ?? '',
      schedules: _ScheduleEntry.format(_schedule),
      localImagePaths: _allPhotoPaths,
      reviews: existing?.reviews ?? const [],
      isVerified: existing?.isVerified ?? false,
    );
  }

  void _openPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: _draftBusiness()),
      ),
    );
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final existing = widget.existingBusiness;
    final profile = await _authService.getCurrentProfile();
    if (!mounted) return;
    final ownerId = _authService.currentAuthUser?.id ?? existing?.ownerId ?? '';
    if (ownerId.isEmpty) {
      setState(() => _isSaving = false);
      _snack(
        'No se pudo identificar tu cuenta. Cierra sesión y vuelve a '
        'iniciar sesión para continuar.',
      );
      return;
    }
    final hostName = profile != null && profile.fullName.trim().isNotEmpty
        ? profile.fullName
        : (existing?.hostName ?? '');

    final location = _confirmedLocation;
    if (location == null) {
      setState(() => _isSaving = false);
      _snack('Confirma la ubicación del negocio en el mapa antes de guardar.');
      return;
    }
    if (_allPhotoPaths.isEmpty) {
      setState(() => _isSaving = false);
      _snack('Agrega al menos una foto antes de publicar.');
      return;
    }

    final business = BusinessModel(
      id: existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      city: _city,
      locationText: _addressController.text.trim(),
      latitude: location.latitude,
      longitude: location.longitude,
      contactPhone: '$_countryCode ${_phoneController.text.trim()}'.trim(),
      instagramLink: _instagramController.text.trim().replaceFirst('@', ''),
      facebookLink: _facebookController.text.trim().replaceFirst('@', ''),
      tiktokLink: existing?.tiktokLink ?? '',
      socialMediaLink: existing?.socialMediaLink ?? '',
      allowsReservations: existing?.allowsReservations ?? false,
      price: existing?.price,
      amenities: _selectedAmenities.toList(),
      activities: _selectedActivities.toList(),
      ecoSealRequested: _ecoSealRequested,
      ecoPractices: _ecoPractices.toList(),
      hostName: hostName,
      ownerId: ownerId,
      schedules: _ScheduleEntry.format(_schedule),
      accessDetails: existing?.accessDetails ?? '',
      otherNotes: existing?.otherNotes ?? '',
      localImagePaths: _allPhotoPaths,
      reviews: existing?.reviews ?? const [],
      isVerified: existing?.isVerified ?? false,
    );

    debugPrint(
      '[RegisterBusinessWizard] _finish(): about to save "${business.name}" '
      '(${_isEditing ? 'update' : 'create'}) with confirmedLocation='
      '(lat=${location.latitude}, lng=${location.longitude}), '
      'mapCenter=(lat=${_mapCenter.latitude}, lng=${_mapCenter.longitude})',
    );

    try {
      if (existing != null) {
        await _storageService.updateBusiness(business);
        if (!mounted) return;
        Navigator.of(context).pop(business);
        return;
      }

      await _storageService.addBusiness(business);
      try {
        await _authService.markAsEmprendedor();
      } on AuthServiceException {
        // Se ignora: el negocio ya se guardó correctamente.
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BusinessSuccessScreen(businessName: business.name),
        ),
        (route) => false,
      );
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.settingsBackground,
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
              _buildStep4(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String subtitle) {
    return _WizardHeader(
      title: _isEditing ? 'Editar negocio' : 'Registra tu negocio',
      subtitle: subtitle,
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _card({required List<Widget> children, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        border: Border.all(color: AppColors.mapControlBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.detailCardGlow,
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionIntro(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.wizardStepHeading),
          const SizedBox(height: 3),
          Text(subtitle, style: AppTextStyles.wizardStepSubtitle),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        _header('Paso 1 de 4 · borrador guardado'),
        _WizardStepper(step: 0),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionIntro(
                  'Datos generales',
                  'Cuéntanos qué ofreces y cómo te contactan.',
                ),
                _card(
                  children: [
                    Text(
                      'NOMBRE DEL NEGOCIO',
                      style: AppTextStyles.wizardFieldLabel,
                    ),
                    const SizedBox(height: 7),
                    _WizardTextField(
                      controller: _nameController,
                      hint: 'ej: Laguna de Apoyo Tours',
                    ),
                    const SizedBox(height: 16),
                    Text('CATEGORÍA', style: AppTextStyles.wizardFieldLabel),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in {
                          ..._kCategoryPresets,
                          _category,
                        })
                          _WizardChip(
                            label: category,
                            selected: _category == category,
                            onTap: () => setState(() => _category = category),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Define el ícono de tu pin en el mapa y los filtros donde apareces.',
                      style: AppTextStyles.wizardCaption,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'DESCRIPCIÓN CORTA',
                            style: AppTextStyles.wizardFieldLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _descriptionController,
                          builder: (context, _) => Text(
                            '${_descriptionController.text.length} / 160',
                            style: AppTextStyles.wizardCaption.copyWith(
                              color: AppColors.neutral400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _WizardTextField(
                      controller: _descriptionController,
                      hint: 'Describe tu negocio en pocas líneas',
                      maxLines: 4,
                      maxLength: 160,
                    ),
                  ],
                ),
                _card(
                  children: [
                    Text('Contacto', style: AppTextStyles.wizardCardTitle),
                    const SizedBox(height: 12),
                    Text('WHATSAPP', style: AppTextStyles.wizardFieldLabel),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _CountryCodeField(
                          value: _countryCode,
                          onChanged: (v) => setState(() => _countryCode = v),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _WizardTextField(
                            controller: _phoneController,
                            hint: '8123 4567',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.accent300,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Es el botón principal de tu perfil. Obligatorio.',
                            style: AppTextStyles.wizardCaption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'REDES (OPCIONAL)',
                      style: AppTextStyles.wizardFieldLabel,
                    ),
                    const SizedBox(height: 7),
                    _SocialField(
                      icon: Icons.photo_camera,
                      iconBg: AppColors.detailInstagramIconBg,
                      iconColor: AppColors.favoriteActive,
                      controller: _instagramController,
                      hint: '@tunegocio',
                    ),
                    const SizedBox(height: 8),
                    _SocialField(
                      icon: Icons.thumb_up,
                      iconBg: AppColors.wizardFacebookIconBg,
                      iconColor: AppColors.wizardFacebookIcon,
                      controller: _facebookController,
                      hint: 'facebook.com/tunegocio',
                    ),
                  ],
                ),
                _card(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Horarios de atención',
                            style: AppTextStyles.wizardCardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _OpenNowPill(entries: _schedule),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Con esto Níkara calcula el estado que ven los viajeros en tiempo real.',
                      style: AppTextStyles.wizardCaption,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        for (var i = 0; i < _schedule.length; i++) ...[
                          _ScheduleRow(
                            entry: _schedule[i],
                            onChanged: (updated) =>
                                setState(() => _schedule[i] = updated),
                            onRemove: _schedule.length > 1
                                ? () => setState(() => _schedule.removeAt(i))
                                : null,
                          ),
                          if (i != _schedule.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(
                        () => _schedule.add(
                          _ScheduleEntry(
                            daysLabel: 'Otro día',
                            weekdays: const {},
                            start: const TimeOfDay(hour: 8, minute: 0),
                            end: const TimeOfDay(hour: 17, minute: 0),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add,
                              size: 16,
                              color: AppColors.accent300,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Agregar un día distinto',
                                style: AppTextStyles.detailInlineLink,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _WizardFooter(
          primaryLabel: 'Siguiente',
          onPrimary: _nextFromStep1,
          secondaryLabel: 'Guardar',
          onSecondary: () => _snack('Borrador guardado en este dispositivo'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final municipalities = _kMunicipalitiesByDepartment[_department]!;
    return Column(
      children: [
        _header('Paso 2 de 4 · borrador guardado'),
        _WizardStepper(step: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionIntro(
                  '¿Dónde te encuentran?',
                  'La ubicación define tu pin en el mapa y la distancia que ve cada viajero.',
                ),
                _card(
                  children: [
                    Text('DEPARTAMENTO', style: AppTextStyles.wizardFieldLabel),
                    const SizedBox(height: 7),
                    _WizardDropdown(
                      value: _department,
                      items: _kDepartments,
                      onChanged: (v) => setState(() {
                        _department = v;
                        _city = _kMunicipalitiesByDepartment[v]!.first;
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CIUDAD O MUNICIPIO',
                      style: AppTextStyles.wizardFieldLabel,
                    ),
                    const SizedBox(height: 7),
                    _WizardDropdown(
                      value: municipalities.contains(_city)
                          ? _city
                          : municipalities.first,
                      items: municipalities.contains(_city)
                          ? municipalities
                          : [_city, ...municipalities],
                      onChanged: (v) => setState(() => _city = v),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Es lo único que se muestra en las tarjetas de Inicio y Mapa.',
                      style: AppTextStyles.wizardCaption,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'DIRECCIÓN O REFERENCIA',
                      style: AppTextStyles.wizardFieldLabel,
                    ),
                    const SizedBox(height: 7),
                    _WizardTextField(
                      controller: _addressController,
                      hint: 'Del mirador de Catarina, 800 m al sur...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Aparece solo en "Cómo llegar", dentro de tu perfil.',
                      style: AppTextStyles.wizardCaption,
                    ),
                  ],
                ),
                _card(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pin exacto',
                            style: AppTextStyles.wizardCardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _locateUser,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.settingsBackground,
                              border: Border.all(
                                color: AppColors.mapControlBorder,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_locatingUser)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                    _MapLocationPicker(
                      initialCenter: _mapCenter,
                      onMapCreated: (controller) => _mapController = controller,
                      onCameraMove: (center) => _mapCenter = center,
                      onTap: (point) => _mapController?.animateCamera(
                        CameraUpdate.newLatLng(point),
                      ),
                      onZoomIn: () => _zoomMap(1),
                      onZoomOut: () => _zoomMap(-1),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.touch_app,
                          size: 15,
                          color: AppColors.accent300,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Arrastra el mapa o toca un punto para que el pin quede sobre la entrada de tu negocio.',
                            style: AppTextStyles.wizardCaption,
                          ),
                        ),
                      ],
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
                    if (_confirmedLocation != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.detailActivityIconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.accent300,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Coordenadas guardadas · '
                                '${_confirmedLocation!.latitude.toStringAsFixed(4)}, '
                                '${_confirmedLocation!.longitude.toStringAsFixed(4)}',
                                style: AppTextStyles.detailActivityLabel
                                    .copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent300,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        _WizardFooter(
          primaryLabel: 'Siguiente',
          onPrimary: _nextFromStep2,
          secondaryLabel: 'Atrás',
          onSecondary: () => _goToStep(0),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final photos = _allPhotoPaths;
    final customActivities = _selectedActivities.where(
      (a) => !_kActivityPresets.contains(a),
    );
    return Column(
      children: [
        _header('Paso 3 de 4 · borrador guardado'),
        _WizardStepper(step: 2),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionIntro(
                  'Fotos y atributos',
                  'La portada es lo primero que ve el viajero en Inicio y Mapa.',
                ),
                _card(
                  children: [
                    Text(
                      'FOTO DE PORTADA',
                      style: AppTextStyles.wizardFieldLabel,
                    ),
                    const SizedBox(height: 8),
                    if (photos.isEmpty)
                      GestureDetector(
                        onTap: _pickCoverOrGalleryPhotos,
                        child: Container(
                          height: 158,
                          decoration: BoxDecoration(
                            color: AppColors.wizardUploadZoneBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary500.withValues(
                                alpha: 0.6,
                              ),
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
                                'Subir foto de portada',
                                style: AppTextStyles.wizardCardTitle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Horizontal, mínimo 1200 × 800 px',
                                style: AppTextStyles.wizardCaption,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 158,
                          width: double.infinity,
                          child: LocalImage(path: photos.first),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'GALERÍA',
                            style: AppTextStyles.wizardFieldLabel,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            '${photos.length} de 10',
                            style: AppTextStyles.wizardCaption.copyWith(
                              color: AppColors.neutral400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: photos.length < 10
                          ? photos.length + 1
                          : photos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemBuilder: (context, index) {
                        if (index >= photos.length) {
                          return GestureDetector(
                            onTap: _pickCoverOrGalleryPhotos,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.settingsBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.mapControlBorder,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add,
                                    size: 20,
                                    color: AppColors.settingsTextMuted,
                                  ),
                                  Text(
                                    'Agregar',
                                    style: AppTextStyles.wizardChipLabel
                                        .copyWith(
                                          fontSize: 9.5,
                                          color: AppColors.settingsTextMuted,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return GestureDetector(
                          onTap: () => _makeCover(index),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: LocalImage(path: photos[index]),
                              ),
                              if (index == 0)
                                Positioned(
                                  left: 4,
                                  bottom: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.detailCoverCounterBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Portada',
                                      style: AppTextStyles.homeMiniBadge
                                          .copyWith(
                                            color: AppColors.surface100,
                                          ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 5,
                                top: 5,
                                child: GestureDetector(
                                  onTap: () => _removeImageAt(index),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.removeButtonBackground,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: AppColors.surface100,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca una foto para hacerla portada. Mínimo una para publicar.',
                      style: AppTextStyles.wizardCaption,
                    ),
                  ],
                ),
                _card(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.detailActivityIconBg,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.eco,
                            color: AppColors.accent300,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sello ECO',
                                style: AppTextStyles.wizardCardTitle,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Para negocios con prácticas sostenibles',
                                style: AppTextStyles.wizardCaption,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _ecoSealRequested,
                          onChanged: (v) =>
                              setState(() => _ecoSealRequested = v),
                          activeThumbColor: AppColors.surface100,
                          activeTrackColor: AppColors.accent300,
                        ),
                      ],
                    ),
                    if (_ecoSealRequested) ...[
                      const SizedBox(height: 12),
                      for (final practice in _kEcoPractices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _ecoPractices.contains(practice)
                                  ? _ecoPractices.remove(practice)
                                  : _ecoPractices.add(practice);
                            }),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _ecoPractices.contains(practice)
                                        ? AppColors.accent300
                                        : null,
                                    border: _ecoPractices.contains(practice)
                                        ? null
                                        : Border.all(
                                            color: AppColors.mapControlBorder
                                                .withValues(alpha: 1),
                                          ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: _ecoPractices.contains(practice)
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: AppColors.surface100,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    practice,
                                    style: AppTextStyles.detailServicePill
                                        .copyWith(
                                          color:
                                              _ecoPractices.contains(practice)
                                              ? AppColors.detailBodyBrown
                                              : AppColors.settingsTextMuted,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_ecoPractices.length < 2)
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.settingsBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 16,
                                color: AppColors.settingsTextMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'El sello queda "por verificar" hasta que Níkara confirme al '
                                  'menos dos prácticas.',
                                  style: AppTextStyles.wizardCaption.copyWith(
                                    color: AppColors.detailMutedRow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
                _card(
                  children: [
                    Text(
                      'Actividades del lugar',
                      style: AppTextStyles.wizardCardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Marca todas las que apliquen. Aparecen en tu perfil y en los filtros.',
                      style: AppTextStyles.wizardCaption,
                    ),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final activity in _kActivityPresets)
                          _WizardChip(
                            label: activity,
                            icon: activityIcon(activity),
                            selected: _selectedActivities.contains(activity),
                            onTap: () => setState(() {
                              _selectedActivities.contains(activity)
                                  ? _selectedActivities.remove(activity)
                                  : _selectedActivities.add(activity);
                            }),
                          ),
                        for (final custom in customActivities)
                          _WizardChip(
                            label: activityLabel(custom),
                            icon: activityIcon(custom),
                            selected: true,
                            onTap: () => setState(
                              () => _selectedActivities.remove(custom),
                            ),
                            trailingRemove: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickActivityIcon,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.settingsBackground,
                              border: Border.all(
                                color: AppColors.mapControlBorder,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              activityIconLibrary[_customActivityIconKey],
                              size: 20,
                              color: AppColors.settingsTextDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _WizardTextField(
                            controller: _customActivityController,
                            hint: 'Agregar otra actividad',
                            onSubmitted: (_) => _addCustomActivity(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addCustomActivity,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary500,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 22,
                              color: AppColors.settingsTextDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Toca el ícono para elegir cómo se ve en tu perfil.',
                        style: AppTextStyles.wizardCaption,
                      ),
                    ),
                  ],
                ),
                _card(
                  children: [
                    Text(
                      'Servicios del lugar',
                      style: AppTextStyles.wizardCardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lo que un viajero encuentra al llegar.',
                      style: AppTextStyles.wizardCaption,
                    ),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final amenity in _kAmenityPresets)
                          _WizardChip(
                            label: amenity,
                            icon: amenityIcon(amenity),
                            selected: _selectedAmenities.contains(amenity),
                            onTap: () => setState(() {
                              _selectedAmenities.contains(amenity)
                                  ? _selectedAmenities.remove(amenity)
                                  : _selectedAmenities.add(amenity);
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _WizardFooter(
          primaryLabel: 'Siguiente',
          onPrimary: _nextFromStep3,
          secondaryLabel: 'Atrás',
          onSecondary: () => _goToStep(1),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    final photos = _allPhotoPaths;
    final draft = _draftBusiness();
    final dataComplete =
        _nameController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty;
    return Column(
      children: [
        _header(_isEditing ? 'Último paso' : 'Paso 4 de 4 · último paso'),
        _WizardStepper(step: 3),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionIntro(
                  'Así te verán',
                  'Revisa tu tarjeta antes de enviarla a publicación.',
                ),
                _card(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VISTA PREVIA EN INICIO',
                            style: AppTextStyles.wizardFieldLabel,
                          ),
                          GestureDetector(
                            onTap: _openPreview,
                            child: Text(
                              'Ver perfil completo',
                              style: AppTextStyles.detailInlineLink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _WizardPreviewCard(business: draft, photos: photos),
                  ],
                ),
                _card(
                  children: [
                    Text(
                      'Listo para enviar',
                      style: AppTextStyles.wizardCardTitle,
                    ),
                    const SizedBox(height: 11),
                    _ChecklistRow(
                      done: dataComplete,
                      label: 'Datos generales y contacto',
                      actionLabel: 'Editar',
                      onTap: () => _goToStep(0),
                    ),
                    const SizedBox(height: 8),
                    _ChecklistRow(
                      done: _confirmedLocation != null,
                      label: 'Ubicación y pin confirmado',
                      actionLabel: 'Editar',
                      onTap: () => _goToStep(1),
                    ),
                    const SizedBox(height: 8),
                    _ChecklistRow(
                      done: photos.length >= 5,
                      label:
                          '${photos.length} ${photos.length == 1 ? 'foto' : 'fotos'} en la galería',
                      hint: photos.length >= 5
                          ? null
                          : 'Con 5 o más apareces en Destacados',
                      actionLabel: photos.length >= 5 ? 'Editar' : 'Agregar',
                      onTap: () => _goToStep(2),
                    ),
                  ],
                ),
                _card(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.wizardReviewBadgeBg,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.verified_outlined,
                            size: 18,
                            color: AppColors.wizardAmber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verificación de Níkara',
                              style: AppTextStyles.wizardCardTitle,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              draft.isVerified
                                  ? 'Ya verificado'
                                  : 'Se revisa después de publicar',
                              style: AppTextStyles.wizardCaption,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.settingsBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.visibility,
                            size: 16,
                            color: AppColors.settingsTextMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              draft.isVerified
                                  ? 'Tu negocio ya muestra el sello de verificado en su perfil.'
                                  : 'Tu negocio se publica de inmediato y queda visible para '
                                        'todos; el sello de verificado se agrega después de una '
                                        'revisión manual del equipo de Níkara.',
                              style: AppTextStyles.wizardCaption.copyWith(
                                color: AppColors.detailMutedRow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _WizardFooter(
          primaryLabel: _isSaving
              ? 'Guardando...'
              : (_isEditing ? 'Guardar cambios' : 'Publicar'),
          primaryIcon: _isEditing ? Icons.save_outlined : Icons.send,
          onPrimary: _isSaving ? null : _finish,
          secondaryLabel: 'Vista previa',
          secondaryIcon: Icons.visibility,
          onSecondary: _openPreview,
        ),
      ],
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.profileDivider,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.settingsTextDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.wizardAppBarTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.wizardCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface100,
                border: Border.all(color: AppColors.mapControlBorder),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Salir', style: AppTextStyles.detailPillAction),
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardStepper extends StatelessWidget {
  const _WizardStepper({required this.step});

  final int step;

  static const _labels = ['Datos', 'Ubicación', 'Galería', 'Publicar'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        border: Border.all(color: AppColors.mapControlBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.detailCardGlow,
            offset: Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < _labels.length; i++) ...[
                if (i != 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: i <= step
                          ? AppColors.primary500
                          : AppColors.profileDivider,
                    ),
                  ),
                _StepCircle(index: i, currentStep: step),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (final label in _labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.wizardChipLabel.copyWith(
                      fontSize: 10,
                      color: _labels.indexOf(label) == step
                          ? AppColors.settingsTextDark
                          : AppColors.settingsTextMuted,
                      fontWeight: _labels.indexOf(label) == step
                          ? FontWeight.w800
                          : FontWeight.w700,
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

class _StepCircle extends StatelessWidget {
  const _StepCircle({required this.index, required this.currentStep});

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final isDone = index < currentStep;
    final isActive = index == currentStep;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isDone || isActive)
            ? AppColors.primary500
            : AppColors.surface100,
        border: (isDone || isActive)
            ? null
            : Border.all(color: AppColors.wizardStepInactiveBorder, width: 1.5),
      ),
      child: isDone
          ? const Icon(Icons.check, size: 16, color: AppColors.settingsTextDark)
          : Text(
              '${index + 1}',
              style: AppTextStyles.wizardChipLabel.copyWith(
                fontSize: 12,
                color: isActive
                    ? AppColors.settingsTextDark
                    : AppColors.neutral400,
              ),
            ),
    );
  }
}

class _WizardTextField extends StatelessWidget {
  const _WizardTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: AppTextStyles.wizardFieldValue,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.wizardFieldHint,
        filled: true,
        fillColor: AppColors.settingsBackground,
        counterText: '',
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.settingsTextDark.withValues(alpha: 0.07),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.settingsTextDark.withValues(alpha: 0.07),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.wizardFocus, width: 1.5),
        ),
      ),
    );
  }
}

class _WizardDropdown extends StatelessWidget {
  const _WizardDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.settingsTextDark.withValues(alpha: 0.07),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.expand_more,
            color: AppColors.settingsTextMuted,
          ),
          style: AppTextStyles.wizardFieldValue,
          dropdownColor: AppColors.surface100,
          borderRadius: BorderRadius.circular(16),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _CountryCodeField extends StatelessWidget {
  const _CountryCodeField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.settingsTextDark.withValues(alpha: 0.07),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(
            Icons.expand_more,
            size: 16,
            color: AppColors.settingsTextMuted,
          ),
          style: AppTextStyles.detailPillAction.copyWith(
            color: AppColors.detailBodyBrown,
          ),
          dropdownColor: AppColors.surface100,
          items: [
            for (final code in _kCountryCodes)
              DropdownMenuItem(value: code, child: Text(code)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _SocialField extends StatelessWidget {
  const _SocialField({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.controller,
    required this.hint,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.settingsTextDark.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.wizardFieldValue,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTextStyles.wizardFieldHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.entry,
    required this.onChanged,
    this.onRemove,
  });

  final _ScheduleEntry entry;
  final ValueChanged<_ScheduleEntry> onChanged;
  final VoidCallback? onRemove;

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? entry.start : entry.end,
    );
    if (picked == null) return;
    onChanged(
      isStart
          ? (_ScheduleEntry(
              daysLabel: entry.daysLabel,
              weekdays: entry.weekdays,
              start: picked,
              end: entry.end,
            ))
          : (_ScheduleEntry(
              daysLabel: entry.daysLabel,
              weekdays: entry.weekdays,
              start: entry.start,
              end: picked,
            )),
    );
  }

  Future<void> _pickDays(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in _ScheduleEntry._knownDayLabels.keys)
              ListTile(
                title: Text(label),
                onTap: () => Navigator.of(context).pop(label),
              ),
            ListTile(
              title: const Text('Escribir otro texto'),
              onTap: () => Navigator.of(context).pop(''),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice.isEmpty) return;
    onChanged(
      _ScheduleEntry(
        daysLabel: choice,
        weekdays: _ScheduleEntry._knownDayLabels[choice] ?? const {},
        start: entry.start,
        end: entry.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Column (no Row) para que la etiqueta de día libre y los chips de hora no compitan por el ancho y desborden.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _pickDays(context),
          child: Container(
            width: double.infinity,
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.settingsBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.settingsTextDark.withValues(alpha: 0.07),
              ),
            ),
            child: Text(
              entry.daysLabel,
              style: AppTextStyles.wizardFieldValue.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            GestureDetector(
              onTap: () => _pickTime(context, isStart: true),
              child: _timeChip(_ScheduleEntry._fmt(entry.start)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '–',
                style: TextStyle(color: AppColors.settingsTextMuted),
              ),
            ),
            GestureDetector(
              onTap: () => _pickTime(context, isStart: false),
              child: _timeChip(_ScheduleEntry._fmt(entry.end)),
            ),
            const Spacer(),
            if (onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.settingsTextMuted,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }

  Widget _timeChip(String text) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.settingsTextDark.withValues(alpha: 0.07),
        ),
      ),
      child: Text(
        text,
        style: AppTextStyles.wizardFieldValue.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _OpenNowPill extends StatelessWidget {
  const _OpenNowPill({required this.entries});

  final List<_ScheduleEntry> entries;

  @override
  Widget build(BuildContext context) {
    final open = _ScheduleEntry.isOpenNow(entries);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: open
            ? AppColors.detailActivityIconBg
            : AppColors.segmentedTrackBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: open ? AppColors.accent300 : AppColors.settingsTextMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            open ? 'ABIERTO AHORA' : 'CERRADO AHORA',
            style: AppTextStyles.detailEcoBadge.copyWith(
              color: open ? AppColors.accent300 : AppColors.settingsTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardChip extends StatelessWidget {
  const _WizardChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailingRemove = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool trailingRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.settingsBackground,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: AppColors.mapControlBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected && !trailingRemove
                  ? Icons.check
                  : (icon ?? Icons.circle_outlined),
              size: 15,
              color: selected
                  ? AppColors.settingsTextDark
                  : AppColors.settingsTextMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.wizardChipLabel.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: selected
                      ? AppColors.settingsTextDark
                      : AppColors.detailBodyBrown,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailingRemove) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.close,
                size: 14,
                color: AppColors.settingsTextDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reutilizado tal cual en cada paso del wizard y en el hub de Editar-negocio.
class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.primaryIcon,
    this.secondaryIcon,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final IconData? primaryIcon;
  final IconData? secondaryIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface100,
        border: Border(top: BorderSide(color: AppColors.mapControlBorder)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowAmbient,
            offset: Offset(0, -6),
            blurRadius: 22,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSecondary,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: AppColors.settingsBackground,
                border: Border.all(color: AppColors.mapControlBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (secondaryIcon != null) ...[
                    Icon(
                      secondaryIcon,
                      size: 17,
                      color: AppColors.settingsTextDark,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    secondaryLabel,
                    style: AppTextStyles.wizardFooterSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onPrimary,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: onPrimary == null
                      ? AppColors.primary500.withValues(alpha: 0.5)
                      : AppColors.primary500,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: onPrimary == null
                      ? null
                      : const [
                          BoxShadow(
                            color: AppColors.detailPrimaryButtonGlow,
                            offset: Offset(0, 4),
                            blurRadius: 14,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (primaryIcon != null) ...[
                      Icon(
                        primaryIcon,
                        size: 18,
                        color: AppColors.settingsTextDark,
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      primaryLabel,
                      style: AppTextStyles.wizardFooterPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [onCameraMove] mantiene sincronizado `_mapCenter` del padre porque `google_maps_flutter` no expone un getter síncrono de centro actual.
class _MapLocationPicker extends StatelessWidget {
  const _MapLocationPicker({
    required this.initialCenter,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onTap,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final LatLng initialCenter;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<LatLng> onCameraMove;
  final ValueChanged<LatLng> onTap;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCenter,
                zoom: 15,
              ),
              onMapCreated: onMapCreated,
              onCameraMove: (position) => onCameraMove(position.target),
              onTap: onTap,
              minMaxZoomPreference: const MinMaxZoomPreference(6, 18),
              cameraTargetBounds: CameraTargetBounds(_kMapBounds),
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
            ),
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.surface100, width: 3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.wizardPhotoShadow,
                              offset: Offset(0, 6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 22,
                          color: AppColors.settingsTextDark,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: AppColors.settingsTextDark.withValues(
                            alpha: 0.22,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Column(
                children: [
                  _mapButton(Icons.add, onZoomIn),
                  const SizedBox(height: 6),
                  _mapButton(Icons.remove, onZoomOut),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapCardShadow,
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 17, color: AppColors.settingsTextDark),
      ),
    );
  }
}

/// Refleja el layout real de la tarjeta de Home/Mapa, no es solo decorativa.
class _WizardPreviewCard extends StatelessWidget {
  const _WizardPreviewCard({required this.business, required this.photos});

  final BusinessModel business;
  final List<String> photos;

  bool get _isEco =>
      business.ecoSealRequested ||
      business.category.toLowerCase().contains('eco');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.mapControlBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LocalImage(path: photos.isEmpty ? null : photos.first),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tagGold600,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        business.category,
                        style: AppTextStyles.detailEcoBadge.copyWith(
                          color: AppColors.settingsTextDark,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  if (_isEco)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ecoGreen500,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ECO',
                          style: AppTextStyles.detailEcoBadge.copyWith(
                            color: AppColors.surface100,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface100,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business.name,
                          style: AppTextStyles.quickInfoValue.copyWith(
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 13,
                              color: AppColors.neutral400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                business.city.isEmpty
                                    ? 'Sin ubicación'
                                    : business.city,
                                style: AppTextStyles.wizardCaption.copyWith(
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.settingsBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Ver perfil',
                      style: AppTextStyles.detailPillAction,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.done,
    required this.label,
    required this.actionLabel,
    required this.onTap,
    this.hint,
  });

  final bool done;
  final String label;
  final String? hint;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: done
              ? AppColors.settingsBackground
              : AppColors.wizardReviewBadgeBg,
          borderRadius: BorderRadius.circular(14),
          border: done
              ? null
              : Border.all(
                  color: AppColors.wizardAmber.withValues(alpha: 0.32),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.detailActivityIconBg
                    : AppColors.primary500,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check : Icons.priority_high,
                size: 15,
                color: done ? AppColors.accent300 : AppColors.settingsTextDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.detailActivityLabel.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hint != null)
                    Text(
                      hint!,
                      style: AppTextStyles.wizardCaption.copyWith(
                        color: AppColors.wizardReviewBadgeText,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              actionLabel,
              style: AppTextStyles.detailPillAction.copyWith(
                color: done
                    ? AppColors.settingsTextMuted
                    : AppColors.wizardReviewBadgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityIconPickerSheet extends StatelessWidget {
  const _ActivityIconPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elige un ícono',
              style: AppTextStyles.wizardStepHeading.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 4),
            Text(
              'Se usa para tu actividad y en tu perfil.',
              style: AppTextStyles.wizardCaption,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: activityIconLibrary.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemBuilder: (context, index) {
                  final key = activityIconLibrary.keys.elementAt(index);
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(key),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.settingsBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.mapControlBorder,
                            ),
                          ),
                          child: Icon(
                            activityIconLibrary[key],
                            color: AppColors.accent300,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          activityIconLibraryLabels[key] ?? key,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.wizardCaption.copyWith(
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
