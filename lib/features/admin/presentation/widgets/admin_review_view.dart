import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/domain/models/admin_business_summary.dart';
import 'package:nikara_app/features/admin/presentation/screens/admin_business_detail_screen.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Qué tipo de solicitud muestra la cola — negocios, jornadas ECO o
/// fundaciones comparten estado de revisión (`status` en sus tres tablas) y
/// el mismo RPC de aprobar/rechazar, así que es un selector dentro de la
/// misma vista y no tres pestañas nuevas en la barra del panel.
enum _ReviewKind { business, ecoActivity, organization }

extension on _ReviewKind {
  String get label => switch (this) {
    _ReviewKind.business => 'Negocios',
    _ReviewKind.ecoActivity => 'Jornadas',
    _ReviewKind.organization => 'Fundaciones',
  };

  IconData get icon => switch (this) {
    _ReviewKind.business => Icons.storefront_outlined,
    _ReviewKind.ecoActivity => Icons.eco_outlined,
    _ReviewKind.organization => Icons.groups_outlined,
  };
}

/// Cola filtrada por estado de revisión (`widget.status`), para los tres
/// tipos de solicitud a la vez.
///
/// Es la misma vista para las tres colas ("Revisión", "Aprobados",
/// "Rechazados") y para los tres tipos: lo único que cambia es el filtro de
/// estado, el tipo activo y los textos de lista vacía. Tenerla como una sola
/// clase evita que se separen visualmente con el tiempo, que es exactamente
/// lo que le pasó al badge ECO antes de consolidarse.
///
/// Negocios se abre en su propia ficha de revisión
/// ([AdminBusinessDetailScreen]) porque `BusinessModel` fusiona campos que
/// solo existen en el caché local del dispositivo del dueño — pedirle el
/// modelo completo a un negocio desde el dispositivo de un admin devolvería
/// campos vacíos (ver `admin_business_summary.dart`). Jornadas y fundaciones
/// no tienen ese problema, así que se abren en sus pantallas públicas reales
/// (`EcoDetailScreen`/`OrganizationProfileScreen`), con la franja de
/// aprobar/rechazar ([AdminInlineReviewCard]) agregada ahí.
class AdminReviewView extends StatefulWidget {
  const AdminReviewView({
    super.key,
    required this.status,
    this.active = true,
    this.refreshToken = 0,
  });

  /// Qué cola muestra: el `status` de la tabla activa debe ser igual a este.
  final ReviewStatus status;

  /// Si esta cola es la pestaña visible ahora mismo.
  ///
  /// `AdminShellScreen` mantiene las 3 colas vivas dentro de un
  /// `IndexedStack` (para no perder el scroll al ir y volver), así que
  /// `initState`/`_load` solo corren una vez, cuando el panel se abre —
  /// rechazar un negocio desde "Revisión" nunca haría aparecer esa fila en
  /// "Rechazados" hasta un pull-to-refresh manual, porque esa pestaña ya
  /// estaba montada con su snapshot viejo. `didUpdateWidget` detecta el
  /// flanco false→true (se volvió la pestaña activa) y recarga. Bug real
  /// encontrado en la auditoría del 2026-09-05 probando el ciclo completo
  /// aprobar/rechazar en el dispositivo.
  final bool active;

  /// Sube al tocar el botón de recarga del encabezado del panel — fuerza un
  /// `_load()` sin importar si esta pestaña ya estaba activa.
  final int refreshToken;

  @override
  State<AdminReviewView> createState() => _AdminReviewViewState();
}

class _AdminReviewViewState extends State<AdminReviewView> {
  final _service = AdminService();
  final _searchController = TextEditingController();

  _ReviewKind _kind = _ReviewKind.business;
  String _query = '';
  String? _error;

