import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/review_status.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

// Piezas compartidas por las cuatro vistas del panel.
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
class AdminStatTile extends StatelessWidget {
  const AdminStatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  /// Resalta la métrica accionable (los pendientes) con el único acento del
  /// panel; el resto son neutras para que ese acento signifique algo.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight
        ? AppColors.oliveText
        : AppColors.settingsTextMuted;
    return Container(
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
