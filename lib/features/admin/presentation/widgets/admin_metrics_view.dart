import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/domain/models/admin_metrics.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Métricas globales de la plataforma — **solo admin**.
///
/// Es una de las dos vistas que un auditor no ve nunca (la otra es Usuarios):
/// esa es la diferencia concreta y visible entre los dos roles de moderación,
/// no una etiqueta distinta sobre la misma pantalla.
class AdminMetricsView extends StatefulWidget {
  const AdminMetricsView({super.key});

  @override
  State<AdminMetricsView> createState() => _AdminMetricsViewState();
}

class _AdminMetricsViewState extends State<AdminMetricsView> {
  final _service = AdminService();

  AdminMetrics? _metrics;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _metrics = null;
      _error = null;
    });
    try {
      final metrics = await _service.getMetrics();
      if (!mounted) return;
      setState(() => _metrics = metrics);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AdminPlaceholder(
        icon: Icons.insights_outlined,
        title: 'No se pudieron cargar las métricas',
        message: _error!,
        onRetry: _load,
      );
    }
    final metrics = _metrics;
    if (metrics == null) return const AdminLoading();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.oliveText,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          const AdminSectionLabel(label: 'Negocios'),
          _TileGrid(
            children: [
              AdminStatTile(
                label: 'Pendientes de verificar',
                value: '${metrics.pendingBusinesses}',
                icon: Icons.schedule_rounded,
                highlight: metrics.pendingBusinesses > 0,
              ),
              AdminStatTile(
                label: 'Verificados',
                value: '${metrics.verifiedBusinesses}',
                icon: Icons.verified_outlined,
              ),
              AdminStatTile(
                label: 'Total registrados',
                value: '${metrics.totalBusinesses}',
                icon: Icons.storefront_outlined,
              ),
              AdminStatTile(
                label: 'Cobertura verificada',
                value: _percent(
                  metrics.verifiedBusinesses,
                  metrics.totalBusinesses,
                ),
                caption: 'del total registrado',
                icon: Icons.donut_small_outlined,
              ),
            ],
          ),
          const AdminSectionLabel(label: 'Comunidad ECO'),
          _TileGrid(
            children: [
              AdminStatTile(
                label: 'Jornadas publicadas',
                value: '${metrics.totalEcoActivities}',
                icon: Icons.eco_outlined,
              ),
              AdminStatTile(
                label: 'Jornadas por venir',
                value: '${metrics.upcomingEcoActivities}',
                caption: 'con fecha futura',
                icon: Icons.event_available_outlined,
              ),
              AdminStatTile(
                label: 'Organizaciones',
                value: '${metrics.totalOrganizations}',
                icon: Icons.groups_outlined,
              ),
              AdminStatTile(
                label: 'Organizaciones sin verificar',
                value: '${metrics.pendingOrganizations}',
                icon: Icons.pending_outlined,
                highlight: metrics.pendingOrganizations > 0,
              ),
            ],
          ),
          const AdminSectionLabel(label: 'Usuarios por rol'),
          _TileGrid(
            children: [
              for (final role in UserRole.values)
                AdminStatTile(
                  label: role.label,
                  value: '${metrics.usersWithRole(role)}',
                  caption: role.permissionsSummary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Total de cuentas: ${metrics.totalUsers}',
            style: AppTextStyles.settingsRowCaption.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  static String _percent(int part, int total) {
    if (total == 0) return '—';
    return '${(part * 100 / total).round()}%';
  }
}

/// Rejilla de dos columnas.
///
/// Va con [Wrap] y ancho calculado en vez de `GridView`: las tarjetas tienen
/// altura variable (el caption de rol es de dos líneas) y un `GridView` con
/// `childAspectRatio` fijo desbordaría con los textos más largos.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children)
              SizedBox(width: columnWidth, child: child),
          ],
        );
      },
    );
  }
}
