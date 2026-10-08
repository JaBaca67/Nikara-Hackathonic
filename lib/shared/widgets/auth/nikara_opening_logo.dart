import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/shared/widgets/auth/auth_logo_geometry.dart';
import 'package:nikara_app/theme/app_theme.dart';

// Todo está en "unidades de caja": el viewBox de logotipo_nikara.svg (y de las 3 piezas, que lo comparten
// a propósito) mide 2117x677 con origen en (-14, 28), así que una pieza dibujada a (0,0) cae en su sitio.
const double _kBoxWidth = 2117;
const double _kBoxHeight = 677;

/// Esquina superior izquierda del cuerpo de la N dentro de la caja (viewBox: 143.9 + 14, 231.4 - 28); solo la altura se usa para alinear la pose inicial con el isotipo.
const Offset _kNTopLeft = Offset(157.9, 203.4);

/// Centro vertical del logo completo dentro de la caja (viewBox: (87 + 645.4) / 2 - 28), para centrarlo en pantalla al final de la apertura.
const double _kContentCenterY = 338.2;

/// Alto del cuerpo de la N en el logo (en unidades de caja).
const double _kLogoNHeight = 396.0;

/// Borde izquierdo del tallo en el logo, en unidades de caja (viewBox 1785.3 + 14).
const double _kStalkLeft = 1799.3;

/// Cuánto sobrepasa el recorte de "ÍKARA" al borde del tallo, para que la última letra quede tapada por él mientras se desliza.
const double _kRevealOverlap = 48;

// Pose inicial: el isotipo del splash. Se mide sobre isotipo_nikara.svg y el PNG nativo (1152 px = 288 dp):
// el PNG muestra 119.75 dp visibles para 1155.1 unidades del SVG, y el cuerpo de la N mide 746.7 unidades.
const double _kIsotipoContentWidth = 1155.1;
const double _kIsotipoVisibleDp = 119.75;
const double _kIsotipoNHeight = 746.7;

/// dp por unidad de caja al inicio: hace que la N del logo tenga el mismo alto que la del isotipo (~77 dp).
const double _kStartDpPerUnit =
    _kIsotipoNHeight *
    _kIsotipoVisibleDp /
    _kIsotipoContentWidth /
    _kLogoNHeight;

/// Esquina de la N del isotipo respecto al centro de la pantalla, en dp (solo se usa la componente vertical: en horizontal el conjunto se centra en cada frame). El PNG va centrado, así que sale de su contenido.
const Offset _kStartNTopLeftFromCenter = Offset(-46.67, -32.40);

/// Desplazamiento inicial del tallo y las hojas (unidades de caja): pegados a la N como en el isotipo. Sale de comparar la posición de cada pieza respecto a la N en ambos SVG; el logo las tiene algo más arriba, de ahí el componente vertical.
const Offset _kLeavesStartOffset = Offset(-1345.6, 16.2);

// Línea temporal (un solo controlador, 1300 ms): apertura en su sitio, pausa breve, y ascenso a la posición de Login.
const int _kCrossfadeMs = 100;
const int _kOpenMs = 500;
const int _kPauseMs = 100;
const int _kAscentMs = 700;

/// Duración total de la animación de apertura.
const Duration kNikaraOpeningDuration = Duration(
  milliseconds: _kOpenMs + _kPauseMs + _kAscentMs,
);

const double _kTotalMs = (_kOpenMs + _kPauseMs + _kAscentMs) + 0.0;

/// Fracción de la animación en la que las piezas del logo terminan de entrar sobre el PNG nativo (~100 ms). La N del logo y la del isotipo no son idénticas (hasta ~9 dp en las marcas), así que el relevo es un fundido breve en vez de un corte.
const double kNikaraOpeningCrossfadeEnd = _kCrossfadeMs / _kTotalMs;

const Interval _crossfadeCurve = Interval(0, kNikaraOpeningCrossfadeEnd);

