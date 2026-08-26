import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/data/business_storage_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/presentation/screens/business_detail_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_eco_activity_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_organization_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/edit_organization_screen.dart';
import 'package:nikara_app/features/my_business/data/my_business_service.dart';
import 'package:nikara_app/features/my_business/domain/models/managed_item.dart';
import 'package:nikara_app/features/my_business/presentation/widgets/my_business_widgets.dart';
import 'package:nikara_app/features/notifications/data/notification_service.dart';
import 'package:nikara_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Panel de control de lo que administra una cuenta: sus negocios, sus
/// fundaciones y sus jornadas ECO.
///
/// Tier **Funcional**, con **un solo acento de marca: Olive**. El prototipo de
/// Claude Design usa además Gold (la barra destacada del gráfico, la estrella
/// de calificación) y un rosa para el corazón de "guardados". El rosa no existe
/// en los primitivos de la marca, así que no se inventó un token para
/// resolverlo — los íconos de las métricas van en la escala neutra y el único
/// color con significado es el del estado de revisión. Queda como pregunta
/// abierta para José.
///
/// El gráfico "Vistas de la semana" del prototipo tampoco está: depende de un
/// tracking de vistas que todavía no tiene dónde guardarse. Dibujarlo con
/// números inventados sería peor que no dibujarlo.
class MyBusinessScreen extends StatefulWidget {
  const MyBusinessScreen({super.key});

  @override
  State<MyBusinessScreen> createState() => _MyBusinessScreenState();
}

class _MyBusinessScreenState extends State<MyBusinessScreen> {
  final _service = MyBusinessService();

  List<ManagedItem>? _items;
  String? _error;

  /// Id del ítem que se está mirando. Se guarda el id y no el objeto para que
  /// sobreviva a un refresco: tras editar o reenviar, la lista se vuelve a
  /// pedir y los modelos son instancias nuevas.
  String? _selectedId;

  List<DashboardMetric> _metrics = const [];
  bool _loadingMetrics = false;
  bool _busy = false;
  int _unread = 0;

  ManagedItem? get _selected {
    final items = _items;
    if (items == null || items.isEmpty) return null;
    for (final item in items) {
      if (item.id == _selectedId) return item;
    }
    return items.first;
  }

