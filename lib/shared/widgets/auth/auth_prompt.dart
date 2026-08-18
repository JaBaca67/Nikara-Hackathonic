import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Implementación única compartida por Login/Register para que no vuelvan a divergir en tamaño (ya pasó: 12px vs 13px).
class AuthPrompt extends StatelessWidget {
  const AuthPrompt({
    super.key,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // El Center exterior es necesario porque el `Column` padre usa crossAxisAlignment.start, que si no encogería el Wrap a su contenido y lo pegaría a la izquierda.
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: AppColors.authBodyMuted,
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: AppTextStyles.linkMd.copyWith(color: AppColors.authLink),
            ),
          ),
        ],
      ),
    );
  }
}
