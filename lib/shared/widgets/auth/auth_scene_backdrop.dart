import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// Sigma de desenfoque inicial de la ilustración de arriba — se aclara a 0 en sintonía con [AuthSceneBackdrop.illustrationsReveal].
const double _kTopIllustrationBlurStart = 16.0;

/// Fondo compartido de las pantallas "de marca" (tier Expresiva): la aurora
/// animada de [AuroraBackgroundWidget] más las dos escenas ilustradas fijas
/// (hojas/aves arriba, montaña/lago/bote abajo) que enmarcan el logo. Se usa
/// en el Splash y en todo el flujo de Auth (via `AuthBottomSheetLayout`) para
/// que ambos compartan el mismo fondo en vez de reimplementar cada uno el
/// mismo par de `Image.asset` posicionadas.
class AuthSceneBackdrop extends StatelessWidget {
  const AuthSceneBackdrop({
    super.key,
    this.logoFocusY = 0.16,
    this.showIllustrations = true,
    this.illustrationsReveal = const AlwaysStoppedAnimation(1),
    this.child,
  });

  /// Altura (fracción de pantalla) donde se centra el halo dorado tras el
  /// logo — ver [AuroraBackgroundWidget.logoFocusY].
  final double logoFocusY;

  /// Dibuja las dos escenas PNG sobre la aurora. En false queda solo la aurora.
  final bool showIllustrations;

  /// Progreso de entrada de las ilustraciones (0 a 1). El valor por defecto
  /// las deja siempre visibles y enfocadas; quien quiera sincronizarlas con
  /// otra animación de entrada (ej. la tarjeta de `AuthBottomSheetLayout`)
  /// pasa su propio [Animation] — así las dos se mueven con el mismo reloj
  /// en vez de aparecer en momentos distintos. Además de controlar la
  /// opacidad del conjunto, maneja el desenfoque de entrada de la
  /// ilustración de arriba (ver [_kTopIllustrationBlurStart]).
  final Animation<double> illustrationsReveal;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AuroraBackgroundWidget(logoFocusY: logoFocusY),
        if (showIllustrations)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: illustrationsReveal,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Top negativo minúsculo: sube el asset lo justo para que
                    // las aves no queden pegadas al logo, sin recortar
                    // visiblemente las hojas del borde superior.
                    Positioned(
                      top: -12,
                      left: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: illustrationsReveal,
                        builder: (context, child) {
                          final blur = ui.lerpDouble(
                            _kTopIllustrationBlurStart,
                            0,
                            illustrationsReveal.value,
                          )!;
                          return ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: blur,
                              sigmaY: blur,
                              tileMode: TileMode.decal,
                            ),
                            child: child,
                          );
                        },
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
                      bottom: 0,
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
                  ],
                ),
              ),
            ),
          ),
        ?child,
      ],
    );
  }
}
