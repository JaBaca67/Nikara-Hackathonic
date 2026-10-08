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
///
/// Movimiento: entra con fade + escala de 0.95 a 1.0 (250 ms) y sale más
/// rápido (200 ms), sin rebote. Con "Eliminar animaciones" activo aparece y
/// desaparece al instante.
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
    final navigator = Navigator.of(context, rootNavigator: true);
    // Como hace `showDialog`: conserva los temas locales del llamador.
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final barrierLabel = MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel;
    final reduced = AppMotion.reduced(context);

    final confirmed = await navigator.push<bool>(
      _AppDialogRoute<bool>(
        enterDuration: reduced ? Duration.zero : AppMotion.standardDuration,
        exitDuration: reduced ? Duration.zero : AppMotion.quickDuration,
        barrierLabel: barrierLabel,
        pageBuilder: (_, _, _) => themes.wrap(
          SafeArea(
            child: _ConfirmDialogContent(
              title: title,
              message: message,
              confirmLabel: confirmLabel,
              cancelLabel: cancelLabel,
              destructive: destructive,
            ),
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }
}

/// Ruta del diálogo con entrada y salida de distinta duración.
///
/// `showDialog` no sirve para esto: su `DialogRoute` solo respeta
/// `AnimationStyle.duration` y usa la misma duración al salir (se midió: la
/// salida tardaba lo mismo que la entrada aunque se pasara `reverseDuration`).
class _AppDialogRoute<T> extends RawDialogRoute<T> {
  _AppDialogRoute({
    required super.pageBuilder,
    required super.barrierLabel,
    required Duration enterDuration,
    required this.exitDuration,
  }) : super(
         barrierDismissible: false,
         barrierColor: AppColors.textPrimary.withValues(alpha: 0.5),
         transitionDuration: enterDuration,
         transitionBuilder: _transition,
       );

  final Duration exitDuration;

  @override
  Duration get reverseTransitionDuration => exitDuration;

  /// Fade + escala de 0.95 a 1.0 con curva desacelerada al entrar y
  /// acelerada al salir. Sin sobrepaso: nada pasa de 1.0.
  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        key: const ValueKey('confirm-dialog-scale'),
        scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
        child: child,
      ),
    );
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
