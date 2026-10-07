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
/// vistazo. Es tier Funcional: un solo acento (el del ícono) por alerta.
abstract class AppSnackbar {
  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, _AppSnackbarType.success);

  static void showError(BuildContext context, String message) =>
      _show(context, message, _AppSnackbarType.error);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, _AppSnackbarType.info);

  static void _show(
    BuildContext context,
    String message,
    _AppSnackbarType type,
  ) {
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

    // Entrada/salida cortas y sin rebote; con "Eliminar animaciones" activo
    // el aviso aparece y desaparece al instante.
    final animationStyle = AppMotion.reduced(context)
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: AppMotion.standardDuration,
            reverseDuration: AppMotion.quickDuration,
            curve: AppMotion.enter,
            reverseCurve: AppMotion.exit,
          );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
            ],
          ),
        ),
        snackBarAnimationStyle: animationStyle,
      );
  }
}
