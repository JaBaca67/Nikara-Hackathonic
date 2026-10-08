import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/auth/auth_scene_backdrop.dart';
import 'package:nikara_app/shared/widgets/auth/nikara_logo_svg.dart';
import 'package:nikara_app/shared/widgets/auth/nikara_opening_logo.dart';
import 'package:nikara_app/shared/widgets/splash_backdrop.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Pantalla de transición animada reutilizable (Figma node 95:2, "Precarga"); hoy se usa tras auth, pero sirve para cualquier pausa de marca entre pantallas.
class SplashTransitionScreen extends StatefulWidget {
  const SplashTransitionScreen({
    super.key,
    this.nextPage,
    this.duration = const Duration(milliseconds: 1800),
    this.onLoadingTask,
    this.showIsotipoOnly = false,
    this.ascendToAuth = true,
  });

  /// Solo el isotipo, quieto desde el primer frame (sin fade, escala ni pulso), para que el paso desde el splash nativo de Android no tenga saltos.
  final bool showIsotipoOnly;

  /// Solo aplica con [showIsotipoOnly]. `true` (el destino es Login): tras
  /// abrirse, el logo sube a su posición en el sheet de Auth. `false` (el
  /// destino es Inicio, ya con sesión): el logo se queda centrado en
  /// pantalla hasta que navega — no hay sheet al que subir.
  final bool ascendToAuth;

  /// Null para una pausa puramente decorativa sin navegación de seguimiento.
  final Widget? nextPage;

  /// Tiempo mínimo en pantalla, sin importar qué tan rápido resuelva [onLoadingTask].
  final Duration duration;

  /// Trabajo async opcional que corre junto a la animación; la navegación espera a ambos.
  final Future<void> Function()? onLoadingTask;

  @override
  State<SplashTransitionScreen> createState() => _SplashTransitionScreenState();
}

/// Cuándo arranca la apertura del logo si las piezas llegan a tiempo, contado desde que aparece el splash. En la práctica casi nunca manda: en dispositivo real las piezas llegan después de este punto (ver [_kOpeningLatest]) y la apertura arranca apenas están listas, no a los 450ms.
const Duration _kOpeningStart = Duration(milliseconds: 450);

/// Si las piezas llegan más tarde que esto, la apertura se omite en vez de quedar cortada por la navegación.
///
/// 550ms (valor original de la rama) se quedaba corto en dispositivo real: en
/// un Samsung A56 las piezas llegaron a los 697-715ms en pruebas repetidas
/// (cold start y con la app ya tibia), así que la apertura nunca disparaba.
/// 900ms deja margen sobre ese peor caso medido. Ver también la duración de
/// [SplashTransitionScreen] pasada en `app.dart`, ajustada para que la
/// animación completa (hasta 900ms de arranque + 1300ms de duración) quepa
/// antes de que la navegación corte la pantalla.
const Duration _kOpeningLatest = Duration(milliseconds: 900);

/// Espera antes de parsear los SVG del logo, para no coincidir con el parseo de la topografía de [SplashBackdrop] (ambos bloquean el hilo principal).
const Duration _kOpeningLoadDelay = Duration(milliseconds: 250);

