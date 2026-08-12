import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/models/mock_data.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Row of social sign-in buttons (Google/Apple/Facebook) — shared between
/// [LoginScreen] and the registration wizard's Paso 1, since both need the
/// exact same secondary/outlined-hierarchy treatment: a neutral surface
/// with a thin border, never a filled brand color, so these never compete
/// visually with the one primary CTA above them.
class SocialAuthRow extends StatelessWidget {
  const SocialAuthRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final provider in mockSocialAuthProviders) ...[
          _SocialAuthButton(provider: provider),
          if (provider != mockSocialAuthProviders.last)
            const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({required this.provider});

  final SocialAuthProvider provider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continuar con ${provider.label}',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  offset: Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: provider.assetPath.endsWith('.svg')
                  ? SvgPicture.asset(provider.assetPath, width: 36, height: 36)
                  : Image.asset(
                      provider.assetPath,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