  @override
  void initState() {
    super.initState();
    _load();
    BusinessStorageService.revision.addListener(_onDataChanged);
    NotificationService.revision.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    BusinessStorageService.revision.removeListener(_onDataChanged);
    NotificationService.revision.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  void _onNotificationsChanged() {
    if (mounted) _loadUnread();
  }

  /// Vacía la lista solo en la primera carga.
  ///
  /// En un refresco (pull-to-refresh, o volver de editar) dejarla en null
  /// reemplazaba el dashboard entero por un spinner y hasta el nombre del
  /// negocio desaparecía del encabezado — un parpadeo a pantalla completa por
  /// una recarga que dura menos de un segundo.
  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_items == null || _items!.isEmpty) _items = null;
    });
    try {
      final items = await _service.getManagedItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _selectedId ??= items.isEmpty ? null : items.first.id;
      });
      await _loadMetrics();
      await _loadUnread();
    } on MyBusinessServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _loadMetrics() async {
    final item = _selected;
    if (item == null) {
      setState(() => _metrics = const []);
      return;
    }
    setState(() => _loadingMetrics = true);
    final metrics = await _service.metricsFor(item);
    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _loadingMetrics = false;
    });
  }

  Future<void> _loadUnread() async {
    try {
      final count = await NotificationService().unreadCount();
      if (!mounted) return;
      setState(() => _unread = count);
    } on NotificationServiceException {
      // El badge es accesorio: sin conteo simplemente no se muestra.
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==================== Acciones ====================

  Future<void> _pickItem() async {
    final items = _items;
    if (items == null || items.length < 2) return;
    final picked = await showModalBottomSheet<ManagedItem>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          ManagedItemPickerSheet(items: items, selectedId: _selected?.id),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedId = picked.id);
    await _loadMetrics();
  }

  Future<void> _resubmit() async {
    final item = _selected;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      await _service.resubmit(item);
      if (!mounted) return;
      _snack('Tu solicitud volvió a la cola. La revisamos en 24 horas.');
      await _load();
    } on MyBusinessServiceException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Abre el wizard de negocio en el paso [step] — es el mismo formulario que
  /// registra, reusado para editar, igual que hacía el hub de edición que esta
  /// pantalla reemplazó.
  Future<void> _editBusinessSection(BusinessModel business, int step) async {
    await Navigator.of(context).push<BusinessModel>(
      MaterialPageRoute(
        builder: (_) => RegisterBusinessWizard(
          existingBusiness: business,
          initialStep: step,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openPreview(ManagedItem item) async {
    final business = item.business;
    if (business == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business),
      ),
    );
  }

  Future<void> _editOrganization(ManagedItem item) async {
    final organization = item.organization;
    if (organization == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditOrganizationScreen(organization: organization),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _editActivity(ManagedItem item) async {
    final activity = item.activity;
    if (activity == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEcoActivityScreen(existingActivity: activity),
      ),
    );
    if (!mounted) return;
    await _load();
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
          'Se eliminará "${business.name}" de forma permanente. Esta acción '
          'no se puede deshacer.',
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
      if (!mounted) return;
      setState(() => _selectedId = null);
      await _load();
    } on BusinessServiceException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (!mounted) return;
    await _loadUnread();
  }

  Future<void> _registerFirst() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterBusinessWizard()));
    if (!mounted) return;
    await _load();
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            MyBusinessHeader(
              subtitle: _selected?.name ?? 'Tu panel de control',
              unreadCount: _unread,
              onNotifications: _openNotifications,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return MyBusinessPlaceholder(
        icon: Icons.cloud_off_rounded,
        title: 'No se pudo cargar tu panel',
        message: error,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.oliveText),
      );
    }
    if (items.isEmpty) {
      return MyBusinessPlaceholder(
        icon: Icons.storefront_outlined,
        title: 'Todavía no administras nada',
        message:
            'Registra tu negocio para empezar a recibir viajeros y llevar el '
            'control desde acá.',
        actionLabel: 'Registrar mi negocio',
        onAction: _registerFirst,
      );
    }

    final item = _selected!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.oliveText,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.navBarClearance,
        ),
        children: [
          ManagedItemCard(
            item: item,
            canSwitch: items.length > 1,
            onTap: _pickItem,
          ),
          if (item.reviewStatus.isRechazado)
            ReviewStatusNotice(
              item: item,
              busy: _busy,
              onResubmit: _busy ? null : _resubmit,
            )
          else if (item.reviewStatus.isPendiente)
            ReviewStatusNotice(item: item, busy: _busy, onResubmit: null),
          const SizedBox(height: AppSpacing.xl),
          const MyBusinessSectionTitle(
            title: 'Este mes',
            trailing: 'Últimos 30 días',
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loadingMetrics)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.oliveText),
              ),
            )
          else
            MetricGrid(metrics: _metrics),
          const SizedBox(height: AppSpacing.xl),
          ..._buildManageSection(item),
        ],
      ),
    );
  }

  List<Widget> _buildManageSection(ManagedItem item) {
    return switch (item.kind) {
      ManagedItemKind.business => _businessSection(item),
      ManagedItemKind.organization => [
        const MyBusinessSectionTitle(title: 'Gestionar fundación'),
        const SizedBox(height: AppSpacing.md),
        ManageRow(
          icon: Icons.diversity_3_rounded,
          title: 'Datos de la fundación',
          subtitle: 'Nombre, handle, descripción, logo y portada',
          onTap: () => _editOrganization(item),
        ),
        const SizedBox(height: AppSpacing.sm),
        ManageRow(
          icon: Icons.add_circle_outline_rounded,
          title: 'Registrar otra fundación',
          subtitle: 'Cada una se revisa por separado',
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateOrganizationScreen(),
              ),
            );
            if (mounted) await _load();
          },
        ),
      ],
      ManagedItemKind.ecoActivity => [
        const MyBusinessSectionTitle(title: 'Gestionar jornada'),
        const SizedBox(height: AppSpacing.md),
        ManageRow(
          icon: Icons.edit_outlined,
          title: 'Editar la jornada',
          subtitle: 'Fecha, lugar, cupo, requisitos y portada',
          onTap: () => _editActivity(item),
        ),
      ],
    };
  }

  List<Widget> _businessSection(ManagedItem item) {
    final business = item.business!;
    final photos = business.localImagePaths;
    return [
      const MyBusinessSectionTitle(title: 'Editar perfil público'),
      const SizedBox(height: AppSpacing.md),
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
        onTap: () => _openPreview(item),
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
}
