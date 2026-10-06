import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_motion.dart';

/// Estado de ánimo de la mascota. Cambia el ritmo del aleteo y la postura, no
/// el dibujo: es la misma mariposa en distintos momentos.
enum ButterflyMood {
  /// En reposo: aletea lento y flota. Es el estado por defecto.
  idle,

  /// El asistente está consultando al modelo — aletea rápido, como ocupada.
  thinking,

  /// Acaba de responder algo bueno (una ruta guardada): un aleteo amplio.
  happy,
}

/// La mascota de Níkara: el isotipo convertido en mariposa.
///
/// ## Por qué está dibujada en código y no es el SVG
///
/// El isotipo ya **es** una mariposa — las dos hojas que acompañan a la "N"
/// son alas. Pero en un SVG esas hojas son dos paths dentro de una sola
/// figura, así que animarlas por separado obligaría a parsear y recomponer el
/// archivo. Dibujarla con un [CustomPainter] permite que cada ala se mueva
/// sola, que es lo único que distingue una mascota viva de un logo que se mece.
///
/// ## Colores
///
/// Usa los tres colores del isotipo (`assets/images/isotipo_nikara.svg`), no
/// los tokens de UI: el marrón `#491B00`, el naranja `#FC4403` y el verde
/// `#5B821C`. Es deliberado y es la única excepción del módulo — un isotipo
/// tiene sus colores propios igual que el logotipo en Auth; no son acentos de
/// marca sueltos sobre una pantalla, son la identidad misma.
class NikaraButterfly extends StatefulWidget {
  const NikaraButterfly({
    super.key,
    this.size = 96,
    this.mood = ButterflyMood.idle,
  });

