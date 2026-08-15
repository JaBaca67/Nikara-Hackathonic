import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Title + subtitle pair opening every Auth card ("Bienvenido de nuevo" /
/// "Crea tu cuenta" / "Cuéntanos sobre ti" / "Verifica tu número") — League
/// Spartan Bold title, Nunito Regular subtitle, both in the Auth flow's
/// dedicated ink/muted tones. One fixed size for both, always — no
/// per-screen override — so every step of the flow reads as the same
/// typographic rhythm instead of subtly different sizes per screen.
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
