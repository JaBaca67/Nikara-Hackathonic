import 'package:flutter/material.dart';

import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_detail_screen.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Drill-down de la tarjeta "Jornadas publicadas" de [AdminMetricsView]: todas
/// las jornadas ECO (cualquier estado), con buscador, misma idea que
/// [AdminBusinessListScreen] pero sobre [EcoActivityModel].
class AdminEcoActivityListScreen extends StatefulWidget {
  const AdminEcoActivityListScreen({super.key});

  @override
  State<AdminEcoActivityListScreen> createState() =>
      _AdminEcoActivityListScreenState();
}

class _AdminEcoActivityListScreenState
    extends State<AdminEcoActivityListScreen> {
  final _service = AdminService();
  final _searchController = TextEditingController();

  List<EcoActivityModel>? _activities;
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
      _activities = null;
      _error = null;
    });
    try {
      final activities = await _service.getEcoActivitiesForAdmin();
      if (!mounted) return;
      setState(() => _activities = activities);
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
          'Jornadas publicadas',
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
    final activities = _activities;
    if (activities == null) return const AdminLoading();
    if (activities.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.oliveText,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            const AdminPlaceholder(
              icon: Icons.eco_outlined,
              title: 'Todavía no hay jornadas',
              message: 'Las que se publiquen van a aparecer acá.',
            ),
          ],
        ),
      );
    }

    final filtered = activities
        .where((a) => a.matchesQuery(_query))
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
            hintText: 'Buscar por título, categoría o ubicación',
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
                            '${filtered.length == 1 ? "jornada" : "jornadas"}',
                            style: AppTextStyles.settingsRowCaption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                        );
                      }
                      final activity = filtered[index - 1];
                      return AdminEcoActivityCard(
                        activity: activity,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EcoDetailScreen(activity: activity),
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