  List<AdminBusinessSummary>? _businesses;
  List<EcoActivityModel>? _activities;
  List<OrganizationModel>? _organizations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justActivated = widget.active && !oldWidget.active;
    final refreshed =
        widget.active && widget.refreshToken != oldWidget.refreshToken;
    if (justActivated || refreshed) _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    switch (_kind) {
      case _ReviewKind.business:
        setState(() => _businesses = null);
        try {
          final businesses = await _service.getBusinesses(
            status: widget.status,
          );
          if (!mounted) return;
          setState(() => _businesses = businesses);
        } on AdminServiceException catch (e) {
          if (!mounted) return;
          setState(() => _error = e.message);
        }
      case _ReviewKind.ecoActivity:
        setState(() => _activities = null);
        try {
          final all = await _service.getEcoActivitiesForAdmin();
          if (!mounted) return;
          setState(
            () => _activities = all
                .where((a) => a.reviewStatus == widget.status)
                .toList(growable: false),
          );
        } on AdminServiceException catch (e) {
          if (!mounted) return;
          setState(() => _error = e.message);
        }
      case _ReviewKind.organization:
        setState(() => _organizations = null);
        try {
          final all = await _service.getOrganizations();
          if (!mounted) return;
          setState(
            () => _organizations = all
                .where((o) => o.reviewStatus == widget.status)
                .toList(growable: false),
          );
        } on AdminServiceException catch (e) {
          if (!mounted) return;
          setState(() => _error = e.message);
        }
    }
  }

  void _selectKind(_ReviewKind kind) {
    if (kind == _kind) return;
    _searchController.clear();
    setState(() {
      _kind = kind;
      _query = '';
    });
    _load();
  }

  Future<void> _openBusiness(AdminBusinessSummary business) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminBusinessDetailScreen(business: business),
      ),
    );
    // El detalle devuelve `true` cuando cambió el estado: la fila ya no
    // pertenece a esta cola, así que se recarga en vez de mutar la lista en
    // memoria (que dejaría una tarjeta "Publicado" dentro de Pendientes).
    if (changed == true && mounted) await _load();
  }

  Future<void> _openActivity(EcoActivityModel activity) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EcoDetailScreen(activity: activity)),
    );
    // EcoDetailScreen no devuelve si cambió (a diferencia de la ficha de
    // negocios): recarga siempre al volver, es la misma consulta barata que
    // ya corre en pull-to-refresh.
    if (mounted) await _load();
  }

  Future<void> _openOrganization(OrganizationModel organization) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrganizationProfileScreen(organization: organization),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: _KindSelector(selected: _kind, onSelected: _selectKind),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AdminPlaceholder(
        icon: Icons.cloud_off_rounded,
        title: 'No se pudo cargar la lista',
        message: _error!,
        onRetry: _load,
      );
    }
    return switch (_kind) {
      _ReviewKind.business => _buildList<AdminBusinessSummary>(
        items: _businesses,
        matches: (b, q) => b.matchesQuery(q),
        cardBuilder: (b) =>
            AdminBusinessCard(business: b, onTap: () => _openBusiness(b)),
        searchHint: 'Buscar por nombre, categoría o ciudad',
        countLabel: (count) => switch (widget.status) {
          ReviewStatus.aprobado =>
            '$count ${count == 1 ? "negocio publicado" : "negocios publicados"}',
          ReviewStatus.rechazado =>
            '$count ${count == 1 ? "negocio rechazado" : "negocios rechazados"}',
          ReviewStatus.pendiente =>
            '$count ${count == 1 ? "negocio espera" : "negocios esperan"} tu revisión',
        },
        emptyIcon: switch (widget.status) {
          ReviewStatus.aprobado => Icons.verified_outlined,
          ReviewStatus.rechazado => Icons.gpp_maybe_outlined,
          ReviewStatus.pendiente => Icons.inbox_outlined,
        },
        emptyTitle: switch (widget.status) {
          ReviewStatus.aprobado => 'Todavía no aprobaste ningún negocio',
          ReviewStatus.rechazado => 'No rechazaste ningún negocio',
          ReviewStatus.pendiente => 'No hay nada pendiente',
        },
        emptyMessage: switch (widget.status) {
          ReviewStatus.aprobado =>
            'Los negocios que apruebes van a aparecer acá.',
          ReviewStatus.rechazado =>
            'Los negocios que rechaces quedan acá hasta que su dueño los '
                'corrija y los vuelva a enviar.',
          ReviewStatus.pendiente =>
            'Cuando un emprendedor registre un negocio nuevo, te va a '
                'esperar en esta cola.',
        },
      ),
      _ReviewKind.ecoActivity => _buildList<EcoActivityModel>(
        items: _activities,
        matches: (a, q) => a.matchesQuery(q),
        cardBuilder: (a) =>
            AdminEcoActivityCard(activity: a, onTap: () => _openActivity(a)),
        searchHint: 'Buscar por título, categoría o ubicación',
        countLabel: (count) => switch (widget.status) {
          ReviewStatus.aprobado =>
            '$count ${count == 1 ? "jornada publicada" : "jornadas publicadas"}',
          ReviewStatus.rechazado =>
            '$count ${count == 1 ? "jornada rechazada" : "jornadas rechazadas"}',
          ReviewStatus.pendiente =>
            '$count ${count == 1 ? "jornada espera" : "jornadas esperan"} tu revisión',
        },
        emptyIcon: switch (widget.status) {
          ReviewStatus.aprobado => Icons.verified_outlined,
          ReviewStatus.rechazado => Icons.gpp_maybe_outlined,
          ReviewStatus.pendiente => Icons.inbox_outlined,
        },
        emptyTitle: switch (widget.status) {
          ReviewStatus.aprobado => 'Todavía no aprobaste ninguna jornada',
          ReviewStatus.rechazado => 'No rechazaste ninguna jornada',
          ReviewStatus.pendiente => 'No hay nada pendiente',
        },
        emptyMessage: switch (widget.status) {
          ReviewStatus.aprobado =>
            'Las jornadas que apruebes van a aparecer acá.',
          ReviewStatus.rechazado =>
            'Las jornadas que rechaces quedan acá hasta que se corrijan y '
                'se vuelvan a enviar.',
          ReviewStatus.pendiente =>
            'Cuando una fundación publique una jornada nueva, te va a '
                'esperar en esta cola.',
        },
      ),
      _ReviewKind.organization => _buildList<OrganizationModel>(
        items: _organizations,
        matches: (o, q) => o.matchesQuery(q),
        cardBuilder: (o) => AdminOrganizationCard(
          organization: o,
          onTap: () => _openOrganization(o),
        ),
        searchHint: 'Buscar por nombre o handle',
        countLabel: (count) => switch (widget.status) {
          ReviewStatus.aprobado =>
            '$count ${count == 1 ? "fundación publicada" : "fundaciones publicadas"}',
          ReviewStatus.rechazado =>
            '$count ${count == 1 ? "fundación rechazada" : "fundaciones rechazadas"}',
          ReviewStatus.pendiente =>
            '$count ${count == 1 ? "fundación espera" : "fundaciones esperan"} tu revisión',
        },
        emptyIcon: switch (widget.status) {
          ReviewStatus.aprobado => Icons.verified_outlined,
          ReviewStatus.rechazado => Icons.gpp_maybe_outlined,
          ReviewStatus.pendiente => Icons.inbox_outlined,
        },
        emptyTitle: switch (widget.status) {
          ReviewStatus.aprobado => 'Todavía no aprobaste ninguna fundación',
          ReviewStatus.rechazado => 'No rechazaste ninguna fundación',
          ReviewStatus.pendiente => 'No hay nada pendiente',
        },
        emptyMessage: switch (widget.status) {
          ReviewStatus.aprobado =>
            'Las fundaciones que apruebes van a aparecer acá.',
          ReviewStatus.rechazado =>
            'Las fundaciones que rechaces quedan acá hasta que se corrijan '
                'y se vuelvan a enviar.',
          ReviewStatus.pendiente =>
            'Cuando alguien registre una fundación nueva, te va a esperar '
                'en esta cola.',
        },
      ),
    };
  }

  /// Esqueleto compartido por los tres tipos: buscador + lista + estados
  /// vacíos. Cada tipo solo aporta sus datos, su tarjeta y sus textos.
  Widget _buildList<T>({
    required List<T>? items,
    required bool Function(T item, String query) matches,
    required Widget Function(T item) cardBuilder,
    required String searchHint,
    required String Function(int count) countLabel,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
  }) {
    if (items == null) return const AdminLoading();
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.oliveText,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            AdminPlaceholder(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
            ),
          ],
        ),
      );
    }

    final filtered = items
        .where((item) => matches(item, _query))
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: AdminSearchField(
            controller: _searchController,
            hintText: searchHint,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? AdminPlaceholder(
                  icon: Icons.search_off_rounded,
                  title: 'Sin resultados',
                  message: 'Nada coincide con "$_query".',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.oliveText,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            countLabel(filtered.length),
                            style: AppTextStyles.settingsRowCaption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                        );
                      }
                      return cardBuilder(filtered[index - 1]);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Fila de chips para elegir qué tipo de solicitud muestra la cola —
/// mismo patrón visual que `_RoleFilterBar` de `admin_users_view.dart`.
class _KindSelector extends StatelessWidget {
  const _KindSelector({required this.selected, required this.onSelected});

  final _ReviewKind selected;
  final ValueChanged<_ReviewKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final kind in _ReviewKind.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _KindChip(
                kind: kind,
                selected: kind == selected,
                onTap: () => onSelected(kind),
              ),
            ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final _ReviewKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.oliveFill : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.oliveFill : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              kind.icon,
              size: 15,
              color: selected
                  ? AppColors.textPrimary
                  : AppColors.settingsTextMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              kind.label,
              style: AppTextStyles.settingsRowCaption.copyWith(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.settingsTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
