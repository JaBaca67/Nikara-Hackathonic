import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/services/location_service.dart';
import 'package:nikara_app/features/admin/presentation/screens/admin_shell_screen.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/legal_identity_gate_screen.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/home/presentation/widgets/search_header_widget.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';
import 'package:nikara_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/category_icons_row.dart';
import 'package:nikara_app/shared/widgets/eco_badge.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/face_guard_bottom_sheet.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Cuántas tarjetas muestra la grilla "Explorá todos" antes de pedir "Cargar
/// más". Seis son tres filas de dos, suficiente para que se entienda que hay
/// una grilla sin alargar el scroll de Inicio de entrada.
const int _kGridPageSize = 6;

enum _SortMode { recientes, cercanos }

/// "N km" desde [from] al negocio, o `null` si no hay posición disponible (sin permiso, GPS apagado, o [from] aún no resolvió).
String? _distanceLabel(Position? from, BusinessModel business) {
  final km = LocationService.distanceKm(
    from,
    business.latitude,
    business.longitude,
  );
  return km == null ? null : '${km.toStringAsFixed(0)} km';
}

/// Pantalla "Inicio" (Figma nodo 124:37). Todo debajo del header es 100% dinámico desde [BusinessStorageService] — sin nombres, precios ni distancias mock.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _photoRotationInterval = Duration(seconds: 5);

  final _businessStorageService = BusinessStorageService();
  final _heroPageController = PageController();
  final _searchController = TextEditingController();
  List<BusinessModel>? _businesses;
  String? _loadError;
  String? _userName;
  UserRole _role = UserRole.turista;
  Position? _userPosition;

  /// No leídas del usuario actual; 0 para invitados (no tienen bandeja).
  int _unreadNotifications = 0;

  Timer? _photoTimer;
  int _heroIndex = 0;
  int _heroPhotoIndex = 0;

  /// Categoría real seleccionada en el filtro (una de
  /// [kBusinessCategoryPresets]); null es "Todos".
  ///
  /// Se filtra vía [businessCategoryPresetFor] y no por igualdad literal con
  /// `businesses.category` porque esa columna es libre: hoy conviven las
  /// categorías del wizard actual ("Hospedaje", "Eco-destino") con las de
  /// los datos semilla, redactadas distinto ("Artesanía y Alfarería",
  /// "Cultura y Patrimonio"), así que un filtro por igualdad exacta parte en
  /// dos un mismo rubro.
  String? _selectedCategory;

  /// Cuántas tarjetas de la grilla están visibles ahora mismo.
  int _gridLimit = _kGridPageSize;

  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.recientes;

  /// Se abre recién tras el primer load exitoso (mismo criterio que
  /// `MapScreen`), para no mantener un socket realtime en pantallas que
  /// nunca llegaron a cargar. Antes de esto, un negocio registrado desde
  /// otra cuenta/dispositivo solo aparecía en Inicio si esta pantalla se
  /// reconstruía por otra razón (ej. editar el propio negocio).
  Future<void> Function()? _unsubscribeBusinessChanges;

  /// Hasta 5 negocios, los más recientes primero.
  List<BusinessModel> get _heroBusinesses {
    final businesses = _businesses;
    if (businesses == null || businesses.isEmpty) return const [];
    return businesses.reversed.take(5).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    // Home queda vivo pero fuera de pantalla en el IndexedStack de
    // MainLayout, así que sin este listener un negocio editado no se
    // refleja aquí hasta reiniciar la app.
    BusinessStorageService.revision.addListener(_onBusinessesChanged);
    // Mismo motivo que el listener de negocios: Home no se reconstruye al
    // volver del detalle de una jornada o del panel de admin, así que el
    // badge quedaría desactualizado tras cualquier escritura en la tabla.
    NotificationService.revision.addListener(_onNotificationsChanged);
    _loadBusinesses();
    _loadUserName();
    _loadPosition();
    _loadUnreadNotifications();
  }

  @override
  void dispose() {
    BusinessStorageService.revision.removeListener(_onBusinessesChanged);
    NotificationService.revision.removeListener(_onNotificationsChanged);
    unawaited(_unsubscribeBusinessChanges?.call());
    _photoTimer?.cancel();
    _heroPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _gridLimit = _kGridPageSize;
    });
  }

  void _onBusinessesChanged() {
    if (!mounted) return;
    _loadBusinesses();
  }

  void _onNotificationsChanged() {
    if (!mounted) return;
    _loadUnreadNotifications();
  }

  /// El badge es informativo: si la consulta falla, Inicio sigue usable con el
  /// contador en 0. El error no se traga en silencio (queda en el log de
  /// depuración) pero tampoco interrumpe la pantalla con un SnackBar, que
  /// sería ruido para algo que el usuario ni pidió.
  Future<void> _loadUnreadNotifications() async {
    if (GuestSessionService().isGuest || !AuthService().isLoggedIn) {
      if (mounted && _unreadNotifications != 0) {
        setState(() => _unreadNotifications = 0);
      }
      return;
    }
    try {
      final count = await NotificationService().unreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = count);
    } on NotificationServiceException catch (e) {
      debugPrint('No se pudo leer el contador de notificaciones: ${e.message}');
      if (!mounted) return;
      setState(() => _unreadNotifications = 0);
    }
  }

  Future<void> _openNotifications() async {
    await pushSharedAxis(context, const NotificationsScreen());
    // La pantalla marca como leídas las que se tocaron; al volver el badge
    // tiene que reflejarlo aunque el usuario no haya escrito nada más.
    await _loadUnreadNotifications();
  }

  Future<void> _loadUserName() async {
    if (GuestSessionService().isGuest || !AuthService().isLoggedIn) return;
    final profile = await AuthService().getCurrentProfile();
    if (!mounted || profile == null) return;
    setState(() {
      _userName = profile.firstName;
      _role = profile.role;
    });
  }

  void _openAdminPanel() {
    pushSharedAxis(context, const AdminShellScreen());
  }

  Future<void> _loadPosition() async {
    final position = await LocationService().getCurrentPosition();
    if (!mounted || position == null) return;
    setState(() => _userPosition = position);
  }

  Future<void> _loadBusinesses() async {
    setState(() => _loadError = null);
    try {
      final businesses = await _businessStorageService.getBusinesses();
      if (!mounted) return;
      setState(() {
        _businesses = businesses;
        _heroIndex = 0;
        _heroPhotoIndex = 0;
      });
      _restartPhotoTimer();
      _unsubscribeBusinessChanges ??= _businessStorageService
          .subscribeToBusinessChanges(_onBusinessesChanged);
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    }
  }

  /// Rota solo las fotos del negocio activo; cambiar de negocio es manual (swipe).
  void _restartPhotoTimer() {
    _photoTimer?.cancel();
    final heroBusinesses = _heroBusinesses;
    if (heroBusinesses.isEmpty) return;
    final activeIndex = _heroIndex.clamp(0, heroBusinesses.length - 1);
    final photoCount = heroBusinesses[activeIndex].localImagePaths.length;
    if (photoCount <= 1) return;
    _photoTimer = Timer.periodic(_photoRotationInterval, (_) {
      if (!mounted) return;
      setState(() {
        _heroPhotoIndex = (_heroPhotoIndex + 1) % photoCount;
      });
    });
  }

  void _onHeroPageChanged(int index) {
    setState(() {
      _heroIndex = index;
      _heroPhotoIndex = 0;
    });
    _restartPhotoTimer();
  }

  void _selectHeroPhoto(int index) {
    setState(() => _heroPhotoIndex = index);
    _restartPhotoTimer();
  }

  void _openBusinessDetail(BusinessModel business) {
    pushSharedAxis(context, BusinessDetailScreen(business: business));
  }

  void _openWizard() => openBusinessRegistrationFlow(context);

  /// Búsqueda básica: coincide si el texto aparece en el nombre, la ciudad o
  /// la categoría, sin distinguir mayúsculas — mismo criterio simple que ya
  /// usa `MapScreen` para su propia barra de búsqueda.
  List<BusinessModel> _searchFiltered(List<BusinessModel> businesses) {
    if (_searchQuery.isEmpty) return businesses;
    final query = _searchQuery.toLowerCase();
    return businesses
        .where(
          (b) =>
              b.name.toLowerCase().contains(query) ||
              b.city.toLowerCase().contains(query) ||
              b.category.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  List<BusinessModel> _visibleBusinesses(List<BusinessModel> businesses) {
    final searched = _searchFiltered(businesses);
    final category = _selectedCategory;
    final filtered = category == null
        ? searched
        : searched
              .where((b) => businessCategoryPresetFor(b.category) == category)
              .toList();
    if (_sortMode == _SortMode.recientes) {
      return filtered.reversed.toList(growable: false);
    }
    final withDistance = [...filtered];
    withDistance.sort((a, b) {
      final da = LocationService.distanceKm(
        _userPosition,
        a.latitude,
        a.longitude,
      );
      final db = LocationService.distanceKm(
        _userPosition,
        b.latitude,
        b.longitude,
      );
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return withDistance;
  }

  Future<void> _openFilterSheet() async {
    final mode = await showModalBottomSheet<_SortMode>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SortSheet(current: _sortMode),
    );
    if (mode == null || !mounted) return;
    setState(() => _sortMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final businesses = _businesses;

    return Scaffold(
      backgroundColor: AppColors.background,
      // PROVISIONAL (2026-08-27): antes había un SafeArea(top: true) envolviendo
      // todo el body, así que la barra de estado del teléfono se pintaba con
      // AppColors.background (beige) y quedaba una costura de color contra
      // SearchHeaderWidget, que es surface100 (blanco) — un tono distinto justo
      // debajo. Igual que en map_screen, el elemento visual real (acá el header
      // blanco) llega hasta y=0 y absorbe la barra de estado en vez de dejar que
      // el Scaffold pinte una franja aparte; el padding de MediaQuery empuja el
      // contenido del header, no un SafeArea que recorta todo el body.
      body: Column(
        children: [
          SearchHeaderWidget(
            userName: _userName,
            isGuest: GuestSessionService().isGuest || !AuthService().isLoggedIn,
            controller: _searchController,
            onSearchChanged: _onSearchChanged,
            notificationCount: _unreadNotifications,
            onNotificationTap: _openNotifications,
            onFilterTap: _openFilterSheet,
            // Siempre el catálogo completo, haya o no negocios de esa
            // categoría hoy: el carrusel representa lo que un negocio
            // *puede* registrar, no lo que ya existe. Filtrar por presencia
            // haría que el filtro cambiara de ancho solo porque alguien
            // registró o borró un negocio, que es peor que mostrar una
            // categoría sin resultados (pedido explícito de José).
            categoryContent: businesses == null || businesses.isEmpty
                ? null
                : CategoryIconsRow(
                    categories: kBusinessCategoryPresets,
                    iconBuilder: businessCategoryIcon,
                    selected: _selectedCategory,
                    onSelect: _selectCategory,
                  ),
          ),
          Expanded(
            child: _loadError != null
                ? _LoadErrorState(
                    message: _loadError!,
                    onRetry: _loadBusinesses,
                  )
                : businesses == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary500,
                    ),
                  )
                : businesses.isEmpty
                ? _EmptyState(onRegister: _openWizard)
                : _buildFeed(businesses),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(List<BusinessModel> businesses) {
    final heroBusinesses = _heroBusinesses;
    final heroIndex = heroBusinesses.isEmpty
        ? 0
        : _heroIndex.clamp(0, heroBusinesses.length - 1);
    final visible = _visibleBusinesses(businesses);

    // El realtime de `_unsubscribeBusinessChanges` cubre negocios de otras
    // cuentas; este gesto es el reload explícito que pidió el usuario para
    // forzar un refresh manual sin esperar al socket.
    return RefreshIndicator(
      onRefresh: _loadBusinesses,
      color: AppColors.primary500,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        // Margen extra porque MainLayout usa extendBody: true y la barra de
        // navegación flotante se superpone al final del scroll.
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_role.canAccessAdminPanel)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _AdminAccessBanner(role: _role, onTap: _openAdminPanel),
              ),
            if (heroBusinesses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: _HeroCarousel(
                    controller: _heroPageController,
                    businesses: heroBusinesses,
                    activeIndex: heroIndex,
                    photoIndex: _heroPhotoIndex,
                    onPageChanged: _onHeroPageChanged,
                    onSelectPhoto: _selectHeroPhoto,
                    onTapDetail: _openBusinessDetail,
                  ),
                ),
              ),
            _DestacadosSection(
              businesses: visible,
              userPosition: _userPosition,
              onTap: _openBusinessDetail,
              onSeeAll: _selectedCategory == null
                  ? null
                  : () => setState(() {
                      _selectedCategory = null;
                      _gridLimit = _kGridPageSize;
                    }),
            ),
            // Recibe `visible` y no la lista completa: así respeta el filtro
            // de categoría y la búsqueda, igual que las otras dos secciones.
            // Antes ignoraba ambos y mostraba lo más cercano aunque no
            // tuviera nada que ver con lo que el usuario estaba filtrando.
            if (_userPosition case final position?)
              _CercaDeTiSection(
                businesses: visible,
                userPosition: position,
                onTap: _openBusinessDetail,
              ),
            // Cierra el feed con todo lo que hay.
            //
            // Es además la red de seguridad del layout: "Cerca de ti"
            // desaparece entera sin GPS, así que sin esta grilla un usuario
            // que niegue el permiso de ubicación solo vería los carruseles
            // horizontales.
            _ExploreGridSection(
              businesses: visible,
              userPosition: _userPosition,
              limit: _gridLimit,
              onTap: _openBusinessDetail,
              onLoadMore: () => setState(() => _gridLimit += _kGridPageSize),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de acceso al panel de revisión, visible solo para admin/auditor.
/// Reusa el acento Olive del propio encabezado de [AdminShellScreen] para que
/// se lea como la misma identidad, no como un tercer acento de marca nuevo.
class _AdminAccessBanner extends StatelessWidget {
  const _AdminAccessBanner({required this.role, required this.onTap});

  final UserRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.oliveFill,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 22,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Panel de ${role.label}',
                      style: AppTextStyles.homeCardTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Revisar negocios y actividades pendientes',
                      style: AppTextStyles.homeCardLocation.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final _SortMode current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ordenar por', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            _SortOption(
              label: 'Más recientes',
              selected: current == _SortMode.recientes,
              onTap: () => Navigator.of(context).pop(_SortMode.recientes),
            ),
            _SortOption(
              label: 'Más cercanos',
              selected: current == _SortMode.cercanos,
              onTap: () => Navigator.of(context).pop(_SortMode.cercanos),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      title: Text(label),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary500 : AppColors.neutral400,
      ),
    );
  }
}

/// Banner destacado deslizable manualmente sobre los negocios más recientes. El marco [ClipRRect] es estático; solo el [PageView] interior cambia de página, para que un swipe nunca parezca una segunda tarjeta entrando desde el borde.
class _HeroCarousel extends StatelessWidget {
  const _HeroCarousel({
    required this.controller,
    required this.businesses,
    required this.activeIndex,
    required this.photoIndex,
    required this.onPageChanged,
    required this.onSelectPhoto,
    required this.onTapDetail,
  });

  static const _height = 224.0;

  final PageController controller;
  final List<BusinessModel> businesses;
  final int activeIndex;
  final int photoIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSelectPhoto;
  final ValueChanged<BusinessModel> onTapDetail;

  @override
  Widget build(BuildContext context) {
    // El padding/borde redondeado los aplica el padre (_buildFeed); esto solo llena ese marco.
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: PageView.builder(
        controller: controller,
        itemCount: businesses.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final business = businesses[index];
          final isActive = index == activeIndex;
          return _HeroCard(
            business: business,
            photoIndex: isActive ? photoIndex : 0,
            onSelectPhoto: onSelectPhoto,
            onTap: () => onTapDetail(business),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.business,
    required this.photoIndex,
    required this.onSelectPhoto,
    required this.onTap,
  });

  final BusinessModel business;
  final int photoIndex;
  final ValueChanged<int> onSelectPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photos = business.localImagePaths;
    final safeIndex = photos.isEmpty
        ? 0
        : photoIndex.clamp(0, photos.length - 1);
    final imagePath = photos.isEmpty ? null : photos[safeIndex];
    final isEco = business.category.toLowerCase().contains('eco');

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.largeDuration,
            child: LocalImage(
              key: ValueKey('${business.id}-$safeIndex'),
              path: imagePath,
              fallbackIcon: Icons.storefront_outlined,
              fallbackIconSize: 40,
            ),
          ),
          // Degradado oscuro solo en la parte inferior para que el texto/thumbnails sean legibles.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 1 - (150 / _HeroCarousel._height), 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.detailCoverScrimBottom,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tagGold600,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                business.category,
                style: AppTextStyles.homeHeroPill.copyWith(
                  color: AppColors.settingsTextDark,
                ),
              ),
            ),
          ),
          if (isEco)
            const Positioned(
              right: AppSpacing.lg - 2,
              top: AppSpacing.lg - 2,
              child: EcoBadge(size: EcoBadgeSize.large),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(business.name, style: AppTextStyles.homeHeroTitle),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me,
                      size: 13,
                      color: AppColors.surface100,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${business.city} · Nicaragua',
                        style: AppTextStyles.homeHeroLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (photos.length > 1)
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final selected = index == safeIndex;
                              return GestureDetector(
                                onTap: () => onSelectPhoto(index),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.surface100
                                          : AppColors.surface100.withValues(
                                              alpha: 0.35,
                                            ),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                    child: LocalImage(
                                      path: photos[index],
                                      fallbackIconSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface100.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: AppColors.surface100.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                            child: Text(
                              'Ver detalle →',
                              style: AppTextStyles.homeCtaPill,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestacadosSection extends StatelessWidget {
  const _DestacadosSection({
    required this.businesses,
    required this.userPosition,
    required this.onTap,
    required this.onSeeAll,
  });

  final List<BusinessModel> businesses;
  final Position? userPosition;
  final ValueChanged<BusinessModel> onTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Destacados',
                    style: AppTextStyles.homeSectionTitle,
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text('Ver todos', style: AppTextStyles.homeSeeMore),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (businesses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                'Ningún negocio coincide con esta categoría.',
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.neutral600,
                ),
              ),
            )
          else
            SizedBox(
              // 96 de imagen + 55 del bloque de texto (padding 11+12, título
              // 16, gap 2, ubicación 14). Con 220 el ListView estiraba la
              // tarjeta y el `Ink` pintaba ~69dp de blanco vacío bajo el
              // texto; la proporción resultante (63.6% imagen) es la misma
              // del prototipo de Claude Design.
              height: 151,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                physics: const ClampingScrollPhysics(),
                itemCount: businesses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  return _DestacadoCard(
                    business: business,
                    distanceLabel: _distanceLabel(userPosition, business),
                    onTap: () => onTap(business),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DestacadoCard extends StatelessWidget {
  const _DestacadoCard({
    required this.business,
    required this.distanceLabel,
    required this.onTap,
  });

  final BusinessModel business;

  /// "N km", o `null` sin posición disponible. La ciudad se trunca con
  /// ellipsis si hace falta espacio, pero la distancia nunca — es el dato
  /// que el usuario necesita ver completo.
  final String? distanceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const width = 196.0;
    final imagePath = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : null;
    final locationLabel = distanceLabel == null
        ? business.city
        : '${business.city} · $distanceLabel';

    return Semantics(
      button: true,
      label: '${business.name}, $locationLabel',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: width,
            decoration: BoxDecoration(
              // Sin este relleno el `boxShadow` dorado de abajo se pinta sobre
              // el Material en vez de detrás y tiñe la tarjeta de crema.
              color: AppColors.surface100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.mapControlBorder),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardGlowSoft,
                  offset: Offset(0, 2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LocalImage(
                          path: imagePath,
                          fallbackIcon: Icons.storefront_outlined,
                        ),
                        if (business.category.isNotEmpty)
                          Positioned(
                            left: 8,
                            top: 8,
                            // Reemplaza al EcoBadge genérico: la categoría ya
                            // dice "Eco-destino" cuando aplica, así que un
                            // segundo pill "ECO" encima sería redundante.
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.tagGold600,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  business.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.homeMiniBadge.copyWith(
                                    color: AppColors.settingsTextDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: _FavoriteButton(
                            businessId: business.id,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        business.name,
                        style: AppTextStyles.homeCardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 12,
                            color: AppColors.settingsTextMuted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              business.city,
                              style: AppTextStyles.homeCardLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (distanceLabel != null)
                            Text(
                              ' · $distanceLabel',
                              style: AppTextStyles.homeCardLocation,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            'Ver detalle →',
                            style: AppTextStyles.homeSeeMore,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Cerca de ti": lista ordenada por distancia real. Solo se renderiza si hay posición GPS; sin ella no existe la sección en vez de mostrar distancias inventadas.
/// "Cerca de ti": carrusel horizontal ordenado por distancia real.
///
/// Solo existe si hay posición GPS — sin ella no hay "cerca", y mostrar la
/// sección con distancias inventadas sería peor que no mostrarla. El listado
/// completo sin GPS lo cubre [_ExploreGridSection].
///
/// Pasó de lista vertical a carrusel para que las tres secciones de negocios
/// de Inicio (Destacados, esta y Explorá todos) tengan la misma gramática:
/// dos carruseles para recorrer y una grilla para abarcar. En vertical, con
/// cinco filas apiladas, era la sección que más scroll consumía.
class _CercaDeTiSection extends StatelessWidget {
  const _CercaDeTiSection({
    required this.businesses,
    required this.userPosition,
    required this.onTap,
  });

  final List<BusinessModel> businesses;
  final Position userPosition;
  final ValueChanged<BusinessModel> onTap;

  /// Ocho y no cinco: al scrollear en horizontal el costo de uno más es un
  /// gesto, no una pantalla entera de scroll.
  static const _maxItems = 8;

  List<BusinessModel> get _nearest {
    final withDistance = [...businesses]
      ..removeWhere((b) => b.latitude == null || b.longitude == null)
      ..sort((a, b) {
        final da = LocationService.distanceKm(
          userPosition,
          a.latitude,
          a.longitude,
        )!;
        final db = LocationService.distanceKm(
          userPosition,
          b.latitude,
          b.longitude,
        )!;
        return da.compareTo(db);
      });
    return withDistance.take(_maxItems).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final nearest = _nearest;
    // Con el filtro de categoría puesto puede no quedar nada con
    // coordenadas; entonces la sección no se dibuja en vez de mostrar un
    // título sobre un vacío.
    if (nearest.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text('Cerca de ti', style: AppTextStyles.homeSectionTitle),
          ),
          const SizedBox(height: 8),
          SizedBox(
            // Misma altura que Destacados: las dos filas son el mismo
            // componente con otro criterio de orden, y cualquier diferencia
            // de alto se leería como un error de alineación.
            height: 151,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              physics: const ClampingScrollPhysics(),
              itemCount: nearest.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final business = nearest[index];
                return _DestacadoCard(
                      business: business,
                      distanceLabel: _distanceLabel(userPosition, business),
                      onTap: () => onTap(business),
                    )
                    .animate(delay: AppMotion.microDuration * index)
                    .fadeIn(
                      duration: AppMotion.standardDuration,
                      curve: AppMotion.enter,
                    )
                    .slideX(
                      begin: 0.08,
                      duration: AppMotion.standardDuration,
                      curve: AppMotion.enter,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de favorito sobre la foto — protegido por [GuestGuard] y sincronizado vía [FavoritesService.idsNotifier] con otras pantallas.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.businessId, this.size = 30});

  final String businessId;

  /// 30 en la card de Destacados, 32 en la fila Cerca-de-ti (Pantalla 2a).
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritesService().idsNotifier,
      builder: (context, ids, _) {
        final isFavorite = ids.contains(businessId);
        return GestureDetector(
          onTap: () async {
            if (!await GuestGuard.allow(context, GuestFeature.favoritos)) {
              return;
            }
            if (!context.mounted) return;
            if (!await FaceGuard.allow(context, FaceLimitedAction.favoritos)) {
              return;
            }
            if (!context.mounted) return;
            try {
              await FavoritesService().toggleFavorite(businessId);
            } on FavoritesServiceException catch (e) {
              if (!context.mounted) return;
              AppSnackbar.showError(context, e.message);
            }
          },
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.profileDivider,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 14,
              color: isFavorite
                  ? AppColors.favoriteActive
                  : AppColors.settingsTextMuted,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 44,
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no hay negocios registrados en Níkara',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Sé la primera persona en dar a conocer tu negocio turístico '
              'a toda la comunidad.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRegister,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Registrar mi Negocio'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.textInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: AppTextStyles.buttonLg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Se muestra en vez del feed cuando falla la carga (problema de red/Supabase, no "aún sin negocios" — eso es [_EmptyState]). [message] ya viene traducido al español.
class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: AppColors.destructive,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No se pudieron cargar los negocios',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: AppColors.textInk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: AppTextStyles.buttonLg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Explorá todos": grilla de dos columnas con paginación, debajo del
/// carrusel de Destacados.
///
/// Resuelve un problema concreto del layout anterior: el único listado
/// completo de negocios era "Cerca de ti", que toma como mucho 5 y
/// **desaparece entera sin posición GPS**. Un usuario que negara el permiso
/// de ubicación solo veía el carrusel horizontal y nada más, por muchos
/// negocios que hubiera registrados. Esta sección no depende del GPS: la
/// distancia es un dato opcional de cada tarjeta, no la condición para
/// mostrarla.
class _ExploreGridSection extends StatelessWidget {
  const _ExploreGridSection({
    required this.businesses,
    required this.userPosition,
    required this.limit,
    required this.onTap,
    required this.onLoadMore,
  });

  final List<BusinessModel> businesses;
  final Position? userPosition;
  final int limit;
  final ValueChanged<BusinessModel> onTap;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (businesses.isEmpty) return const SizedBox.shrink();

    final visible = businesses.take(limit).toList(growable: false);
    final hasMore = businesses.length > visible.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Explorá todos',
                    style: AppTextStyles.homeSectionTitle,
                  ),
                ),
                Text(
                  '${businesses.length}',
                  style: AppTextStyles.homeSeeMore.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: GridView.builder(
              // Vive dentro del scroll de Inicio, así que no scrollea por su
              // cuenta: se deja medir completa.
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                // Alto fijo en vez de `childAspectRatio`: lo que necesita la
                // tarjeta depende del texto, no del ancho de la pantalla, así
                // que un ratio se desborda en pantallas angostas.
                mainAxisExtent: 196,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final business = visible[index];
                return _ExploreCard(
                  business: business,
                  distanceLabel: _distanceLabel(userPosition, business),
                  onTap: () => onTap(business),
                );
              },
            ),
          ),
          if (hasMore) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: OutlinedButton(
                onPressed: onLoadMore,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  'Cargar más perfiles',
                  style: AppTextStyles.homeSeeMore.copyWith(
                    color: AppColors.settingsTextDark,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de la grilla. Más compacta que [_DestacadoCard] porque entra de a
/// dos por fila.
class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.business,
    required this.distanceLabel,
    required this.onTap,
  });

  final BusinessModel business;

  /// "N km", o `null` sin posición disponible. Igual que en [_DestacadoCard]:
  /// la ciudad se trunca con ellipsis si hace falta, la distancia nunca.
  final String? distanceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = business.localImagePaths.isNotEmpty
        ? business.localImagePaths.first
        : business.logoUrl;
    final categoryLabel =
        businessCategoryPresetFor(business.category) ?? 'Otros';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: LocalImage(
                    path: cover,
                    fallbackIcon: Icons.storefront_outlined,
                  ),
                ),
                // El badge de categoría dice de qué es la tarjeta sin tener
                // que leer el nombre — misma categoría real que el filtro de
                // Inicio, no la familia (más gruesa) de los pines del Mapa.
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldFill,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          businessCategoryIcon(categoryLabel),
                          size: 11,
                          // Sobre un Fill de marca va tinta oscura.
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          categoryLabel,
                          style: AppTextStyles.homeMiniBadge.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: _FavoriteButton(businessId: business.id, size: 28),
                ),
                if (business.ecoSealRequested)
                  const Positioned(
                    bottom: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: EcoBadge(),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      business.name,
                      style: AppTextStyles.homeCardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: AppColors.settingsTextMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            business.city,
                            style: AppTextStyles.homeCardLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceLabel != null)
                          Text(
                            ' · $distanceLabel',
                            style: AppTextStyles.homeCardLocation,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
