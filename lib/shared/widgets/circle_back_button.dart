import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Botón circular de "volver" de las cabeceras de formulario.
///
/// Estaba reimplementado idéntico —mismo tamaño, mismos dos colores— en el
/// hub de edición de negocio, el wizard de registro y la cabecera compartida
/// del módulo ECO. Se consolidó acá sin cambiar un píxel: los tres usaban
/// exactamente 40x40 sobre [AppColors.profileDivider].
///
/// Las cabeceras de Ajustes (36px), del wizard de rutas y de la portada de
/// detalle ([DetailCoverIconButton]) siguen aparte a propósito: tienen otro
/// tamaño o van sobre una foto, no sobre fondo plano.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({
    super.key,
    required this.onTap,
    this.label = 'Volver',
  });

  final VoidCallback onTap;

  /// Descripción para lectores de pantalla — el botón no tiene texto visible.
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.profileDivider,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_back,
          semanticLabel: label,
          color: AppColors.settingsTextDark,
        ),
      ),
    );
  }
}
