import 'package:flutter/material.dart';

import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/domain/models/admin_business_summary.dart';
import 'package:nikara_app/features/admin/presentation/screens/admin_business_detail_screen.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Drill-down de una tarjeta de [AdminMetricsView]: la misma lista buscable
/// de negocios que la cola de revisión, pero filtrada por lo que esa tarjeta
/// representa en vez de por [ReviewStatus] — "Verificados" filtra por
/// [AdminBusinessSummary.isVerified], no por estado de revisión, así que no
/// puede reusar [AdminReviewView] tal cual.
class AdminBusinessListScreen extends StatefulWidget {
  const AdminBusinessListScreen({
    super.key,
    required this.title,
    required this.filter,
  });

  final String title;
  final bool Function(AdminBusinessSummary business) filter;

  @override
  State<AdminBusinessListScreen> createState() =>
      _AdminBusinessListScreenState();
}

class _AdminBusinessListScreenState extends State<AdminBusinessListScreen> {
  final _service = AdminService();
  final _searchController = TextEditingController();

  List<AdminBusinessSummary>? _businesses;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _businesses = null;
      _error = null;
    });
    try {
      final businesses = await _service.getAllBusinesses();
      if (!mounted) return;
      setState(() => _businesses = businesses);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _openDetail(AdminBusinessSummary business) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminBusinessDetailScreen(business: business),
      ),
    );
    // A diferencia de la cola de revisión, acá no importa que el estado haya
    // cambiado: esta lista no está filtrada por estado, así que la fila sigue
    // perteneciendo a ella. Se recarga igual para reflejar cualquier cambio
    // (ej. verificación) sin esperar un pull-to-refresh manual.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          widget.title,
          style: AppTextStyles.settingsTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
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
    final businesses = _businesses;
    if (businesses == null) return const AdminLoading();

    final scoped = businesses.where(widget.filter).toList(growable: false);
    if (scoped.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.oliveText,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            const AdminPlaceholder(
              icon: Icons.inbox_outlined,
              title: 'No hay negocios en esta métrica',
              message: 'Todavía no hay nada que coincida.',
            ),
          ],
        ),
      );
    }

    final filtered = scoped
        .where((b) => b.matchesQuery(_query))
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
            hintText: 'Buscar por nombre, categoría o ciudad',
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
                            '${filtered.length} '
                            '${filtered.length == 1 ? "negocio" : "negocios"}',
                            style: AppTextStyles.settingsRowCaption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                        );
                      }
                      final business = filtered[index - 1];
                      return AdminBusinessCard(
                        business: business,
                        onTap: () => _openDetail(business),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
