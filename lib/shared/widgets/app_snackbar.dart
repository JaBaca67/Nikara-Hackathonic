import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

enum _AppSnackbarType { success, error, info }

/// Punto único para mostrar feedback transitorio de una acción (guardado,
/// error, aviso). Sigue siendo el `SnackBar` nativo de Material por dentro
/// —conserva cola de mensajes, anuncio a lectores de pantalla y
/// swipe-to-dismiss— solo agrega ícono y color de estado sobre la base ya
/// temeada en `AppTheme.lightTheme.snackBarTheme` (superficie clara,
/// flotante, redondeada). Reemplaza gradualmente los ~26 call sites que hoy
/// llaman a `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))`
/// directo, sin ícono ni diferenciación de estado.
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
    switch (type) {
      case _AppSnackbarType.success:
        icon = Icons.check_circle;
        color = AppColors.success;
      case _AppSnackbarType.error:
        icon = Icons.error;
        color = AppColors.error;
      case _AppSnackbarType.info:
        icon = Icons.info;
        color = AppColors.oliveText;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
