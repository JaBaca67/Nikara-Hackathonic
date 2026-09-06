import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logotipo oficial de Níkara ("NÍKARA" + hojas naranja y verde), compartido
/// por Splash y todo el flujo de Auth.
///
/// El asset es multicolor: [color] aplana el logo entero a un solo tono, así que
/// solo tiene sentido para siluetas/marcas de agua, no para el uso normal.
class NikaraLogoSvg extends StatelessWidget {
  const NikaraLogoSvg({super.key, this.width, this.height, this.color});

  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logotipo_nikara.svg',
      width: width,
      height: height,
      fit: BoxFit.contain,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
