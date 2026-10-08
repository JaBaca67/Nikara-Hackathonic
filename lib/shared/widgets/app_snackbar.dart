import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

enum _AppSnackbarType { success, error, info }

/// Punto único para mostrar feedback transitorio de una acción (guardado,
/// error, aviso). Sigue siendo el `SnackBar` nativo de Material por dentro
/// —conserva cola de mensajes, anuncio a lectores de pantalla y
/// swipe-to-dismiss— sobre la base ya temeada en
/// `AppTheme.lightTheme.snackBarTheme` (superficie clara, flotante,
/// redondeada).
///
/// Los tres tipos comparten estructura, formas, espaciados y tipografía: solo
/// cambian el ícono, su color y cuánto dura en pantalla. Un error dura más
/// porque suele pedir leer qué falló y qué hacer; un éxito se entiende de un
/// vistazo. Es tier Funcional: un solo acento (el del tipo) por alerta, que
/// pinta el ícono y, si lo hay, el botón de acción.
///
/// Movimiento: la barra entra con el fade + revelado desde el borde inferior
/// que ya trae el `SnackBar` flotante (250 ms) y sale en 200 ms; el ícono se
/// asienta de 0.8 a 1.0. Sin rebotes ni barra de progreso. Con "Eliminar
/// animaciones" activo todo aparece y desaparece al instante.
abstract class AppSnackbar {
  /// [actionLabel] y [onAction] van juntos: sin ellos la alerta es la de
  /// siempre. Al pulsar la acción la alerta se cierra y se ejecuta [onAction].
  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    _AppSnackbarType.success,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showError(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    _AppSnackbarType.error,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showInfo(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    _AppSnackbarType.info,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void _show(
    BuildContext context,
    String message,
    _AppSnackbarType type, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    assert(
      (actionLabel == null) == (onAction == null),
      'actionLabel y onAction se pasan juntos.',
    );
    final hasAction = actionLabel != null && onAction != null;

    final IconData icon;
    final Color color;
    final Duration duration;
    switch (type) {
      case _AppSnackbarType.success:
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        duration = const Duration(seconds: 3);
      case _AppSnackbarType.error:
        icon = Icons.error_rounded;
        color = AppColors.error;
        duration = const Duration(seconds: 5);
      case _AppSnackbarType.info:
        // No existe un token `info`: se reutiliza el oliva de texto (4.76:1).
        // La diferencia con éxito la da el ícono, no solo el matiz.
        icon = Icons.info_rounded;
        color = AppColors.oliveText;
        duration = const Duration(seconds: 4);
    }

    final reduced = AppMotion.reduced(context);
    final animationStyle = reduced
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: AppMotion.standardDuration,
            reverseDuration: AppMotion.quickDuration,
          );

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // Con acción se da margen extra para poder leerla y pulsarla.
          duration: hasAction
              ? duration + const Duration(seconds: 2)
              : duration,
          content: Row(
            children: [
              _SettlingIcon(icon: icon, color: color, animate: !reduced),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
              if (hasAction) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar(
                      reason: SnackBarClosedReason.action,
                    );
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child: Text(actionLabel, style: AppTextStyles.buttonMd),
                ),
              ],
            ],
          ),
        ),
        snackBarAnimationStyle: animationStyle,
      );
  }
}

/// Ícono que se asienta de 0.8 a 1.0 mientras entra la barra. Curva
/// desacelerada (sin sobrepaso): un rebote en una alerta de error se lee como
/// un fallo de timing, no como gracia.
class _SettlingIcon extends StatelessWidget {
  const _SettlingIcon({
    required this.icon,
    required this.color,
    required this.animate,
  });

  final IconData icon;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, color: color, size: 24);
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1),
      duration: AppMotion.standardDuration,
      curve: AppMotion.decelerate,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
