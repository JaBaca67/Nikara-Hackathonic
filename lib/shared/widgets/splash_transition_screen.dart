import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:nikara_app/shared/widgets/auth/auth_scene_backdrop.dart';
import 'package:nikara_app/shared/widgets/auth/nikara_logo_svg.dart';
import 'package:nikara_app/shared/widgets/auth/nikara_opening_logo.dart';
import 'package:nikara_app/shared/widgets/splash_backdrop.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Pantalla de transición animada reutilizable (Figma node 95:2, "Precarga"); hoy se usa tras auth, pero sirve para cualquier pausa de marca entre pantallas.
class SplashTransitionScreen extends StatefulWidget {
  const SplashTransitionScreen({
    super.key,
    this.nextPage,
    this.duration = const Duration(milliseconds: 1800),
    this.onLoadingTask,
    this.showIsotipoOnly = false,
  });

  /// Solo el isotipo, quieto desde el primer frame (sin fade, escala ni pulso), para que el paso desde el splash nativo de Android no tenga saltos.
  final bool showIsotipoOnly;

  /// Null para una pausa puramente decorativa sin navegación de seguimiento.
  final Widget? nextPage;

  /// Tiempo mínimo en pantalla, sin importar qué tan rápido resuelva [onLoadingTask].
  final Duration duration;

  /// Trabajo async opcional que corre junto a la animación; la navegación espera a ambos.
  final Future<void> Function()? onLoadingTask;

  @override
  State<SplashTransitionScreen> createState() => _SplashTransitionScreenState();
}

/// Cuándo arranca la apertura del logo, contado desde que aparece el splash. Con 1300 ms de animación, 450 ms de arranque la termina a los 1750 ms, justo antes de que [SplashTransitionScreen.duration] (1800 ms) navegue.
const Duration _kOpeningStart = Duration(milliseconds: 450);

/// Si las piezas llegan más tarde que esto, la apertura se omite en vez de quedar cortada por la navegación.
const Duration _kOpeningLatest = Duration(milliseconds: 550);

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
      curve: Curves.easeOut,
    );
    _introScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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

    if (widget.showIsotipoOnly) {
      // Parsear SVG en el primer frame retrasaría justo el frame que debe igualar a la pantalla nativa.
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepareOpening());
    } else {
      _introController.forward().whenComplete(() {
        if (mounted) _pulseController.repeat(reverse: true);
      });
    }
    _run();
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
        transitionDuration: const Duration(milliseconds: 500),
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
        // En el arranque, el color del splash nativo: es lo que se ve antes del primer frame de [SplashBackdrop].
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
                      // Se retira cuando las piezas del logo ya lo cubren (ver [_isotipoOpacity]).
                      opacity: _isotipoOpacity,
                      filterQuality: FilterQuality.high,
                      // TEMPORAL: diagnóstico de la precarga de main(); borrar tras confirmar.
                      frameBuilder: (context, child, frame, sync) {
                        if (kDebugMode) {
                          debugPrint(
                            'TEMPORAL isotipo: wasSynchronouslyLoaded=$sync frame=$frame',
                          );
                        }
                        return child;
                      },
                    ),
                  ),
                  if (_pieces case final pieces?)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: NikaraOpeningLogo(
                          pieces: pieces,
                          progress: _openingController,
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
                          final pulse = _introController.isCompleted
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
