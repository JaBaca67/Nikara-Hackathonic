import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Duración de un ciclo completo. Es largo a propósito: un fondo ambiental que
/// se recorre en pocos segundos se lee como "algo girando" en vez de como luz
/// que cambia — era la queja concreta sobre la versión anterior (7s).
const Duration _kAuroraCycle = Duration(seconds: 24);

/// Lado del tile del patrón topográfico, en px de su propio viewBox.
const int _kPatternTile = 600;

/// Fondo animado "aurora" de las pantallas de Auth (tier Expresiva, la única
/// autorizada a combinar los 3 `Fill` de marca).
///
/// Se pinta en capas: gradiente base -> blobs de luz en movimiento -> halo
/// dorado fijo bajo el logo -> hojas de marca de agua -> patrón topográfico.
///
/// Cada blob es uno de los primitivos de marca — Gold, Olive y Orange.
/// **Ningún blob usa `oliveText` ni blanco puro**: `oliveText` es un color de
/// texto (oscuro por diseño, para contraste AA) y como relleno ensuciaba el
/// fondo de verde; el blanco puro fijo se leía como un foco girando en bucle.
///
/// Contrato de performance: el ticker vive aislado en un [RepaintBoundary]
/// alrededor de [CustomPaint] únicamente, así [child] nunca se rebuildea por la
/// animación; el "glow" usa el fade nativo de [RadialGradient] en vez de
/// [MaskFilter.blur] (costoso por frame) para rendir bien en gama baja, y el
/// patrón se repite por GPU con un [ImageShader] en vez de dibujar N copias.
class AuroraBackgroundWidget extends StatefulWidget {
  const AuroraBackgroundWidget({super.key, this.child, this.logoFocusY = 0.16});

  final Widget? child;

  /// Altura (fracción de la pantalla) donde queda el logo. Marca la zona que
  /// los blobs esquivan y sobre la que se pinta el halo dorado, para que el
  /// logo se lea siempre sobre amarillo y ninguna luz le pase por encima.
  /// El Splash lo centra (0.5); Auth lo deja arriba, sobre el sheet.
  final double logoFocusY;

  @override
  State<AuroraBackgroundWidget> createState() => _AuroraBackgroundWidgetState();
}