class _SplashTransitionScreenState extends State<SplashTransitionScreen>
    with TickerProviderStateMixin {
  /// Animación de entrada del logo; el pulso continuo de abajo solo arranca después de que esta termina.
  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<double> _introScale;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  bool _navigated = false;
  bool _animationsStarted = false;
  bool _reduceMotion = false;

  /// Apertura del logo (solo modo de arranque): un único controlador para toda la animación.
  late final AnimationController _openingController;

  /// El PNG nativo se retira cuando las piezas del logo ya lo cubren del todo.
  late final Animation<double> _isotipoOpacity;
  final Stopwatch _sinceStart = Stopwatch()..start();
  NikaraLogoPieces? _pieces;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _introFade = CurvedAnimation(
      parent: _introController,
      curve: AppMotion.enter,
    );
    _introScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: AppMotion.overshoot),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: AppMotion.standard),
    );

    _openingController = AnimationController(
      vsync: this,
      duration: kNikaraOpeningDuration,
    );
    _isotipoOpacity = ReverseAnimation(
      CurvedAnimation(
        parent: _openingController,
        curve: const Interval(
          kNikaraOpeningCrossfadeEnd,
          kNikaraOpeningCrossfadeEnd + 0.001,
        ),
      ),
    );

    _run();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduced(context);
    if (_animationsStarted) return;
    _animationsStarted = true;

    if (widget.showIsotipoOnly) {
      // Con el ajuste activo el isotipo queda quieto en su estado final (ver
      // [_isotipoOpacity] con el controlador en 0): ni la apertura al logo
      // completo ni el fondo animado de [SplashBackdrop] llegan a arrancar.
      if (_reduceMotion) return;
      // Parsear SVG en el primer frame retrasaría justo el frame que debe igualar a la pantalla nativa.
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepareOpening());
      return;
    }

    if (_reduceMotion) {
      // Logo directo en su estado final: sin entrada escalada ni pulso. El
      // temporizador de `_run()` sigue corriendo, así que la navegación pasa
      // igual — solo se va el movimiento.
      _introController.value = 1.0;
      return;
    }
    _introController.forward().whenComplete(() {
      if (mounted) _pulseController.repeat(reverse: true);
    });
  }

  /// Rasteriza las piezas del logo y lanza la apertura. Si llegan tarde la omite: una apertura cortada por la navegación se vería peor que ninguna.
  Future<void> _prepareOpening() async {
    await Future<void>.delayed(_kOpeningLoadDelay);
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final loadTimer = Stopwatch()..start();
    final pieces = await NikaraLogoPieces.load(
      screenSize: size,
      devicePixelRatio: pixelRatio,
    );
    if (kDebugMode) {
      debugPrint(
        'Splash: piezas del logo listas en ${loadTimer.elapsedMilliseconds} ms '
        '(a los ${_sinceStart.elapsedMilliseconds} ms del inicio)',
      );
    }
    if (!mounted || _sinceStart.elapsed > _kOpeningLatest) {
      if (kDebugMode && mounted) {
        debugPrint('Splash: apertura omitida, las piezas llegaron tarde');
      }
      pieces.dispose();
      return;
    }
    setState(() => _pieces = pieces);
    final wait = _kOpeningStart - _sinceStart.elapsed;
    if (!wait.isNegative) await Future<void>.delayed(wait);
    if (!mounted) return;
    _openingController.forward();
  }

  Future<void> _run() async {
    final loadingTask = widget.onLoadingTask?.call() ?? Future<void>.value();
    await Future.wait([Future<void>.delayed(widget.duration), loadingTask]);
    _goToNextPage();
  }

  void _goToNextPage() {
    if (!mounted || _navigated) return;
    final next = widget.nextPage;
    if (next == null) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    _openingController.dispose();
    _pieces?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Bloquea el gesto/botón de back mientras dura la transición.
      canPop: false,
      child: Scaffold(
        // En el arranque, el color del splash nativo: es lo que se ve antes de que [SplashBackdrop] pinte su primer frame.
        backgroundColor: widget.showIsotipoOnly
            ? AppColors.sunsetStart
            : AppColors.oliveMidFill,
        body: widget.showIsotipoOnly
            ? Stack(
                fit: StackFit.expand,
                children: [
                  const SplashBackdrop(),
                  // Fuera del backdrop animado: el isotipo no se repinta ni se anima. Mismo raster que el splash nativo (1152 px = 288 dp, isotipo visible ~120 dp).
                  Center(
                    child: Image.asset(
                      'assets/images/isotipo_nikara_splash.png',
                      width: 288,
                      height: 288,
                      // Se retira cuando las piezas del logo ya lo cubren (ver [_isotipoOpacity]). Con el ajuste de accesibilidad activo el controlador nunca arranca, así que queda totalmente opaco.
                      opacity: _isotipoOpacity,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  if (_pieces case final pieces?)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: NikaraOpeningLogo(
                          pieces: pieces,
                          progress: _openingController,
                          ascendToAuth: widget.ascendToAuth,
                        ),
                      ),
                    ),
                ],
              )
            : AuthSceneBackdrop(
                // El logo del Splash va centrado, no en la franja de arriba como en Auth.
                logoFocusY: 0.5,
                showIllustrations: false,
                child: Center(
                  child: Padding(
                    // FittedBox evita cortes en pantallas angostas aunque el logo pida más ancho del disponible.
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _introController,
                          _pulseController,
                        ]),
                        builder: (context, child) {
                          final pulse =
                              _introController.isCompleted && !_reduceMotion
                              ? _pulseScale.value
                              : 1.0;
                          return Opacity(
                            opacity: _introFade.value,
                            child: Transform.scale(
                              scale: _introScale.value * pulse,
                              child: child,
                            ),
                          );
                        },
                        child: const NikaraLogoSvg(height: 220),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
