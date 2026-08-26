import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/admin/data/admin_service.dart';
import 'package:nikara_app/features/admin/domain/models/admin_business_summary.dart';
import 'package:nikara_app/features/admin/presentation/screens/admin_business_detail_screen.dart';
import 'package:nikara_app/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Cola de negocios filtrada por estado de revisión.
///
/// Es la misma vista para las tres colas ("Revisión", "Aprobados",
/// "Rechazados"): lo único que cambia es el filtro y los textos de lista
/// vacía. Tenerlas como una sola clase evita que se separen visualmente con
/// el tiempo, que es exactamente lo que le pasó al badge ECO antes de
/// consolidarse.
class AdminReviewView extends StatefulWidget {
  const AdminReviewView({super.key, required this.status});

  /// Qué cola muestra: `businesses.status` igual a este valor.
  final ReviewStatus status;

  @override
  State<AdminReviewView> createState() => _AdminReviewViewState();
}

class _AdminReviewViewState extends State<AdminReviewView> {
  final _service = AdminService();

  List<AdminBusinessSummary>? _businesses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _businesses = null;
      _error = null;
    });
    try {
      final businesses = await _service.getBusinesses(status: widget.status);
      if (!mounted) return;
      setState(() => _businesses = businesses);
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _openDetail(AdminBusinessSummary business) async {
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

  @override
  Widget build(BuildContext context) {
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
    if (businesses.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.oliveText,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            AdminPlaceholder(
              icon: switch (widget.status) {
                ReviewStatus.aprobado => Icons.verified_outlined,
                ReviewStatus.rechazado => Icons.gpp_maybe_outlined,
                ReviewStatus.pendiente => Icons.inbox_outlined,
              },
              title: switch (widget.status) {
                ReviewStatus.aprobado => 'Todavía no aprobaste ningún negocio',
                ReviewStatus.rechazado => 'No rechazaste ningún negocio',
                ReviewStatus.pendiente => 'No hay nada pendiente',
              },
              message: switch (widget.status) {
                ReviewStatus.aprobado =>
                  'Los negocios que apruebes van a aparecer acá.',
                ReviewStatus.rechazado =>
                  'Los negocios que rechaces quedan acá hasta que su dueño '
                      'los corrija y los vuelva a enviar.',
                ReviewStatus.pendiente =>
                  'Cuando un emprendedor registre un negocio nuevo, te va a '
                      'esperar en esta cola.',
              },
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
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
        itemCount: businesses.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                switch (widget.status) {
                  ReviewStatus.aprobado =>
                    '${businesses.length} '
                        '${businesses.length == 1 ? "negocio publicado" : "negocios publicados"}',
                  ReviewStatus.rechazado =>
                    '${businesses.length} '
                        '${businesses.length == 1 ? "negocio rechazado" : "negocios rechazados"}',
                  ReviewStatus.pendiente =>
                    '${businesses.length} '
                        '${businesses.length == 1 ? "negocio espera" : "negocios esperan"} tu revisión',
                },
                style: AppTextStyles.settingsRowCaption.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
              ),
            );
          }
          final business = businesses[index - 1];
          return _AdminBusinessCard(
            business: business,
            onTap: () => _openDetail(business),
          );
        },
      ),
    );
  }
}

class _AdminBusinessCard extends StatelessWidget {
  const _AdminBusinessCard({required this.business, required this.onTap});

  final AdminBusinessSummary business;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      business.name.isEmpty ? 'Sin nombre' : business.name,
                      style: AppTextStyles.settingsRowTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AdminStatusPill(status: business.reviewStatus),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                business.category.isEmpty
                    ? business.locationLabel
                    : '${business.category} · ${business.locationLabel}',
                style: AppTextStyles.settingsRowCaption.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.settingsTextMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      business.ownerLabel,
                      style: AppTextStyles.settingsRowCaption.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Revisar',
                    style: AppTextStyles.settingsRowCaption.copyWith(
                      color: AppColors.oliveText,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.oliveText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
