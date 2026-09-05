import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/features/admin/domain/models/admin_business_summary.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';
import 'package:nikara_app/features/eco/domain/models/organization_model.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

// Piezas compartidas por las cuatro vistas del panel — más [AdminInlineReviewCard],
// que en vez de vivir en el panel se inserta condicionalmente dentro de las
// pantallas públicas de ECO y fundaciones (ver eco_detail_screen.dart /
// organization_profile_screen.dart) para que un admin apruebe/rechace mirando
// el mismo detalle rico que ve cualquier usuario, en vez de una ficha aparte.
//
// Tier FUNCIONAL: fondo `AppColors.background`, superficies
// `AppColors.surface`, texto de la escala neutra y UN SOLO acento de marca en
// toda la feature — Olive. Gold no aparece en ninguna pantalla del panel:
// "verificado" se lee como estado positivo, no como destacado comercial, y
// meter el dorado acá reintroduciría la coexistencia Gold+Olive que la
// auditoría del 2026-08-25 dejó marcada como deuda abierta.

/// Píldora del estado de revisión de una fila (`status`).
///
/// Ni aprobado ni rechazado usan [AppColors.goldFill] aunque el dorado sea el
/// color natural de "en espera": sería un segundo relleno de marca en una
/// pantalla Funcional. Aprobado se queda con el único acento permitido
/// ([AppColors.oliveFill]), pendiente con el neutro [AppColors.profileDivider]
/// —el fondo de chip neutro del resto de la app— y rechazado con el token de
/// estado [AppColors.error], que no cuenta como acento de marca.
class AdminStatusPill extends StatelessWidget {
  const AdminStatusPill({super.key, required this.status});

  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    // Relleno claro + texto oscuro en los tres casos: ningún Fill de marca
    // lleva texto blanco encima (ver CLAUDE.md > Sistema de diseño).
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

/// Tarjeta de un conteo del panel de métricas.
///
/// [onTap] es opcional: solo las métricas que tienen una lista real detrás
/// (negocios) lo pasan y abren su drill-down con buscador; una métrica
/// derivada (el porcentaje de cobertura) se queda sin acción porque no hay
/// una lista que abrir.
class AdminStatTile extends StatelessWidget {
  const AdminStatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  /// Resalta la métrica accionable (los pendientes) con el único acento del
  /// panel; el resto son neutras para que ese acento signifique algo.
  final bool highlight;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = highlight
        ? AppColors.oliveText
        : AppColors.settingsTextMuted;
    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.settingsRowCaption.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.settingsTextMuted,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.profileStatValue.copyWith(
              color: highlight ? AppColors.oliveText : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              style: AppTextStyles.settingsRowCaption.copyWith(
                color: AppColors.settingsTextMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Buscador del panel: mismo look en la cola de revisión y en cualquier
/// drill-down de métricas, para que no diverjan como pasó con el badge ECO
/// antes de consolidarse (ver CLAUDE.md > auditoría de diseño).
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.settingsRowTitle.copyWith(
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hintText,
        hintStyle: AppTextStyles.settingsRowCaption.copyWith(
          color: AppColors.settingsTextMuted,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.settingsTextMuted,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.settingsTextMuted,
              ),
              tooltip: 'Limpiar búsqueda',
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            );
          },
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.oliveText),
        ),
      ),
    );
  }
}

/// Tarjeta de negocio del panel — misma fila en la cola de revisión y en el
/// drill-down de métricas, para no terminar con dos versiones que se separan
/// visualmente con el tiempo.
class AdminBusinessCard extends StatelessWidget {
  const AdminBusinessCard({
    super.key,
    required this.business,
    required this.onTap,
  });

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

/// Estado vacío/erróneo de una vista del panel, con reintento opcional.
class AdminPlaceholder extends StatelessWidget {
  const AdminPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.settingsTextMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.settingsRowTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.settingsRowCaption.copyWith(
                color: AppColors.settingsTextMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Reintentar',
                  style: AppTextStyles.settingsRowTitle.copyWith(
                    color: AppColors.oliveText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Spinner de carga del panel, en el acento de la feature.
class AdminLoading extends StatelessWidget {
  const AdminLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.oliveText),
        ),
      ),
    );
  }
}

/// Encabezado de sección dentro de una vista con scroll.
class AdminSectionLabel extends StatelessWidget {
  const AdminSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxl,
        bottom: AppSpacing.md,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.settingsSectionLabel.copyWith(
          color: AppColors.settingsTextMuted,
        ),
      ),
    );
  }
}

