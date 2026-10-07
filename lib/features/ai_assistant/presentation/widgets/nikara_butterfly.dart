import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Cambia el ritmo y la amplitud del aleteo de la mascota.
enum ButterflyMood { idle, thinking, happy }

/// Mariposa vectorizada de Mascota-Icono.jpg, con cuatro alas independientes.
/// Las seis piezas comparten lienzo y conservan los colores del isotipo.
class NikaraButterfly extends StatefulWidget {
  const NikaraButterfly({
    super.key,
    this.size = 96,
    this.mood = ButterflyMood.idle,
    this.animated = true,
  });

  final double size;
  final ButterflyMood mood;
  final bool animated;

  @override
  State<NikaraButterfly> createState() => _NikaraButterflyState();
}

class _NikaraButterflyState extends State<NikaraButterfly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationFor(widget.mood),
  );

  static Duration _durationFor(ButterflyMood mood) => switch (mood) {
    ButterflyMood.idle => const Duration(milliseconds: 2200),
    ButterflyMood.thinking => const Duration(milliseconds: 850),
    ButterflyMood.happy => const Duration(milliseconds: 1200),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(NikaraButterfly oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood ||
        oldWidget.animated != widget.animated) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (!widget.animated || AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    // repeat crea su simulación con este período; hay que renovarla cuando
    // cambia el estado, aunque el controlador ya esté animándose.
    _controller.duration = _durationFor(widget.mood);
    _controller.repeat(period: _durationFor(widget.mood));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = !widget.animated || AppMotion.reduced(context);
    final width = widget.size * 1024 / 1028;
    final wings = [
      _piece('ala_inferior_izquierda'),
      _piece('ala_inferior_derecha'),
      _piece('ala_superior_izquierda'),
      _piece('ala_superior_derecha'),
    ];
    final body = _piece('cuerpo');
    final antennae = _piece('antenas');

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final phase = _controller.value * 2 * math.pi;
              final lift = still ? 0.0 : (1 - math.cos(phase)) / 2;
              final shadowBlur = widget.size * (0.025 + lift * 0.015);
              final range = switch (widget.mood) {
                ButterflyMood.idle => 0.95,
                ButterflyMood.thinking => 1.10,
                ButterflyMood.happy => 1.22,
              };
              final floatOffset = still || widget.mood == ButterflyMood.thinking
                  ? 0.0
                  : math.sin(phase) * widget.size * 0.025;

              return Transform.translate(
                offset: Offset(0, -floatOffset),
                child: Transform(
                  alignment: const Alignment(-0.075, 0.167),
                  transform: Matrix4.identity()
                    ..rotateZ(still ? 0 : math.sin(phase) * 0.035),
                  child: SizedBox(
                    width: width,
                    height: widget.size,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        if (widget.animated)
                          IgnorePointer(
                            child: Transform.translate(
                              offset: Offset(
                                widget.size * 0.025,
                                widget.size * (0.045 + lift * 0.025),
                              ),
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: shadowBlur,
                                  sigmaY: shadowBlur,
                                ),
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    AppColors.textPrimary.withValues(
                                      alpha: 0.24 - lift * 0.08,
                                    ),
                                    BlendMode.srcIn,
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      for (var i = 0; i < wings.length; i++)
                                        _wing(
                                          wings[i],
                                          i,
                                          phase,
                                          range,
                                          still,
                                          shadow: true,
                                        ),
                                      body,
                                      antennae,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (var i = 0; i < wings.length; i++)
                          _wing(wings[i], i, phase, range, still),
                        body,
                        antennae,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _wing(
    Widget child,
    int index,
    double phase,
    double range,
    bool still, {
    bool shadow = false,
  }) {
    final lower = index < 2;
    final side = index.isEven ? -1.0 : 1.0;
    // Las alas inferiores siguen a las superiores con un pequeño retraso.
    final closed = still
        ? 0.0
        : (1 - math.cos(phase - (lower ? 0.22 : 0.0))) / 2;
    final angle = closed * range * (lower ? 0.88 : 1.0);
    final transform = Matrix4.identity();
    if (!still && widget.size > 0) {
      // La perspectiva se adapta al tamaño del widget. Ambas alas pliegan
      // hacia el observador y conservan su unión con el cuerpo.
      transform
        ..setEntry(3, 2, -0.65 / widget.size)
        ..rotateY(side * angle)
        ..rotateX((lower ? -1 : 1) * angle * 0.10);
    }
    return Transform(
      key: shadow ? null : ValueKey('butterfly-wing-$index'),
      alignment: Alignment(
        2 * (index.isEven ? 437 : 510) / 1024 - 1,
        2 * 600 / 1028 - 1,
      ),
      transform: transform,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: closed * (lower ? 0.18 : 0.12)),
          BlendMode.srcATop,
        ),
        child: child,
      ),
    );
  }

  // Los widgets SVG se construyen fuera del AnimatedBuilder para reutilizar
  // su renderizado: cada fotograma solo modifica las transformaciones.
  Widget _piece(String name) => SvgPicture.asset(
    'assets/images/mascota_nikara_$name.svg',
    fit: BoxFit.fill,
    excludeFromSemantics: true,
  );
}
