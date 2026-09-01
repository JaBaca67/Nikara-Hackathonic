import 'package:flutter/material.dart';

import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/organization_profile_screen.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Drill-down de la tarjeta "Organizaciones" de [AdminMetricsView]: todas las
/// fundaciones (cualquier estado), con buscador, misma idea que
/// [AdminBusinessListScreen] pero sobre [OrganizationModel].
class AdminOrganizationListScreen extends StatefulWidget {
  const AdminOrganizationListScreen({super.key});

  @override
  State<AdminOrganizationListScreen> createState() =>
      _AdminOrganizationListScreenState();
}

class _AdminOrganizationListScreenState
    extends State<AdminOrganizationListScreen> {
  final _service = AdminService();
  final _searchController = TextEditingController();

  List<OrganizationModel>? _organizations;
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
      _organizations = null;
      _error = null;
    });
    try {
      final organizations = await _service.getOrganizations();
      if (!mounted) return;
      setState(() => _organizations = organizations);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Organizaciones',
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
    final organizations = _organizations;
    if (organizations == null) return const AdminLoading();
    if (organizations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.oliveText,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            const AdminPlaceholder(
              icon: Icons.groups_outlined,
              title: 'Todavía no hay fundaciones',
              message: 'Las que se registren van a aparecer acá.',
            ),
          ],
        ),
      );
    }

    final filtered = organizations
        .where((o) => o.matchesQuery(_query))
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
            hintText: 'Buscar por nombre o handle',
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
                            '${filtered.length == 1 ? "fundación" : "fundaciones"}',
                            style: AppTextStyles.settingsRowCaption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                        );
                      }
                      final organization = filtered[index - 1];
                      return AdminOrganizationCard(
                        organization: organization,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrganizationProfileScreen(
                              organizationId: organization.id,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
