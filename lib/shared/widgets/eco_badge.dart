import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Tamaño del badge ECO según el contenedor que lo aloja.
enum EcoBadgeSize {
  /// Tarjeta hero / vista previa — incluye el ícono de hoja.
  large,

  /// Tarjeta de listado, fila de mapa, chip de detalle.
  small,
}

/// Único badge "ECO" de la app.
///
/// Antes vivía reimplementado seis veces (tres en Inicio, uno en Mapa, uno en
/// el wizard de negocio y uno en el detalle) con cuatro paddings y tres
/// estilos tipográficos distintos. Consolidarlo acá no es solo limpieza:
/// todas esas copias pintaban texto blanco sobre [AppColors.oliveFill], un
/// contraste de 1.74:1 — muy por debajo del mínimo 4.5:1 de WCAG AA, en la
/// práctica ilegible.
///
/// La corrección sigue la misma regla que el sistema ya aplicaba a
/// [AppColors.goldFill]: un relleno de marca claro lleva texto oscuro encima,
/// nunca blanco. Con [AppColors.textPrimary] sobre el lima el contraste sube
/// a 10.61:1.
class EcoBadge extends StatelessWidget {
  const EcoBadge({super.key, this.size = EcoBadgeSize.small});

  final EcoBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final isLarge = size == EcoBadgeSize.large;
    final textStyle =
        (isLarge ? AppTextStyles.homeHeroPill : AppTextStyles.homeMiniBadge)
            .copyWith(color: AppColors.textPrimary);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? AppSpacing.md : AppSpacing.sm,
        vertical: isLarge ? AppSpacing.xs + 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.oliveFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLarge) ...[
            const Icon(Icons.eco, size: 12, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Text('ECO', style: textStyle),
        ],
      ),
    );
  }
}