/// Diálogo de confirmación genérico para acciones de admin reversibles pero
/// visibles en toda la app (dar/quitar el sello de verificado). Compartido
/// entre `admin_business_detail_screen.dart` y `organization_profile_screen.dart`.
class AdminConfirmDialog extends StatelessWidget {
  const AdminConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        title,
        style: AppTextStyles.settingsTitle.copyWith(
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        message,
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
            confirmLabel,
            style: AppTextStyles.settingsRowTitle.copyWith(color: confirmColor),
          ),
        ),
      ],
    );
  }
}

/// Fila del sello de verificado — interruptor y no botón porque es la acción
/// secundaria (la principal es publicar/aprobar). Compartida entre la ficha
/// de negocios (`admin_business_detail_screen.dart`) y el perfil de
/// fundación (`organization_profile_screen.dart`): mismo mecanismo
/// (`AdminService.setBusinessVerified`/`setOrganizationVerified`), mismo
/// widget.
class AdminSealRow extends StatelessWidget {
  const AdminSealRow({
    super.key,
    required this.isVerified,
    required this.enabled,
    required this.onChanged,
  });

  final bool isVerified;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isVerified
                ? 'Muestra el sello de verificado'
                : 'Sin sello de verificado',
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          ),
        ),
        Switch(
          value: isVerified,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: AppColors.oliveText,
        ),
      ],
    );
  }
}

/// Franja de aprobar/rechazar que se inserta en una pantalla pública (eco,
/// fundación) cuando quien mira tiene permiso de revisión — nunca reemplaza
/// contenido de la pantalla, solo se agrega. Mismo texto/color que la barra
/// de acciones de la ficha de negocios (`admin_business_detail_screen.dart`),
/// pero como tarjeta dentro del scroll en vez de una barra inferior fija: acá
/// esa barra ya está ocupada por "Unirme"/"Gestionar".
class AdminInlineReviewCard extends StatelessWidget {
  const AdminInlineReviewCard({
    super.key,
    required this.status,
    required this.rejectionReason,
    required this.saving,
    required this.onApprove,
    required this.onReject,
  });

  final ReviewStatus status;
  final String? rejectionReason;
  final bool saving;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final showApprove = !status.isAprobado;
    final showReject = !status.isRechazado;
    final reason = rejectionReason?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.oliveFill, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppColors.oliveText,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Revisión del equipo Níkara',
                  style: AppTextStyles.settingsRowCaption.copyWith(
                    color: AppColors.oliveText,
                  ),
                ),
              ),
              AdminStatusPill(status: status),
            ],
          ),
          if (status.isRechazado && reason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Motivo del rechazo: $reason',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (showReject)
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.destructive),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: saving
                        ? const AdminLoading()
                        : Text(
                            status.isAprobado ? 'Quitar de la app' : 'Rechazar',
                            style: AppTextStyles.buttonMd.copyWith(
                              color: AppColors.destructive,
                            ),
                          ),
                  ),
                ),
              if (showReject && showApprove)
                const SizedBox(width: AppSpacing.md),
              if (showApprove)
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.oliveFill,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: saving
                        ? const AdminLoading()
                        : Text(
                            'Aprobar',
                            style: AppTextStyles.buttonMd.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de jornada ECO del panel — misma fila en el drill-down de
/// métricas y en el selector "Jornadas" de la cola de revisión unificada.
class AdminEcoActivityCard extends StatelessWidget {
  const AdminEcoActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final EcoActivityModel activity;
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
                      activity.title.isEmpty ? 'Sin título' : activity.title,
                      style: AppTextStyles.settingsRowTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AdminStatusPill(status: activity.reviewStatus),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                activity.category.isEmpty
                    ? activity.location
                    : '${activity.category} · ${activity.location}',
                style: AppTextStyles.settingsRowCaption.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 14,
                    color: AppColors.settingsTextMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      activity.organizerDisplayName,
                      style: AppTextStyles.settingsRowCaption.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
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

/// Tarjeta de fundación del panel — misma fila en el drill-down de métricas
/// y en el selector "Fundaciones" de la cola de revisión unificada.
class AdminOrganizationCard extends StatelessWidget {
  const AdminOrganizationCard({
    super.key,
    required this.organization,
    required this.onTap,
  });

  final OrganizationModel organization;
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
                      organization.name.isEmpty
                          ? 'Sin nombre'
                          : organization.name,
                      style: AppTextStyles.settingsRowTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AdminStatusPill(status: organization.reviewStatus),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                organization.handleTag,
                style: AppTextStyles.settingsRowCaption.copyWith(
                  color: AppColors.settingsTextMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    organization.isVerified
                        ? Icons.verified_outlined
                        : Icons.pending_outlined,
                    size: 14,
                    color: AppColors.settingsTextMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      organization.isVerified ? 'Verificada' : 'Sin verificar',
                      style: AppTextStyles.settingsRowCaption.copyWith(
                        color: AppColors.settingsTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
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
