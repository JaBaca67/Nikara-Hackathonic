import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/profile_face.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/features/eco/data/eco_service.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_eco_activity_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/edit_organization_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/features/my_business/data/my_business_service.dart';
import 'package:nikara_app/features/my_business/domain/models/managed_item.dart';
import 'package:nikara_app/features/my_business/presentation/widgets/my_business_widgets.dart';
import 'package:nikara_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// El perfil de una cara de **negocio** o **fundación**: la misma pestaña
/// Perfil, con otra identidad puesta.
///
/// Usa la plantilla del perfil de turista como base estructural
/// ([ProfileHeaderShell]) para que las dos caras se lean como la misma pantalla
/// con distinto contenido. Reemplaza al dashboard "Mi negocio", que vivía en
/// una sexta pestaña ya retirada: su selector agrupado (NEGOCIO / FUNDACIÓN /
/// JORNADA ECO) desapareció porque ahora la selección la hace el cambio de
/// cara, no un control dentro de la pantalla.
///
/// **No muestra estado de solicitud**: una cara solo existe si ya fue aprobada
/// (ver [ProfileFace]). Lo pendiente y lo rechazado vive en "Estado de
/// solicitudes", dentro de Ajustes.
///
/// ## Excepción de tier autorizada
///
/// Tier **Funcional**, que admite un solo `Fill` de marca visible. Esta
/// pantalla muestra Gold y Olive a la vez en la fila de estadísticas y es la
/// **segunda excepción autorizada**, después del módulo ECO, por la misma
/// razón: cada color comunica una categoría distinta de dato, no decora —
/// **dorado = reputación** (calificación, reseñas), **oliva = comunidad**
/// (guardados, voluntarios, jornadas) y **neutro apagado = todavía no
/// disponible**, así el color mismo dice "Próximamente" sin depender de que
/// alguien lea la leyenda. La correspondencia vive en [MetricAccent]. **No se
/// generaliza a otras pantallas.**
///
/// No entran colores nuevos: el rosa del prototipo quedó descartado y el
/// naranja no existe como familia de marca desde la auditoría del 2026-08-25.
/// El sistema son dos acentos, Gold y Olive.
class FaceProfileScreen extends StatefulWidget {
  const FaceProfileScreen({
    super.key,
    required this.face,
    required this.onFaceTap,
    required this.onSettingsTap,
  });

  /// La cara activa. Siempre de negocio o fundación: la de turista la dibuja
  /// `ProfileScreen`.
  final ProfileFace face;

  /// Abre la hoja de caras — el mismo control provisional de la cabecera del
  /// perfil de turista.
  final VoidCallback onFaceTap;

  final VoidCallback onSettingsTap;

  @override
  State<FaceProfileScreen> createState() => _FaceProfileScreenState();
}

class _FaceProfileScreenState extends State<FaceProfileScreen> {
  final _service = MyBusinessService();

  List<DashboardMetric> _headline = const [];
  bool _loadingStats = true;
  String? _error;

  /// Solo en la cara de fundación: las jornadas que organiza, cada una con su
  /// propio estado de revisión (que una fundación esté aprobada no le da
  /// libertad de publicar sin revisión).
  List<EcoActivityModel> _activities = const [];

  ManagedItem get _item {
    final business = widget.face.business;
    if (business != null) return ManagedItem.fromBusiness(business);
    return ManagedItem.fromOrganization(widget.face.organization!);
  }

  bool get _isOrganization => widget.face.kind == ProfileFaceKind.organization;

  // PROVISIONAL (Fase B, 2026-08-27): toggle de anfitrión post-publicación.
  // Estado local optimista porque `widget.face` es inmutable — el próximo
  // `ProfileFaceService().load()` (paso 5 de la sesión de Caras) lo alinea
  // con el servidor de todas formas.
  late bool _showHost = widget.face.business?.showHost ?? true;

  @override
  void initState() {
    super.initState();
    _load();
    BusinessStorageService.revision.addListener(_onDataChanged);
    EcoService.revision.addListener(_onDataChanged);
  }

  @override
  void didUpdateWidget(covariant FaceProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cambiar de una cara de negocio a otra reusa este State: sin esto la
    // pantalla se quedaría con los números de la cara anterior.
    if (oldWidget.face.id != widget.face.id) {
      _showHost = widget.face.business?.showHost ?? true;
      _load();
    }
  }

