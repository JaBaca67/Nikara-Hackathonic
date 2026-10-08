import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// La textura de mapa da contexto de viaje sin competir con los mensajes.
class AssistantTravelBackground extends StatelessWidget {
  const AssistantTravelBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  AppColors.goldFill.withValues(alpha: 0.10),
                  AppColors.background,
                ),
                AppColors.background,
                AppColors.surface,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: SvgPicture.asset(
              'assets/images/topography.svg',
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                AppColors.textPrimary.withValues(alpha: 0.055),
                BlendMode.srcIn,
              ),
              excludeFromSemantics: true,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
