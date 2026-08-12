import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Full-bleed animated "aurora/olas" background — 3 soft radial-gradient
/// blobs drifting in slow sine/cosine orbits over the brand gradient.
///
/// PERFORMANCE CONTRACT: the animation ticks entirely inside its own
/// [AnimationController], isolated in a [RepaintBoundary] around only the
/// [CustomPaint] layer. [child] sits as a sibling in the same [Stack], one
/// layer above — it is never inside the [AnimatedBuilder]'s `builder`, so
/// a screen putting a whole login/register form in [child] gets zero
/// extra rebuilds from the background animation; the ticker never touches
/// `setState` on anything outside this widget.
///
/// No [MaskFilter.blur] is used for the blob "glow" — that's a real
/// per-frame GPU/CPU cost. The soft edge comes from [RadialGradient]'s
/// built-in fade-to-transparent instead, which is effectively free (a
/// plain shader), keeping this smooth even on low-end devices.
class AuroraBackgroundWidget extends StatefulWidget {
  const AuroraBackgroundWidget({super.key, this.child});

  final Widget? child;

  @override
  State<AuroraBackgroundWidget> createState() =>
      _AuroraBackgroundWidgetState();
}

class _AuroraBackgroundWidgetState extends State<AuroraBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
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
        // Base brand gradient — painted once, never touched by the ticker.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.65, -0.76),
              end: Alignment(0.65, 0.76),
              colors: [
                AppColors.primary500,
                Color(0xFFFFCC33),
                AppColors.primary400,
              ],
              stops: [0.0893, 0.4265, 0.9323],
            ),
          ),
        ),
        // The ONLY layer that repaints every tick. RepaintBoundary keeps
        // that continuous repaint from propagating to the base gradient
        // below or to `child` above.
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

    _blob(
      canvas,
      color: AppColors.accent300,
      alpha: 0.28,
      center: Offset(
        size.width * (0.18 + 0.10 * math.sin(t)),
        size.height * (0.20 + 0.06 * math.cos(t)),
      ),
      radius: size.width * 0.55,
    );
    _blob(
      canvas,
      color: Colors.white,
      alpha: 0.18,
      center: Offset(
        size.width * (0.85 + 0.07 * math.cos(t * 0.8)),
        size.height * (0.10 + 0.05 * math.sin(t * 0.8)),
      ),
      radius: size.width * 0.42,
    );
    _blob(
      canvas,
      color: AppColors.coral500,
      alpha: 0.22,
      center: Offset(
        size.width * (0.5 + 0.12 * math.sin(t * 1.3 + 1)),
        size.height * (0.88 + 0.05 * math.cos(t * 1.3)),
      ),
      radius: size.width * 0.6,
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
        colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
