import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// CTA primario único del flujo de Auth; `onPressed: null` ya renderiza el estado deshabilitado, sin que el caller tenga que apagar colores manualmente.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon = Icons.arrow_forward,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Null omite el ícono por completo.
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: [
            AppColors.primary500.withValues(alpha: isEnabled ? 1 : 0.6),
            AppColors.primary700.withValues(alpha: isEnabled ? 1 : 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled
            ? const [
                BoxShadow(
                  color: AppColors.authPrimaryButtonGlow,
                  offset: Offset(0, 8),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? onPressed : null,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(AppColors.authInk),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: AppTextStyles.authButtonLabel),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailingIcon, size: 16, color: AppColors.authInk),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Contraparte outlined del botón primario (p. ej. "Verificar código" junto al "Saltar por ahora").
class AuthOutlinedButton extends StatelessWidget {
  const AuthOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.authMuted.withValues(alpha: isEnabled ? 0.4 : 0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.authButtonLabel.copyWith(
                color: isEnabled
                    ? AppColors.authInk
                    : AppColors.authInk.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
