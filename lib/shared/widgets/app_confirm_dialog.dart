import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Diálogo de confirmación único para acciones destructivas o de salida.
///
/// Misma superficie, radio, espaciado y tipografía que [AppSnackbar]; solo
/// cambia el contenido. Devuelve `true` únicamente si el usuario pulsa el
/// botón de confirmar: cerrar con el botón atrás del sistema cuenta como
/// cancelar (nunca se confirma por accidente). No se cierra al tocar fuera.
abstract class AppConfirmDialog {
  /// [destructive] pinta el botón de confirmar con `AppColors.destructive`
  /// (eliminar, cerrar sesión, salir perdiendo progreso). Con `false` usa el
  /// CTA dorado de la app.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancelar',
    bool destructive = true,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      animationStyle: AppMotion.reduced(context)
          ? AnimationStyle.noAnimation
          : AnimationStyle(
              duration: AppMotion.standardDuration,
              reverseDuration: AppMotion.quickDuration,
              curve: AppMotion.enter,
              reverseCurve: AppMotion.exit,
            ),
      builder: (_) => _ConfirmDialogContent(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
    return confirmed ?? false;
  }
}

class _ConfirmDialogContent extends StatelessWidget {
  const _ConfirmDialogContent({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.destructive : AppColors.goldFill;
    final onAccent = destructive
        ? AppColors.textInverted
        : AppColors.textPrimary;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      actionsPadding: const EdgeInsets.all(AppSpacing.xxl),
      title: Text(
        title,
        style: AppTextStyles.h6.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        message,
        style: AppTextStyles.bodyText2.copyWith(color: AppColors.textPrimary),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(cancelLabel, style: AppTextStyles.buttonMd),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: accent,
                  foregroundColor: onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(confirmLabel, style: AppTextStyles.buttonMd),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
