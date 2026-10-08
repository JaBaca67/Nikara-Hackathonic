import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// Recorrido del deslizamiento de entrada de cada ilustración, en dp. Corto a propósito: la de arriba baja desde el borde superior y la de abajo sube desde el inferior, sin que se lea como un desplazamiento de pantalla.
const double _kSlideDistance = 24.0;

/// Ventanas de [AuthSceneBackdrop.illustrationsReveal] en las que se mueve cada ilustración. Con los 650ms de la entrada de `AuthBottomSheetLayout` cada una dura ~500ms y la de abajo arranca ~150ms después: el desfase entre ellas sin un segundo controlador.
const double _kTopWindowEnd = 0.77;
const double _kBottomWindowStart = 0.23;

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

  /// Progreso lineal de entrada de las ilustraciones (0 a 1). El valor por
  /// defecto las deja siempre visibles y en su sitio; quien quiera
  /// sincronizarlas con otra animación de entrada (ej. la tarjeta de
  /// `AuthBottomSheetLayout`) pasa su propio [Animation] — así las dos se
  /// mueven con el mismo reloj en vez de aparecer en momentos distintos. Las
  /// curvas y el desfase entre ilustraciones se aplican aquí dentro, por eso
  /// debe llegar sin curva.
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
                    child: _RevealedIllustration(
                      reveal: illustrationsReveal,
                      window: const Interval(0, _kTopWindowEnd),
                      slideFrom: const Offset(0, -_kSlideDistance),
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
                    child: _RevealedIllustration(
                      reveal: illustrationsReveal,
                      window: const Interval(_kBottomWindowStart, 1),
                      slideFrom: const Offset(0, _kSlideDistance),
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
                ],
              ),
            ),
          ),
        ?child,
      ],
    );
  }
}

/// Fade más deslizamiento corto, ambos dentro de [window] del progreso [reveal]. Sin rebote: la opacidad no puede salirse de 0-1 sin parpadear.
class _RevealedIllustration extends StatelessWidget {
  const _RevealedIllustration({
    required this.reveal,
    required this.window,
    required this.slideFrom,
    required this.child,
  });

  final Animation<double> reveal;
  final Interval window;
  final Offset slideFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: reveal,
      curve: Interval(window.begin, window.end, curve: AppMotion.enter),
    );
    final slide = CurvedAnimation(
      parent: reveal,
      curve: Interval(window.begin, window.end, curve: AppMotion.decelerate),
    );
    return FadeTransition(
      opacity: opacity,
      child: AnimatedBuilder(
        animation: slide,
        builder: (context, child) => Transform.translate(
          offset: Offset.lerp(slideFrom, Offset.zero, slide.value)!,
          child: child,
        ),
        child: child,
      ),
    );
  }
}