class _AuroraBackgroundWidgetState extends State<AuroraBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kAuroraCycle,
  )..repeat();

  ui.Image? _pattern;

  @override
  void initState() {
    super.initState();
    _loadPattern();
  }

  /// Rasteriza el tile del patrón una sola vez; el painter lo repite con un
  /// shader, así el costo por frame no depende de cuántas veces se vea.
  Future<void> _loadPattern() async {
    final info = await vg.loadPicture(
      const SvgAssetLoader('assets/images/topography.svg'),
      null,
    );
    final image = await info.picture.toImage(_kPatternTile, _kPatternTile);
    info.picture.dispose();
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _pattern = image);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pattern?.dispose();
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
                painter: _AuroraPainter(
                  progress: _controller.value,
                  focusY: widget.logoFocusY,
                  pattern: _pattern,
                ),
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
  const _AuroraPainter({
    required this.progress,
    required this.focusY,
    required this.pattern,
  });

  final double progress;
  final double focusY;
  final ui.Image? pattern;

  double get t => progress * 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    // Las órbitas viven en los bordes: el centro de la franja del logo queda
    // libre para que ninguna luz le pase por dentro. Con la tarjeta de Auth
    // abierta esa franja es lo único que se ve del fondo, así que los tres
    // primitivos tienen que convivir ahí sin invadirla.
    _blob(
      canvas,
      size,
      color: AppColors.oliveFill,
      alpha: 0.68,
      cx: 0.02,
      cy: 0.08,
      ax: 0.09,
      ay: 0.06,
      phase: 0.0,
      radius: 0.40,
    );
    _blob(
      canvas,
      size,
      color: AppColors.coral500,
      alpha: 0.34,
      cx: 0.99,
      cy: 0.07,
      ax: 0.08,
      ay: 0.06,
      phase: 2.1,
      radius: 0.38,
    );
    _blob(
      canvas,
      size,
      color: AppColors.goldFill,
      alpha: 0.55,
      cx: 0.50,
      cy: 0.46,
      ax: 0.22,
      ay: 0.12,
      phase: 4.0,
      radius: 0.60,
    );
    // Refuerzo cálido de la mitad inferior, visible cuando el sheet baja.
    _blob(
      canvas,
      size,
      color: AppColors.coral500,
      alpha: 0.26,
      cx: 0.30,
      cy: 0.92,
      ax: 0.20,
      ay: 0.08,
      phase: 1.2,
      radius: 0.62,
    );

    _logoHalo(canvas, size);
    _leaves(canvas, size);
    _topography(canvas, size);
  }

  /// Colchón dorado fijo bajo el logo. Es lo que garantiza que el logo se lea
  /// siempre sobre amarillo: se pinta después de los blobs, así aunque uno pase
  /// cerca no le tiñe el fondo.
  void _logoHalo(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * focusY);
    final radius = size.width * 0.78;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.goldFill.withValues(alpha: 0.85),
          AppColors.goldFill.withValues(alpha: 0.55),
          AppColors.goldFill.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  /// Hojas de marca de agua en las esquinas superiores, como en la referencia.
  /// Se dibujan con [Path] en vez de con un asset: así el color sale de los
  /// tokens y el tamaño se adapta al ancho real de la pantalla.
  void _leaves(Canvas canvas, Size size) {
    // Nacen fuera del lienzo y entran hacia adentro, como en la referencia: una
    // hoja completa flotando en el medio se leería como un objeto, no como
    // textura de fondo.
    //
    // La mitad inferior lleva las suyas porque el sheet de Auth se puede bajar
    // y deja el fondo entero a la vista: con hojas solo arriba, esa mitad se
    // veía vacía. Van algo más tenues para no competir con el logo.
    const specs = <({double x, double y, double len, double turn, double a})>[
      (x: -0.06, y: -0.02, len: 0.52, turn: -0.62, a: 0.13),
      (x: 0.22, y: -0.05, len: 0.34, turn: -1.20, a: 0.10),
      (x: 1.04, y: 0.01, len: 0.46, turn: 2.62, a: 0.12),
      (x: 0.78, y: -0.04, len: 0.30, turn: 2.15, a: 0.09),
      (x: 0.96, y: 0.26, len: 0.30, turn: 1.90, a: 0.15),
      (x: -0.05, y: 0.44, len: 0.40, turn: -0.30, a: 0.10),
      (x: 1.06, y: 0.56, len: 0.44, turn: 2.90, a: 0.11),
      (x: 0.14, y: 0.74, len: 0.34, turn: -1.55, a: 0.09),
      (x: 0.90, y: 0.86, len: 0.38, turn: 2.35, a: 0.10),
      (x: 0.44, y: 1.06, len: 0.42, turn: 3.55, a: 0.09),
      (x: -0.02, y: 1.02, len: 0.30, turn: 3.95, a: 0.08),
    ];
    for (final s in specs) {
      canvas.save();
      canvas.translate(size.width * s.x, size.height * s.y);
      canvas.rotate(s.turn);
      _leaf(
        canvas,
        size.width * s.len,
        AppColors.oliveText.withValues(alpha: s.a),
      );
      canvas.restore();
    }
  }

  /// Hoja lanceolada: dos curvas simétricas, nervadura central y venas
  /// laterales. Las venas se dibujan en negativo (borran parte del relleno) —
  /// sin ellas la silueta se leía como una mancha, no como una hoja.
  void _leaf(Canvas canvas, double length, Color color) {
    final w = length * 0.44;
    final body = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(w, length * 0.34, 0, length)
      ..quadraticBezierTo(-w, length * 0.34, 0, 0)
      ..close();

    // saveLayer para que el BlendMode.dstOut de las venas recorte solo esta
    // hoja y no lo que ya está pintado debajo.
    canvas.saveLayer(body.getBounds().inflate(length * 0.05), Paint());
    canvas.drawPath(body, Paint()..color = color);

    final vein = Paint()
      ..blendMode = BlendMode.dstOut
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = math.max(1.0, length * 0.018);
    // Nervadura central.
    canvas.drawLine(Offset(0, length * 0.04), Offset(0, length * 0.96), vein);
    // Venas laterales, en pares que se abren hacia la punta.
    for (var i = 1; i <= 4; i++) {
      final at = 0.16 + i * 0.17;
      final reach = w * (1 - (at - 0.5).abs()) * 0.78;
      for (final side in const [1.0, -1.0]) {
        canvas.drawLine(
          Offset(0, length * at),
          Offset(side * reach, length * (at + 0.13)),
          vein,
        );
      }
    }
    canvas.restore();
  }

  /// Textura topográfica sobre todo el fondo. Va en negro a opacidad muy baja:
  /// oscurece apenas el relieve sin aportar color propio, que es lo que evita
  /// que compita con los tres primitivos de marca.
  void _topography(Canvas canvas, Size size) {
    final image = pattern;
    if (image == null) return;
    // El tile se dibuja más chico que su tamaño de diseño para que las curvas
    // queden finas y densas, como en la referencia, en vez de ampliadas.
    final scale = size.width * 0.88 / _kPatternTile;
    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.diagonal3Values(scale, scale, 1).storage,
      )
      ..colorFilter = ColorFilter.mode(
        AppColors.textPrimary.withValues(alpha: 0.07),
        BlendMode.srcIn,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  /// Dibuja un blob cuyo centro deriva sobre una trayectoria de dos armónicos.
  ///
  /// Ambos armónicos son múltiplos ENTEROS de `t`, condición para que el ciclo
  /// cierre sin salto visible; el segundo, más rápido y de menor amplitud,
  /// deforma la elipse lo suficiente para que el recorrido no se lea como una
  /// órbita circular — que es lo que hacía la versión anterior.
  void _blob(
    Canvas canvas,
    Size size, {
    required Color color,
    required double alpha,
    required double cx,
    required double cy,
    required double ax,
    required double ay,
    required double phase,
    required double radius,
  }) {
    final center = Offset(
      size.width *
          (cx + ax * math.sin(t + phase) + ax * 0.34 * math.sin(3 * t + phase)),
      size.height *
          (cy + ay * math.cos(t + phase) + ay * 0.28 * math.cos(2 * t - phase)),
    );
    // El radio también late, para que el blob no se sienta un disco rígido.
    final r = size.width * radius * (1 + 0.07 * math.sin(2 * t + phase));
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pattern != pattern ||
      oldDelegate.focusY != focusY;
}
