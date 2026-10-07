import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Indicador de carga estándar: mismo grosor y tamaño en toda la app.
///
/// [color] por defecto es `textPrimary`. Pásalo según la pantalla: `oliveText`
/// en el módulo ECO, `textPrimary` sobre un CTA dorado (el dorado nunca se usa
/// como color de trazo sobre fondo claro).
class AppSpinner extends StatelessWidget {
  const AppSpinner({
    super.key,
    this.size = 20,
    this.color = AppColors.textPrimary,
    this.semanticLabel = 'Cargando',
  });

  final double size;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: color,
        semanticsLabel: semanticLabel,
      ),
    );
  }
}

/// Carga de una sección o pantalla mientras llegan datos. No bloquea nada:
/// ocupa solo el espacio que le da el padre y deja la navegación libre.
class AppSectionLoader extends StatelessWidget {
  const AppSectionLoader({
    super.key,
    this.message,
    this.color = AppColors.textPrimary,
  });

  final String? message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpinner(size: 28, color: color),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón primario (CTA dorado) con estado de carga integrado.
///
/// Protege contra el doble toque por sí mismo: mientras [onPressed] (async)
/// no termina, el botón queda deshabilitado y muestra el spinner, sin que el
/// llamador tenga que llevar su propio flag. [isLoading] permite forzar el
/// estado de carga desde fuera (p. ej. si otra acción de la pantalla guarda).
/// El ancho no cambia al cargar, así no salta el layout.
class AppLoadingButton extends StatefulWidget {
  const AppLoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;

  /// `null` deja el botón deshabilitado (sin spinner).
  final FutureOr<void> Function()? onPressed;
  final bool isLoading;

  @override
  State<AppLoadingButton> createState() => _AppLoadingButtonState();
}

class _AppLoadingButtonState extends State<AppLoadingButton> {
  bool _running = false;

  bool get _busy => _running || widget.isLoading;

  Future<void> _handlePress() async {
    if (_busy) return;
    final result = widget.onPressed!();
    if (result is! Future<void>) return;
    setState(() => _running = true);
    try {
      await result;
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: _busy ? '${widget.label}, cargando' : widget.label,
      excludeSemantics: true,
      child: FilledButton(
        onPressed: enabled ? _handlePress : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.goldFill,
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.goldFill.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.textPrimary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.respect(context, AppMotion.quickDuration),
          child: _busy
              ? const AppSpinner(key: ValueKey('spinner'))
              : Text(
                  widget.label,
                  key: const ValueKey('label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.buttonLg,
                ),
        ),
      ),
    );
  }
}

/// Carga a pantalla completa para una acción larga que no admite que el
/// usuario siga tocando (p. ej. subir fotos y guardar). Úsala solo cuando
/// [AppLoadingButton] o [AppSectionLoader] no alcancen: bloquea toda la
/// pantalla.
class AppBusyOverlay extends StatelessWidget {
  const AppBusyOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.message,
  });

  final bool visible;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: AppMotion.respect(context, AppMotion.quickDuration),
            child: !visible
                ? const SizedBox.shrink()
                : Semantics(
                    liveRegion: true,
                    label: message ?? 'Cargando',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ModalBarrier(
                          dismissible: false,
                          color: AppColors.textPrimary.withValues(alpha: 0.35),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppSpinner(size: 32),
                                if (message != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    message!,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyText2.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
