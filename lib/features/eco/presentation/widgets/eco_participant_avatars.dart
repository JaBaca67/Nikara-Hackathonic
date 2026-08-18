import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Pila de avatares superpuestos + contador ("+18") de quienes ya se
/// unieron a una actividad. La comparten la tarjeta del feed y la pestaña
/// "Información" del detalle.
///
/// `eco_participants` no trae foto de perfil, así que los círculos se
/// pintan con los rellenos neutros de [AppColors.ecoAvatarStack] — sugieren
/// varias personas distintas sin inventar identidades. Cuando no hay nadie
/// no se dibuja nada: quien llama decide qué poner en su lugar.
class EcoParticipantAvatars extends StatelessWidget {
  const EcoParticipantAvatars({
    super.key,
    required this.count,
    this.size = 32,
    this.maxShown = 4,
    this.borderColor = AppColors.surface100,
  });

  final int count;
  final double size;
  final int maxShown;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final shown = count < maxShown ? count : maxShown;
    final overlap = size * 0.62;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: size,
          width: overlap * (shown - 1) + size,
          child: Stack(
            children: [
              for (var i = 0; i < shown; i++)
                Positioned(
                  left: i * overlap,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors
                          .ecoAvatarStack[i % AppColors.ecoAvatarStack.length],
                      border: Border.all(color: borderColor, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '+$count',
          style: AppTextStyles.mapRowTitle.copyWith(
            fontSize: 12,
            color: AppColors.settingsTextMuted,
          ),
        ),
      ],
    );
  }
}