/// Fase 1, "apertura en su sitio": las hojas se deslizan, "ÍKARA" se revela y el grupo se encoge hasta el tamaño final del logo, siempre centrado en horizontal.
const Interval kNikaraOpenInterval = Interval(
  0,
  _kOpenMs / _kTotalMs,
  curve: Curves.easeInOutCubic,
);

/// Fase 2, "ascenso": el logo ya formado sube, solo en vertical, hasta la posición de Login. Es el intervalo al que se enlazan el halo y la tarjeta.
const Interval kNikaraAscentInterval = Interval(
  (_kOpenMs + _kPauseMs) / _kTotalMs,
  1,
  curve: Curves.easeInOutCubic,
);

/// Las tres piezas del logo ya rasterizadas, listas para dibujarse sin parsear nada por frame.
class NikaraLogoPieces {
  NikaraLogoPieces._(this.n, this.ikara, this.hojas);

  final ui.Image n;
  final ui.Image ikara;
  final ui.Image hojas;

  /// Rasteriza a la mayor de las dos escalas (la del isotipo al inicio o la del logo al final) para que nunca se amplíe una imagen. Parsear los SVG ocurre en el hilo principal: llamar fuera del primer frame.
  static Future<NikaraLogoPieces> load({
    required Size screenSize,
    required double devicePixelRatio,
  }) async {
    final logoDpPerUnit =
        AuthLogoGeometry.widthFor(screenSize.width) / _kBoxWidth;
    final pxPerUnit =
        math.max(_kStartDpPerUnit, logoDpPerUnit) * devicePixelRatio;
    final width = (_kBoxWidth * pxPerUnit).ceil();
    final height = (_kBoxHeight * pxPerUnit).ceil();

    Future<ui.Image> raster(String asset) async {
      final info = await vg.loadPicture(SvgAssetLoader(asset), null);
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..scale(width / info.size.width, height / info.size.height)
        ..drawPicture(info.picture);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      info.picture.dispose();
      return image;
    }

    // En serie, no con Future.wait: cada parseo bloquea el hilo principal y juntos sumarían un solo tirón largo.
    final n = await raster('assets/images/logo_n.svg');
    final ikara = await raster('assets/images/logo_ikara.svg');
    final hojas = await raster('assets/images/logo_hojas.svg');
    return NikaraLogoPieces._(n, ikara, hojas);
  }

  void dispose() {
    n.dispose();
    ikara.dispose();
    hojas.dispose();
  }
}

/// Animación "el isotipo se abre en Níkara": la N queda en su sitio, las hojas se deslizan a la derecha y "ÍKARA" se revela en el hueco, mientras el grupo sube del centro de la pantalla a la posición exacta del logo de Auth ([AuthLogoGeometry]).
///
/// Es un solo [CustomPaint] movido por [progress] (el controlador lo pone el anfitrión); nada se reconstruye por frame. Colocar con `Positioned.fill` en un Stack del tamaño de la pantalla.
class NikaraOpeningLogo extends StatelessWidget {
  const NikaraOpeningLogo({
    super.key,
    required this.pieces,
    required this.progress,
    this.ascendToAuth = true,
  });

  final NikaraLogoPieces pieces;
  final Animation<double> progress;

  /// `true`: tras abrirse, el grupo sube a la posición exacta del logo de
  /// Auth (el destino es Login). `false`: se queda centrado en pantalla — el
  /// ascenso es un no-op — porque el destino es Inicio, que no tiene sheet
  /// al que subir.
  final bool ascendToAuth;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoWidth = AuthLogoGeometry.widthFor(constraints.maxWidth);
        final logoTop = AuthLogoGeometry.topFor(
          availableHeight: constraints.maxHeight,
          safeTop: safeTop,
          logoHeight: AuthLogoGeometry.heightFor(logoWidth),
          sheetExtent: kAuthSheetOpenSize,
        );
        return RepaintBoundary(
          child: CustomPaint(
            size: constraints.biggest,
            painter: _OpeningLogoPainter(
              pieces: pieces,
              progress: progress,
              logoTop: logoTop,
              logoWidth: logoWidth,
              ascendToAuth: ascendToAuth,
            ),
          ),
        );
      },
    );
  }
}

