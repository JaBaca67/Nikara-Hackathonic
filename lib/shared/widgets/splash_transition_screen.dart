import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Reusable animated transition screen (Figma node 95:2, "Precarga"), styled
/// after the sober PedidosYa/Uber-style loading beat. Used after auth today;
/// any future flow that needs a branded pause between screens can reuse it.
class SplashTransitionScreen extends StatefulWidget {
  const SplashTransitionScreen({
    super.key,
    this.nextPage,
    this.duration = const Duration(milliseconds: 1800),
    this.onLoadingTask,
  });

  /// Screen to land on once [duration] (and [onLoadingTask], if any) finish.
  /// Left null for a purely decorative pause with no follow-up navigation.
  final Widget? nextPage;

  /// Minimum time this screen stays up, regardless of how fast
  /// [onLoadingTask] resolves.
  final Duration duration;

  /// Optional async work (token refresh, prefetching, …) to run alongside
  /// the animation. Navigation waits for both this and [duration].
  final Future<void> Function()? onLoadingTask;

  @override
  State<SplashTransitionScreen> createState() =>
      _SplashTransitionScreenState();
}

class _SplashTransitionScreenState extends State<SplashTransitionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      // Blocks the back gesture/button while the transition plays out.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.ecoGreen500,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              width: size.width,
              height: size.height,
              child: _SplashGradientBackground(size: size),
            ),
            Center(
              child: ScaleTransition(
                scale: _pulseScale,
                child: const _SplashLogo(),
              ),
            ),
          ],
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

/// Vertical gradient (eco green → gold → coral) plus the top-right glow,
/// matching the login header's decorative language (Figma node 95:6/95:8).
class _SplashGradientBackground extends StatelessWidget {
  const _SplashGradientBackground({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.62, -0.79),
          end: Alignment(0.62, 0.79),
          colors: [
            AppColors.ecoGreen500,
            AppColors.tagGold600,
            AppColors.coral500,
          ],
          stops: [0.0849, 0.417, 0.9151],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size.width * (262 / 390),
            top: size.height * (-32 / 844),
            child: Container(
              width: size.width * (160 / 390),
              height: size.width * (160 / 390),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.22),
                    AppColors.tagGold600.withValues(alpha: 0.10),
                    AppColors.tagGold600.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.3, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
