import 'package:flutter/material.dart';

/// Logotipo oficial de Níkara, compartido por Splash y todo el flujo de Auth.
/// Usa un PNG rasterizado (no `SvgPicture` directo) porque `flutter_svg` no soporta el `filter` del SVG original, y un raster demasiado grande seguía mostrando moiré en las curvas del pin al escalarse en runtime; 1025x450 es el punto que lo evita.
/// Sigue llamándose `...Svg` por estabilidad de los call sites existentes.
class NikaraLogoSvg extends StatelessWidget {
  const NikaraLogoSvg({super.key, this.width, this.height, this.color});

  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/nikara_logo_wordmark.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    if (color == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      child: image,
    );
  }
}
