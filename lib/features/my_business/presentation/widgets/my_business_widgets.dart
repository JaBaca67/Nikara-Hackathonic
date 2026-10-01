import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/my_business/data/my_business_service.dart';
import 'package:nikara_app/features/my_business/domain/models/managed_item.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Miniatura con fallback al ícono del tipo — una jornada sin portada y un
/// negocio sin fotos son casos normales, no errores.
class ManagedItemThumb extends StatelessWidget {
  const ManagedItemThumb({super.key, required this.item, required this.size});

  final ManagedItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = item.imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null || path.isEmpty
            ? Container(
                color: AppColors.profileDivider,
                alignment: Alignment.center,
                child: Icon(
                  item.kind.icon,
                  size: size * 0.45,
                  color: AppColors.settingsTextMuted,
                ),
              )
            : LocalImage(path: path, fit: BoxFit.cover),
      ),
    );
  }
}

/// Píldora del estado de revisión. Mismos criterios de color que
/// `AdminStatusPill` del panel: relleno claro con texto oscuro, Olive como
/// único acento de marca y el token `error` —que no cuenta como acento— para
/// el rechazo.
class ReviewStatusPill extends StatelessWidget {
  const ReviewStatusPill({super.key, required this.status});

  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (status) {
      ReviewStatus.aprobado => (
        AppColors.oliveFill,
        AppColors.textPrimary,
        Icons.check_circle_rounded,
      ),
      ReviewStatus.rechazado => (
        AppColors.error.withValues(alpha: 0.12),
        AppColors.error,
        Icons.gpp_maybe_rounded,
      ),
      ReviewStatus.pendiente => (
        AppColors.profileDivider,
        AppColors.settingsTextMuted,
        Icons.schedule_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.label,
            style: AppTextStyles.homeMiniBadge.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Aviso de que lo que se está mirando todavía no es público, con el motivo si
/// fue rechazado y el botón para volver a mandarlo a revisión.
class ReviewStatusNotice extends StatelessWidget {
  const ReviewStatusNotice({
    super.key,
    required this.item,
    required this.busy,
    required this.onResubmit,
  });

  final ManagedItem item;
  final bool busy;
  final VoidCallback? onResubmit;

  @override
  Widget build(BuildContext context) {
    final rejected = item.reviewStatus.isRechazado;
    final reason = item.rejectionReason?.trim() ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: rejected
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: rejected
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                rejected
                    ? Icons.gpp_maybe_rounded
                    : Icons.hourglass_top_rounded,
                size: 18,
                color: rejected ? AppColors.error : AppColors.settingsTextMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rejected
                      ? 'Necesita ajustes para publicarse'
                      : 'En revisión — te avisamos en 24 horas',
                  style: AppTextStyles.settingsRowTitle.copyWith(
                    color: rejected ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (rejected && reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              reason,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ],
          if (rejected) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: busy ? null : onResubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.oliveFill,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: Text(
                  busy ? 'Enviando...' : 'Corrige y vuelve a enviar',
                  style: AppTextStyles.buttonMd.copyWith(
                    color: AppColors.textPrimary,
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

class MyBusinessSectionTitle extends StatelessWidget {
  const MyBusinessSectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final trailingText = trailing;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.detailSectionTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailingText != null)
          Text(
            trailingText,
            style: AppTextStyles.settingsRowCaption.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
      ],
    );
  }
}

/// El color de una categoría de métrica.
///
/// Vive acá y no en `MyBusinessService` porque el servicio declara **qué
/// significa** el dato ([MetricAccent]) y la UI decide con qué token se pinta.
Color metricAccentColor(MetricAccent accent) => switch (accent) {
  MetricAccent.reputation => AppColors.goldFill,
  MetricAccent.community => AppColors.oliveText,
  MetricAccent.inactive => AppColors.settingsTextMuted,
};

/// Grid 2×N de métricas.
///
/// Altura fija por tarjeta y no `IntrinsicHeight`: todas tienen que medir lo
/// mismo aunque una traiga leyenda ("Próximamente") y la otra no.
///
/// La altura sale de la proporción 1.35 **con un piso**: el contenido de la
/// tarjeta (ícono, número, etiqueta y leyenda) mide siempre lo mismo, así que
/// en un teléfono de 320dp la proporción sola dejaba la tarjeta ~7px más corta
/// que su contenido y desbordaba. Arriba de ~360dp el piso no interviene y el
/// render es idéntico al de antes.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.metrics});

  static const _minTileHeight = 112.0;

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - AppSpacing.md) / 2;
        final tileHeight = math.max(tileWidth / 1.35, _minTileHeight);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Sin esto el grid hereda `primary: true` y le suma el padding
          // inferior del sistema (la barra de gestos), que dentro de un
          // ListView aparece como ~150dp de hueco muerto antes de la sección
          // siguiente.
          padding: EdgeInsets.zero,
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            mainAxisExtent: tileHeight,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final muted = metric.accent == MetricAccent.inactive;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(metric.icon, size: 20, color: metricAccentColor(metric.accent)),
          Text(
            metric.value,
            style: AppTextStyles.h4.copyWith(
              color: muted
                  ? AppColors.settingsTextMuted
                  : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: AppTextStyles.settingsRowCaption.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (metric.caption != null)
                Text(
                  metric.caption!,
                  style: AppTextStyles.homeMiniBadge.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila de gestión: el mismo lenguaje que las filas de Ajustes, con el badge
/// "REVISIÓN" en lo que vuelve a mandar el negocio a la cola al tocarse.
class ManageRow extends StatelessWidget {
  const ManageRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final badgeText = badge;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
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
                child: Icon(icon, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTextStyles.settingsRowTitle.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.profileDivider,
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              badgeText,
                              style: AppTextStyles.homeMiniBadge.copyWith(
                                color: AppColors.settingsTextMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.settingsRowCaption.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.settingsTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío o de error del dashboard.
class MyBusinessPlaceholder extends StatelessWidget {
  const MyBusinessPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Icon(icon, size: 48, color: AppColors.settingsTextMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.detailSectionTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.settingsTextMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.oliveFill,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                actionLabel,
                style: AppTextStyles.buttonMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
