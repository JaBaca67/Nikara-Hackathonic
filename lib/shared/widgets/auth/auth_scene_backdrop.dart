import 'package:flutter/material.dart';

import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// Fondo compartido de las pantallas "de marca" (tier Expresiva): la aurora
/// animada de [AuroraBackgroundWidget] más las dos escenas ilustradas fijas
/// (hojas/aves arriba, montaña/lago/bote abajo) que enmarcan el logo. Se usa
/// en el Splash y en todo el flujo de Auth (via `AuthBottomSheetLayout`) para
/// que ambos compartan el mismo fondo en vez de reimplementar cada uno el
/// mismo par de `Image.asset` posicionadas.
class AuthSceneBackdrop extends StatelessWidget {
  const AuthSceneBackdrop({super.key, this.logoFocusY = 0.16, this.child});

  /// Altura (fracción de pantalla) donde se centra el halo dorado tras el
  /// logo — ver [AuroraBackgroundWidget.logoFocusY].
  final double logoFocusY;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AuroraBackgroundWidget(logoFocusY: logoFocusY),
        // Top negativo minúsculo: sube el asset lo justo para que las aves no
        // queden pegadas al logo, sin recortar visiblemente las hojas del
        // borde superior.
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Image.asset(
              'assets/images/parte_arriba_nikara.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.medium,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: IgnorePointer(
            child: Image.asset(
              'assets/images/parte_abajo_login.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.medium,
              alignment: Alignment.bottomCenter,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}