  final double size;
  final ButterflyMood mood;

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
    ButterflyMood.idle => const Duration(milliseconds: 2600),
    ButterflyMood.thinking => const Duration(milliseconds: 900),
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
    if (oldWidget.mood != widget.mood) {
      _controller.duration = _durationFor(widget.mood);
      _syncAnimation();
    }
  }

  /// El aleteo es una animación continua, así que respeta "Eliminar
  /// animaciones" del sistema: con el ajuste activo la mariposa queda en una
  /// pose fija en vez de moverse sin parar. Se consulta acá y no en
  /// `initState` para que reaccione si el ajuste cambia con la pantalla
  /// abierta.
  void _syncAnimation() {
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 0.35;
      return;
    }
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final phase = _controller.value;
          // Una sinusoide da el ir y venir del ala sin saltos entre ciclos.
          final wave = math.sin(phase * 2 * math.pi);

          final flapRange = switch (widget.mood) {
            ButterflyMood.idle => 0.16,
            ButterflyMood.thinking => 0.34,
            ButterflyMood.happy => 0.46,
          };
          // 1.0 es el ala abierta de frente; al cerrarse se acorta en
          // horizontal, que es como se ve un aleteo real en perspectiva.
          final flap = 1 - flapRange * (0.5 + 0.5 * wave);

          // Flota: sube y baja la mitad de rápido que el aleteo, para que los
          // dos movimientos no queden sincronizados y se vea mecánico.
          final floatOffset = widget.mood == ButterflyMood.thinking
              ? 0.0
              : math.sin(phase * math.pi) * widget.size * 0.035;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Transform.translate(
              offset: Offset(0, -floatOffset),
              child: CustomPaint(
                painter: _ButterflyPainter(flap: flap),
                size: Size.square(widget.size),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ButterflyPainter extends CustomPainter {
  const _ButterflyPainter({required this.flap});

  /// Qué tan abierta está el ala en horizontal: 1 = de frente, <1 = cerrándose.
  final double flap;

  // Los tres colores del isotipo. Ver la nota de la clase pública.
  static const _brown = Color(0xFF491B00);
  static const _orange = Color(0xFFFC4403);
  static const _green = Color(0xFF5B821C);
  static const _paper = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    // Todo se define en coordenadas 0..1 y se escala: así la mariposa se ve
    // igual a 32px que a 200px.
    Offset p(double x, double y) => Offset(x * s, y * s);

    final bodyCenter = p(0.5, 0.52);

    // --- Alas -------------------------------------------------------------
    // Cada par se dibuja con el eje X escalado alrededor del cuerpo, lo que
    // produce el aleteo sin recalcular la geometría.
    void withFlap(void Function() draw) {
      canvas.save();
      canvas.translate(bodyCenter.dx, 0);
      canvas.scale(flap, 1);
      canvas.translate(-bodyCenter.dx, 0);
      draw();
      canvas.restore();
    }

    withFlap(() {
      // Inferiores primero: las superiores se superponen encima, igual que en
      // el isotipo.
      _drawWing(canvas, s, p(0.5, 0.58), p(0.16, 0.93), 0.13, _green);
      _drawWing(canvas, s, p(0.5, 0.58), p(0.84, 0.93), -0.13, _green);
      _drawWing(canvas, s, p(0.5, 0.45), p(0.10, 0.19), -0.15, _orange);
      _drawWing(canvas, s, p(0.5, 0.45), p(0.90, 0.19), 0.15, _orange);
    });

    // --- Cuerpo -----------------------------------------------------------
    // Afinado hacia abajo en vez de un rectangulo: con lados rectos la mascota
    // se leia como "dos hojas pegadas a un palo" y no como un insecto.
    final bodyPaint = Paint()..color = _brown;
    final halfWidth = s * 0.042;

    canvas.drawPath(
      Path()
        ..moveTo(bodyCenter.dx - halfWidth, s * 0.36)
        ..lineTo(bodyCenter.dx - halfWidth * 0.92, s * 0.58)
        // Las dos curvas cierran el abdomen en punta redondeada.
        ..quadraticBezierTo(
          bodyCenter.dx - halfWidth * 0.75,
          s * 0.74,
          bodyCenter.dx,
          s * 0.75,
        )
        ..quadraticBezierTo(
          bodyCenter.dx + halfWidth * 0.75,
          s * 0.74,
          bodyCenter.dx + halfWidth * 0.92,
          s * 0.58,
        )
        ..lineTo(bodyCenter.dx + halfWidth, s * 0.36)
        ..close(),
      bodyPaint,
    );

    // La cabeza va despues de las alas para que asome por encima: es lo que
    // deja que las antenas nazcan de ella y no del medio del ala.
    canvas.drawCircle(p(0.5, 0.345), s * 0.058, bodyPaint);

    // --- Antenas ----------------------------------------------------------
    // Guino a los tres destellos que el isotipo tiene sobre la "N".
    final antenna = Paint()
      ..color = _brown
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.026
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(s * 0.475, s * 0.315)
        ..quadraticBezierTo(s * 0.40, s * 0.20, s * 0.325, s * 0.125),
      antenna,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.525, s * 0.315)
        ..quadraticBezierTo(s * 0.60, s * 0.20, s * 0.675, s * 0.125),
      antenna,
    );
    // Las bolitas de la punta son lo que vuelve "antena" a una linea curva.
    canvas.drawCircle(p(0.325, 0.125), s * 0.026, bodyPaint);
    canvas.drawCircle(p(0.675, 0.125), s * 0.026, bodyPaint);
  }

  /// Una hoja del isotipo: dos curvas que se encuentran en las puntas, con el
  /// doble contorno (blanco por dentro, marrón por fuera) que es la firma
  /// visual de la marca, y la nervadura central.
  void _drawWing(
    Canvas canvas,
    double s,
    Offset base,
    Offset tip,
    double bulge,
    Color fill,
  ) {
    final axis = tip - base;
    final perpendicular = Offset(-axis.dy, axis.dx);
    final length = axis.distance;
    if (length == 0) return;
    final unit = perpendicular / length;

    final control1 = base + axis * 0.5 + unit * (bulge * s * 2.4);
    final control2 = base + axis * 0.5 - unit * (bulge * s * 0.9);

    final wing = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(control1.dx, control1.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(control2.dx, control2.dy, base.dx, base.dy)
      ..close();

    // Orden: contorno marrón ancho, contorno blanco encima, relleno al final.
    // Pintar en este orden evita tener que calcular tres paths distintos.
    canvas.drawPath(
      wing,
      Paint()
        ..color = _brown
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.085
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      wing,
      Paint()
        ..color = _paper
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.048
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(wing, Paint()..color = fill);

    // Nervadura: no llega hasta la punta, igual que en el isotipo.
    final veinEnd = base + axis * 0.78;
    final veinControl = base + axis * 0.45 + unit * (bulge * s * 0.55);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          veinControl.dx,
          veinControl.dy,
          veinEnd.dx,
          veinEnd.dy,
        ),
      Paint()
        ..color = _paper
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ButterflyPainter oldDelegate) => oldDelegate.flap != flap;
}
