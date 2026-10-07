import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Duración con la que el sólido del splash nativo se vuelve el degradado de la app.
const Duration _kGradientIntro = Duration(milliseconds: 1000);

/// Ciclo de la deriva ambiental del degradado; largo para que se lea como luz que cambia, no como movimiento.
const Duration _kDriftCycle = Duration(seconds: 14);

/// Cuánto se desplazan los stops intermedios del degradado (fracción de alto) en cada extremo de la deriva.
const double _kDriftAmplitude = 0.035;

/// Lado del tile de `topography.svg` en px de su propio viewBox.
const int _kPatternTile = 600;

/// Tiempo que tarda el patrón en recorrer un tile completo; lineal y largo para que se lea como textura que respira, no como scroll.
const Duration _kTopographyLoop = Duration(seconds: 50);

/// Retraso mínimo del fade de la topografía respecto al inicio del degradado: que el degradado se asiente primero.
const Duration _kTopographyFadeDelay = Duration(milliseconds: 400);

const Duration _kTopographyFade = Duration(milliseconds: 1200);

/// Opacidad final del tinte. Ver [_kTopographyTint].
const double _kTopographyAlpha = 0.12;

/// Tinte de la topografía. Negro puro (`textPrimary`, lo que usa Aurora) apaga el degradado; `goldDeepText`
/// es el ámbar oscuro de la familia Gold, así que oscurece el relieve sin cambiar de tono ni ensuciarlo de
/// verde como haría `oliveText`. Su doc lo define como color de texto; aquí solo se usa como tinte a baja opacidad.
const Color _kTopographyTint = AppColors.goldDeepText;

/// Fondo del splash de arranque: frame 0 idéntico al splash nativo de Android (sólido
/// [AppColors.sunsetStart]) que evoluciona al degradado vertical de Auth, deriva muy sutilmente y, cuando
/// el patrón topográfico está listo, lo muestra con fade y desplazamiento diagonal lento en bucle.
///
/// No reemplaza a `AuroraBackgroundWidget` (blobs, halo, topografía estática) — vive aparte para que
/// Login y Registro conserven su aspecto. Degradado y topografía son capas con su propio
/// [RepaintBoundary]; nada que se ponga encima (el isotipo) se reconstruye con la animación.
class SplashBackdrop extends StatefulWidget {
  const SplashBackdrop({super.key});

  @override
  State<SplashBackdrop> createState() => _SplashBackdropState();
}

class _SplashBackdropState extends State<SplashBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: _kGradientIntro,
  )..forward();

  late final Animation<double> _intro = CurvedAnimation(
    parent: _introController,
    curve: Curves.easeInOut,
  );

  // Con t=0 todos los colores son iguales, así que la deriva es invisible hasta que el degradado aparece.
  late final AnimationController _driftController = AnimationController(
    vsync: this,
    duration: _kDriftCycle,
  )..repeat(reverse: true);

  late final Animation<double> _drift = CurvedAnimation(
    parent: _driftController,
    curve: Curves.easeInOut,
  );

  late final AnimationController _topographyFade = AnimationController(
    vsync: this,
    duration: _kTopographyFade,
  );

  late final AnimationController _topographyScroll = AnimationController(
    vsync: this,
    duration: _kTopographyLoop,
  );

  /// Cuenta desde el inicio del degradado, para medir el retraso del fade sin depender del momento en que la imagen quedó lista.
  final Stopwatch _sinceStart = Stopwatch()..start();

  ui.Image? _pattern;

  @override
  void initState() {
    super.initState();
    // Parsear 91 KB de SVG en el primer frame retrasaría justo el frame que debe igualar a la pantalla nativa.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPattern());
  }

  /// Rasteriza el tile una sola vez; el painter lo repite con un shader, así el costo por frame no depende de cuántas veces se vea.
  Future<void> _loadPattern() async {
    final parseTimer = Stopwatch()..start();
    final info = await vg.loadPicture(
      const SvgAssetLoader('assets/images/topography.svg'),
      null,
    );
    final image = await info.picture.toImage(_kPatternTile, _kPatternTile);
    info.picture.dispose();
    if (kDebugMode) {
      debugPrint(
        'Splash: topografía lista en ${parseTimer.elapsedMilliseconds} ms',
      );
    }
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _pattern = image);

    final wait = _kTopographyFadeDelay - _sinceStart.elapsed;
    if (!wait.isNegative) await Future<void>.delayed(wait);
    if (!mounted) return;
    unawaited(_topographyFade.forward());
    unawaited(_topographyScroll.repeat());
  }

  @override
  void dispose() {
    _introController.dispose();
    _driftController.dispose();
    _topographyFade.dispose();
    _topographyScroll.dispose();
    _pattern?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pattern = _pattern;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _drift]),
            builder: (context, _) {
              final t = _intro.value;
              final shift = (_drift.value * 2 - 1) * _kDriftAmplitude;
              final stops = AppGradients.authBackgroundStops;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AppGradients.authBackgroundBegin,
                    end: AppGradients.authBackgroundEnd,
                    colors: [
                      for (final target in AppGradients.authBackgroundColors)
                        Color.lerp(AppColors.sunsetStart, target, t)!,
                    ],
                    // Solo los intermedios se mueven; los extremos quedan fijos en 0.0 y 1.0.
                    stops: [
                      for (var i = 0; i < stops.length; i++)
                        (i == 0 || i == stops.length - 1)
                            ? stops[i]
                            : stops[i] + shift,
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
        if (pattern != null)
          RepaintBoundary(
            child: CustomPaint(
              painter: _TopographyPainter(
                pattern: pattern,
                scroll: _topographyScroll,
                fade: _topographyFade,
              ),
            ),
          ),
      ],
    );
  }
}

class _TopographyPainter extends CustomPainter {
  _TopographyPainter({
    required this.pattern,
    required this.scroll,
    required this.fade,
  }) : super(repaint: Listenable.merge([scroll, fade]));

  final ui.Image pattern;
  final Animation<double> scroll;
  final Animation<double> fade;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = _kTopographyAlpha * fade.value;
    if (alpha <= 0) return;
    // Misma escala que Aurora, para que el patrón no cambie de tamaño al pasar a Login.
    final scale = size.width * 0.88 / _kPatternTile;
    // Un tile entero por vuelta: en scroll == 1.0 el patrón coincide con el de scroll == 0.0 (bucle sin salto).
    final offset = scroll.value * _kPatternTile * scale;
    final matrix =
        Matrix4.translationValues(offset, offset, 0) *
        Matrix4.diagonal3Values(scale, scale, 1);
    final paint = Paint()
      ..shader = ImageShader(
        pattern,
        TileMode.repeated,
        TileMode.repeated,
        matrix.storage,
      )
      ..colorFilter = ColorFilter.mode(
        _kTopographyTint.withValues(alpha: alpha),
        BlendMode.srcIn,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _TopographyPainter oldDelegate) =>
      oldDelegate.pattern != pattern;
}
