import 'dart:math' as math;

/// Fracción de pantalla que ocupa el sheet de Auth abierto. Vive aquí porque de ella depende dónde queda el logo en reposo.
const double kAuthSheetOpenSize = 0.72;

/// Dónde y de qué tamaño se dibuja el logo en las pantallas de Auth. Es la única fuente de esta cuenta: la
/// usan `AuthBottomSheetLayout` y la animación de apertura del splash, así el logo animado termina en el
/// mismo píxel que el logo real.
abstract final class AuthLogoGeometry {
  /// Techo de altura del logo. En la práctica casi nunca manda: a los anchos de teléfono reales el limitante es [sidePadding] vía la relación de aspecto.
  static const double maxHeight = 210.0;

  /// Ancho/alto del asset del logo. Fijarlo permite saber la altura que el logo va a ocupar *antes* de renderizarlo, que es lo que necesita el cálculo de posición: usar [maxHeight] ahí dejaba un hueco fantasma de ~87dp entre el logo y el sheet. Actualizar si se cambia el asset.
  static const double aspectRatio = 2117 / 677;

  /// Sube este valor para achicar el logo: es el que decide su ancho real.
  static const double sidePadding = 40.0;

  /// Gap fijo entre el logo y el borde superior del sheet cuando este lo alcanza.
  static const double toSheetGap = 20.0;

  static double widthFor(double maxWidth) =>
      math.min(maxWidth - sidePadding * 2, maxHeight * aspectRatio);

  static double heightFor(double logoWidth) => logoWidth / aspectRatio;

  /// El logo se centra en la franja libre (borde seguro -> techo del sheet), no en la pantalla entera: así queda a media altura de lo que realmente se ve y sigue al sheet cuando este baja.
  static double topFor({
    required double availableHeight,
    required double safeTop,
    required double logoHeight,
    required double sheetExtent,
  }) {
    final sheetTopY = availableHeight * (1 - sheetExtent);
    final topLimit = safeTop + 8;
    final bandBottom = sheetTopY - toSheetGap;
    return (topLimit + (bandBottom - topLimit - logoHeight) / 2).clamp(
      topLimit,
      availableHeight,
    );
  }
}
