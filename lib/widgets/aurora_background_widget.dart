import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Fondo animado "aurora/olas" con 3 blobs de gradiente radial en órbitas sinusoidales sobre el gradiente de marca.
/// Contrato de performance: el ticker vive aislado en un [RepaintBoundary] alrededor de [CustomPaint] únicamente, así [child] nunca se rebuildea por la animación; el "glow" usa el fade nativo de [RadialGradient] en vez de [MaskFilter.blur] (costoso por frame) para rendir bien en gama baja.
class AuroraBackgroundWidget extends StatefulWidget {
  const AuroraBackgroundWidget({super.key, this.child});

  final Widget? child;

  @override
  State<AuroraBackgroundWidget> createState() => _AuroraBackgroundWidgetState();
}

class _AuroraBackgroundWidgetState extends State<AuroraBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradiente base, pintado una sola vez, nunca tocado por el ticker (Figma node 636:912).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AppGradients.authBackgroundBegin,
              end: AppGradients.authBackgroundEnd,
              colors: AppGradients.authBackgroundColors,
              stops: AppGradients.authBackgroundStops,
            ),
          ),
        ),
        // Única capa que repinta cada tick; el RepaintBoundary evita que eso se propague al gradiente base o a `child`.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AuroraPainter(progress: _controller.value),
              );
            },
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // Cada oscilador usa un múltiplo ENTERO de `t` a propósito: así sin/cos coinciden en ambos extremos del ciclo y el loop no se corta visiblemente (un múltiplo no entero sí producía un salto).
    _blob(
      canvas,
      color: AppColors.accent300,
      alpha: 0.55,
      center: Offset(
        size.width * (0.18 + 0.3 * math.sin(t)),
        size.height * (0.20 + 0.18 * math.cos(t)),
      ),
      radius: size.width * 0.65,
    );
    _blob(
      canvas,
      color: Colors.white,
      alpha: 0.38,
      center: Offset(
        size.width * (0.82 + 0.22 * math.cos(t * 2 + 1.1)),
        size.height * (0.12 + 0.16 * math.sin(t * 2 + 1.1)),
      ),
      radius: size.width * 0.5,
    );
    _blob(
      canvas,
      color: AppColors.coral500,
      alpha: 0.46,
      center: Offset(
        size.width * (0.5 + 0.34 * math.sin(t * 2 + 3.4)),
        size.height * (0.86 + 0.16 * math.cos(t * 2 + 3.4)),
      ),
      radius: size.width * 0.7,
    );
    _blob(
      canvas,
      color: AppColors.sunsetMid1,
      alpha: 0.42,
      center: Offset(
        size.width * (0.35 + 0.28 * math.cos(t * 3 - 1.4)),
        size.height * (0.55 + 0.22 * math.sin(t * 3 - 1.4)),
      ),
      radius: size.width * 0.55,
    );

    // Glow ambiental "respirando" arriba a la derecha, 3 pulsos por loop.
    final breathe = 0.5 + 0.5 * (0.5 + 0.5 * math.sin(t * 3));
    _blob(
      canvas,
      color: Colors.white,
      alpha: 0.42 * breathe,
      center: Offset(size.width * 0.82, size.height * 0.06),
      radius: size.width * 0.36,
    );
  }

  void _blob(
    Canvas canvas, {
    required Color color,
    required double alpha,
    required Offset center,
    required double radius,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