  Future<void> _toggleShowHost(BusinessModel business, bool value) async {
    setState(() => _showHost = value);
    try {
      await BusinessStorageService().updateBusiness(
        business.copyWith(showHost: value),
      );
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() => _showHost = !value);
      _snack(e.message);
    }
  }

  @override
  void dispose() {
    BusinessStorageService.revision.removeListener(_onDataChanged);
    EcoService.revision.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingStats = true;
      _error = null;
    });

    final headline = await _service.headlineStatsFor(_item);
    var activities = const <EcoActivityModel>[];
    String? error;
    if (_isOrganization) {
      try {
        activities = await EcoService().getActivitiesByOrganization(
          widget.face.id,
        );
      } on EcoServiceException catch (e) {
        // Falla suave: la fundación sigue siendo administrable aunque el feed
        // de jornadas no responda.
        error = e.message;
      }
    }
    if (!mounted) return;
    setState(() {
      _headline = headline;
      _activities = activities;
      _error = error;
      _loadingStats = false;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== Acciones ====================

  /// Abre el wizard de negocio en el paso [step] — es el mismo formulario que
  /// registra, reusado para editar.
  Future<void> _editBusinessSection(BusinessModel business, int step) async {
    await Navigator.of(context).push<BusinessModel>(
      MaterialPageRoute(
        builder: (_) => RegisterBusinessWizard(
          existingBusiness: business,
          initialStep: step,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openBusinessPreview(BusinessModel business) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business),
      ),
    );
  }

  Future<void> _openOrganizationPreview() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            OrganizationProfileScreen(organization: widget.face.organization),
      ),
    );
  }

  Future<void> _editOrganization() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EditOrganizationScreen(organization: widget.face.organization!),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openActivity(EcoActivityModel activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EcoDetailScreen(activity: activity)),
    );
    if (mounted) await _load();
  }

  Future<void> _editActivity(EcoActivityModel? activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEcoActivityScreen(existingActivity: activity),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _confirmDeleteBusiness(BusinessModel business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          '¿Eliminar negocio?',
          style: AppTextStyles.settingsTitle.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Se eliminará "${business.name}" de forma permanente, y con él este '
          'perfil. Esta acción no se puede deshacer.',
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.settingsRowValue.copyWith(
                color: AppColors.settingsTextMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Eliminar',
              style: AppTextStyles.settingsRowTitle.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await BusinessStorageService().deleteBusiness(business.id);
    } on BusinessServiceException catch (e) {
      if (mounted) _snack(e.message);
    }
    // Al desaparecer el negocio desaparece su cara; `ProfileFaceService` vuelve
    // a turista sola en la próxima recarga y `ProfileScreen` se encarga.
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final face = widget.face;

    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: Column(
        children: [
          // Sin esto la franja del status bar mostraría el fondo del Scaffold
          // en vez de continuar el surface100 de la cabecera.
          Container(
            height: MediaQuery.paddingOf(context).top,
            color: AppColors.surface100,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.navBarClearance,
                ),
                children: [
                  ProfileHeaderShell(
                    actions: [
                      ProfileHeaderIconButton(
                        icon: Icons.visibility_outlined,
                        label: 'Ver como lo ven los viajeros',
                        onTap: _openPreview,
                      ),
                      ProfileHeaderIconButton(
                        icon: Icons.settings_outlined,
                        label: 'Ajustes',
                        onTap: widget.onSettingsTap,
                      ),
                    ],
                    avatar: ProfileFaceAvatar(
                      imageUrl: face.imageUrl,
                      initials: face.initials,
                      fallbackIcon: face.imageUrl == null
                          ? face.kind.icon
                          : null,
                      label: _isOrganization
                          ? 'Editar el logo de la fundación'
                          : 'Editar las fotos del negocio',
                      onTap: _editImage,
                    ),
                    faceControl: FaceSelectorControl(
                      name: face.name,
                      kindLabel: face.kind.label,
                      onTap: widget.onFaceTap,
                    ),
                    stats: [
                      for (final metric in _headline)
                        ProfileStat(
                          value: metric.value,
                          label: metric.label,
                          icon: metric.icon,
                          tint: metricAccentColor(metric.accent),
                        ),
                    ],
                  ),
                  if (_loadingStats)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.oliveText,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MetricGrid(metrics: _service.metricsFor(_item)),
                        const SizedBox(height: AppSpacing.xl),
                        ..._isOrganization
                            ? _organizationSections()
                            : _businessSections(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPreview() {
    final business = widget.face.business;
    if (business != null) return _openBusinessPreview(business);
    return _openOrganizationPreview();
  }

  /// El avatar de esta cara no cambia una foto de perfil (no hay tal cosa en un
  /// negocio): lleva al mismo formulario donde vive su imagen.
  Future<void> _editImage() {
    final business = widget.face.business;
    if (business != null) return _editBusinessSection(business, 2);
    return _editOrganization();
  }

  List<Widget> _businessSections() {
    final business = widget.face.business!;
    final photos = business.localImagePaths;
    return [
      const MyBusinessSectionTitle(title: 'Editar perfil público'),
      const SizedBox(height: AppSpacing.md),
      // PROVISIONAL (Fase B, 2026-08-27): toggle directo acá, en vez de
      // mandar al wizard, para que quede claro que esto NO reabre revisión —
      // es presentación, no algo que el equipo verificó.
      Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.profileDivider,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mostrarme como anfitrión',
                      style: AppTextStyles.settingsRowTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tu perfil aparece en el detalle público',
                      style: AppTextStyles.settingsRowCaption.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _showHost,
                onChanged: (v) => _toggleShowHost(business, v),
                activeThumbColor: AppColors.surface100,
                activeTrackColor: AppColors.primary500,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      ManageRow(
        icon: Icons.storefront_rounded,
        title: 'Datos generales y contacto',
        subtitle: 'Nombre, categoría, descripción, WhatsApp',
        onTap: () => _editBusinessSection(business, 0),
      ),
      const SizedBox(height: AppSpacing.sm),
      ManageRow(
        icon: Icons.location_on_outlined,
        title: 'Ubicación y pin en el mapa',
        subtitle: business.city.isEmpty ? 'Sin ubicación' : business.city,
        badge: 'REVISIÓN',
        onTap: () => _editBusinessSection(business, 1),
      ),
      const SizedBox(height: AppSpacing.sm),
      ManageRow(
        icon: Icons.photo_library_outlined,
        title: 'Galería y atributos ECO',
        subtitle:
            '${photos.length} ${photos.length == 1 ? 'foto' : 'fotos'} · '
            '${business.ecoSealRequested ? 'sello ECO activo' : 'sin sello ECO'}',
        badge: 'REVISIÓN',
        onTap: () => _editBusinessSection(business, 2),
      ),
      const SizedBox(height: AppSpacing.sm),
      ManageRow(
        icon: Icons.schedule_rounded,
        title: 'Horarios de atención',
        subtitle: business.schedules.isEmpty
            ? 'Sin horarios cargados'
            : business.schedules,
        onTap: () => _editBusinessSection(business, 0),
      ),
      const SizedBox(height: AppSpacing.sm),
      ManageRow(
        icon: Icons.visibility_outlined,
        title: 'Ver como lo ven los viajeros',
        subtitle: 'Abre tu perfil público tal cual se publica',
        onTap: () => _openBusinessPreview(business),
      ),
      const SizedBox(height: AppSpacing.xl),
      Center(
        child: TextButton(
          onPressed: () => _confirmDeleteBusiness(business),
          child: Text(
            'Eliminar este negocio',
            style: AppTextStyles.body.copyWith(
              color: AppColors.destructive,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.destructive,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _organizationSections() {
    return [
      const MyBusinessSectionTitle(title: 'Editar perfil público'),
      const SizedBox(height: AppSpacing.md),
      ManageRow(
        icon: Icons.diversity_3_rounded,
        title: 'Datos de la fundación',
        subtitle: 'Nombre, handle, descripción, logo y portada',
        onTap: _editOrganization,
      ),
      const SizedBox(height: AppSpacing.sm),
      ManageRow(
        icon: Icons.visibility_outlined,
        title: 'Ver como lo ven los viajeros',
        subtitle: 'Abre tu perfil público tal cual se publica',
        onTap: _openOrganizationPreview,
      ),
      const SizedBox(height: AppSpacing.xl),
      MyBusinessSectionTitle(
        title: 'Tus jornadas ECO',
        trailing: _activities.isEmpty
            ? null
            : '${_activities.length} '
                  '${_activities.length == 1 ? 'jornada' : 'jornadas'}',
      ),
      const SizedBox(height: AppSpacing.md),
      if (_error != null)
        Text(
          _error!,
          style: AppTextStyles.body.copyWith(
            color: AppColors.settingsTextMuted,
          ),
        )
      else if (_activities.isEmpty)
        Text(
          'Todavía no publicaste ninguna jornada. Cada una se revisa por '
          'separado antes de aparecer en ECO.',
          style: AppTextStyles.body.copyWith(
            color: AppColors.settingsTextMuted,
          ),
        )
      else
        for (final activity in _activities) ...[
          _ActivityRow(
            activity: activity,
            onOpen: () => _openActivity(activity),
            onEdit: () => _editActivity(activity),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      const SizedBox(height: AppSpacing.sm),
      ManageRow(
        icon: Icons.add_circle_outline_rounded,
        title: 'Crear una jornada',
        subtitle: 'Se publica tras la revisión del equipo Níkara',
        onTap: () => _editActivity(null),
      ),
    ];
  }
}

/// Una jornada de la fundación, con su propio estado de revisión.
///
/// Toda la fila abre el detalle —que es donde se ven los inscritos— y el lápiz
/// va aparte: son dos destinos distintos y meterlos en el mismo toque obligaría
/// a elegir cuál gana.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.onOpen,
    required this.onEdit,
  });

  final EcoActivityModel activity;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final item = ManagedItem.fromActivity(activity);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ManagedItemThumb(item: item, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: AppTextStyles.settingsRowTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.subtitle} · ${activity.participantCount} '
                      '${activity.participantCount == 1 ? 'inscrito' : 'inscritos'}',
                      style: AppTextStyles.settingsRowCaption.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ReviewStatusPill(status: activity.reviewStatus),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Editar la jornada',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.settingsTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