class _OpeningLogoPainter extends CustomPainter {
  _OpeningLogoPainter({
    required this.pieces,
    required this.progress,
    required this.logoTop,
    required this.logoWidth,
    required this.ascendToAuth,
  }) : super(repaint: progress);

  final NikaraLogoPieces pieces;
  final Animation<double> progress;
  final double logoTop;
  final double logoWidth;
  final bool ascendToAuth;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final fade = _crossfadeCurve.transform(p);
    if (fade <= 0) return;

    final open = kNikaraOpenInterval.transform(p);
    final ascent = kNikaraAscentInterval.transform(p);

    // Una sola transformación afín para todo el grupo, así nada se desalinea entre sí. La escala baja de la del isotipo a la del logo durante la apertura y ya no cambia en el ascenso.
    final endScale = logoWidth / _kBoxWidth;
    final scale = ui.lerpDouble(_kStartDpPerUnit, endScale, open)!;
    final leaves = _kLeavesStartOffset * (1 - open);

    // Horizontal: el conjunto visible (N, hojas y lo ya revelado de "ÍKARA") va centrado en CADA frame. Su extremo derecho es el tallo, así que su ancho es (caja + desplazamiento de las hojas); se centra sobre el centro de la caja del viewBox, no sobre el del dibujo, para que al terminar la apertura el origen coincida con el logo de Login (que centra la caja): la diferencia es de ~0.08 dp. La N se desplaza a la izquierda porque lo demás crece a la derecha. Sin componente horizontal en el ascenso.
    final originX = size.width / 2 - scale * (_kBoxWidth + leaves.dx) / 2;

    // Vertical: de la pose del isotipo (N alineada con el PNG) a logo centrado en pantalla, y luego, en el ascenso, a la posición de Login.
    final startY =
        size.height / 2 +
        _kStartNTopLeftFromCenter.dy -
        _kNTopLeft.dy * _kStartDpPerUnit;
    final centeredY = size.height / 2 - _kContentCenterY * endScale;
    // Sin ascenso a Auth, el destino del lerp es el mismo punto donde ya
    // está: el tramo de ascenso queda como un no-op y el grupo se queda
    // centrado en pantalla.
    final ascentTarget = ascendToAuth ? logoTop : centeredY;
    final originY = ui.lerpDouble(
      ui.lerpDouble(startY, centeredY, open)!,
      ascentTarget,
      ascent,
    )!;
    final origin = Offset(originX, originY);

    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium
      // Solo cuenta el alfa: modula la imagen entera sin teñirla.
      ..color = AppColors.textInverted.withValues(alpha: fade);

    Rect rectFor(Offset offset) => Rect.fromLTWH(
      origin.dx + offset.dx * scale,
      origin.dy + offset.dy * scale,
      _kBoxWidth * scale,
      _kBoxHeight * scale,
    );

    void draw(ui.Image image, Rect dst) => canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      paint,
    );

    // "ÍKARA" solo asoma hasta donde el tallo ya pasó, así se revela de izquierda a derecha en el hueco.
    final revealRight =
        origin.dx + (_kStalkLeft + leaves.dx + _kRevealOverlap) * scale;
    final ikaraRect = rectFor(Offset.zero);
    if (revealRight > ikaraRect.left) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          ikaraRect.left,
          ikaraRect.top,
          math.min(revealRight, ikaraRect.right),
          ikaraRect.bottom,
        ),
      );
      draw(pieces.ikara, ikaraRect);
      canvas.restore();
    }
    draw(pieces.n, rectFor(Offset.zero));
    draw(pieces.hojas, rectFor(leaves));
  }

  @override
  bool shouldRepaint(covariant _OpeningLogoPainter oldDelegate) =>
      oldDelegate.pieces != pieces ||
      oldDelegate.logoTop != logoTop ||
      oldDelegate.logoWidth != logoWidth ||
      oldDelegate.ascendToAuth != ascendToAuth;
}
