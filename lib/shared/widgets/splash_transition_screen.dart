import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';
import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// Pantalla de transición animada reutilizable (Figma node 95:2, "Precarga"); hoy se usa tras auth, pero sirve para cualquier pausa de marca entre pantallas.
class SplashTransitionScreen extends StatefulWidget {
  const SplashTransitionScreen({
    super.key,
    this.nextPage,
    this.duration = const Duration(milliseconds: 1800),
    this.onLoadingTask,
  });

  /// Null para una pausa puramente decorativa sin navegación de seguimiento.
  final Widget? nextPage;

  /// Tiempo mínimo en pantalla, sin importar qué tan rápido resuelva [onLoadingTask].
  final Duration duration;

  /// Trabajo async opcional que corre junto a la animación; la navegación espera a ambos.
  final Future<void> Function()? onLoadingTask;

  @override
  State<SplashTransitionScreen> createState() => _SplashTransitionScreenState();
}

class _SplashTransitionScreenState extends State<SplashTransitionScreen>
    with TickerProviderStateMixin {
  /// Animación de entrada del logo; el pulso continuo de abajo solo arranca después de que esta termina.
  late final AnimationController _introController;
  late final Animation<double> _introFade;
  late final Animation<double> _introScale;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  bool _navigated = false;

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

    _introController.forward().whenComplete(() {
      if (mounted) _pulseController.repeat(reverse: true);
    });
    _run();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Bloquea el gesto/botón de back mientras dura la transición.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.secundario6,
        body: AuroraBackgroundWidget(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _pulseController]),
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
              child: const _SplashLogo(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/nikara_logo.png',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        Text('NÍKARA', style: AppTextStyles.logoWordmark),
      ],
    );
  }
}
