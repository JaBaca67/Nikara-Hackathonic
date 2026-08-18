import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Título + subtítulo de cada card de Auth; tamaño fijo sin override por pantalla para mantener el mismo ritmo tipográfico en todo el flujo.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.registerHeading.copyWith(
            color: AppColors.authInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.body.copyWith(
            color: AppColors.authBodyMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
