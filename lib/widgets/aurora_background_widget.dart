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
        // Base brand gradient — painted once, never touched by the ticker.
        // Figma node 636:912 ("UI-NÍKARA"), reused unmodified across
        // Splash/Login/Register — see [AppGradients.authBackgroundColors].
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

    // Every oscillator below uses an INTEGER multiple of `t` (1, 2, or 3).
    // That's not a style choice — it's what makes the loop seamless.
    // `progress` wraps 1→0 every cycle, so `t` wraps 2π→0; sin/cos of an
    // integer multiple of `t` land on the exact same value at both ends
    // (sin(2π·k) == sin(0) for integer k), so nothing jumps. A non-integer
    // multiplier (the previous 0.85/1.3/1.6/breathe-ratio-2.8) does NOT
    // return to its starting phase at the wrap, which is exactly what
    // produced the visible "cut" each loop.
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

    // Ambient "breathing" glow, top-right — 3 pulses per loop.
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
