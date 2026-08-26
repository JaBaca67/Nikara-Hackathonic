import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/my_business/data/my_business_service.dart';
import 'package:nikara_app/features/my_business/domain/models/managed_item.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Cabecera fija del dashboard: título, qué se está mirando y el acceso a
/// notificaciones (donde llega el aviso de aprobado/rechazado).
class MyBusinessHeader extends StatelessWidget {
  const MyBusinessHeader({
    super.key,
    required this.subtitle,
    required this.unreadCount,
    required this.onNotifications,
  });

  final String subtitle;
  final int unreadCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi negocio',
                  style: AppTextStyles.settingsTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.settingsSubtitle.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _NotificationButton(count: unreadCount, onTap: onNotifications),
        ],
      ),
    );
  }
}

/// 48x48 y no 40: es el mínimo táctil, y acá no hay layout apretado que
/// obligue a achicarlo como en las cabeceras con foto de fondo.
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Notificaciones, $count sin leer' : 'Notificaciones',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppColors.destructive,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.homeMiniBadge.copyWith(
                        color: AppColors.textInverted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de lo que se está administrando ahora mismo.
///
/// El chevron solo aparece si hay más de un ítem: con uno solo no hay nada
/// entre qué elegir y una flecha que no lleva a ningún lado es una promesa
/// falsa.
class ManagedItemCard extends StatelessWidget {
  const ManagedItemCard({
    super.key,
    required this.item,
    required this.canSwitch,
    required this.onTap,
  });

  final ManagedItem item;
  final bool canSwitch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: canSwitch ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              ManagedItemThumb(item: item, size: 56),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: AppTextStyles.settingsRowTitle.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isVerified) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.oliveText,
                            semanticLabel: 'Verificado por Níkara',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        ReviewStatusPill(status: item.reviewStatus),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            item.subtitle,
                            style: AppTextStyles.settingsRowCaption.copyWith(
                              color: AppColors.settingsTextMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canSwitch)
                const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.settingsTextMuted,
                  semanticLabel: 'Cambiar de negocio',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Grid 2×N de métricas.
///
/// `childAspectRatio` fijo y no `IntrinsicHeight`: las cuatro tarjetas tienen
/// que medir lo mismo aunque una traiga leyenda ("63 reseñas") y la otra no.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.metrics});

  final List<DashboardMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Sin esto el grid hereda `primary: true` y le suma el padding inferior
      // del sistema (la barra de gestos), que dentro de un ListView aparece
      // como ~150dp de hueco muerto antes de la sección siguiente.
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      children: [for (final metric in metrics) _MetricCard(metric: metric)],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final muted = metric.comingSoon;
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
          Icon(
            metric.icon,
            size: 20,
            color: muted ? AppColors.settingsTextMuted : AppColors.textPrimary,
          ),
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

/// Hoja para elegir entre negocios, fundaciones y jornadas — agrupada por tipo
/// porque una lista plana mezclaría cosas que se administran distinto.
class ManagedItemPickerSheet extends StatelessWidget {
  const ManagedItemPickerSheet({
    super.key,
    required this.items,
    required this.selectedId,
  });

  final List<ManagedItem> items;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    // Sin el tope de altura la hoja crece hasta el borde de la pantalla y el
    // título queda debajo del reloj del sistema: con nueve o diez ítems, que es
    // un caso normal, `mainAxisSize.min` no alcanza para contenerla.
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Qué quieres administrar?',
              style: AppTextStyles.settingsTitle.copyWith(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final kind in ManagedItemKind.values)
                    ..._groupFor(context, kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupFor(BuildContext context, ManagedItemKind kind) {
    final group = items.where((item) => item.kind == kind).toList();
    if (group.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        child: Text(
          kind.label.toUpperCase(),
          style: AppTextStyles.homeMiniBadge.copyWith(
            color: AppColors.settingsTextMuted,
          ),
        ),
      ),
      for (final item in group)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ManagedItemThumb(item: item, size: 40),
          title: Text(
            item.name,
            style: AppTextStyles.settingsRowTitle.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            item.subtitle,
            style: AppTextStyles.settingsRowCaption.copyWith(
              color: AppColors.settingsTextMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: item.id == selectedId
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.oliveText,
                  semanticLabel: 'Seleccionado',
                )
              : null,
          onTap: () => Navigator.of(context).pop(item),
        ),
    ];
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
