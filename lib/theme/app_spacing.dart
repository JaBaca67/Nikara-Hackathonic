/// Escala de espaciado y radios de borde.
///
/// A diferencia de [AppColors]/[AppTextStyles] (extraídos de Figma/Claude
/// Design), esta escala no viene de un tablero de diseño: se derivó
/// analizando la frecuencia real de valores de `EdgeInsets`/
/// `BorderRadius.circular` en todo `lib/features` y `lib/shared` (ver
/// `nikara-design-audit` skill, que puede regenerar este análisis). Los
/// valores elegidos son los que YA predominan en la app — esto formaliza un
/// patrón existente, no impone uno nuevo.
///
/// Antes de esta escala, ~40-50% de los usos de radio (`14`, `18`, `10`,
/// `11`, `13`, `22`...) y una fracción similar de paddings (`14`, `10`, `6`,
/// `9`...) se desviaban por 1-6px de la grilla de 4pt que el resto de la app
/// ya sigue — típico de un valor "inventado cercano" en vez de reusado.
/// Pantallas nuevas deberían usar solo estos tokens; el saneamiento de
/// pantallas existentes es progresivo (ver auditoría de `nikara-design-audit`).
abstract class AppSpacing {
  /// 4px — separación mínima (ícono-texto muy pegado, ajustes finos).
  static const xs = 4.0;

  /// 8px — separación entre elementos relacionados dentro de un grupo chico.
  static const sm = 8.0;

  /// 12px — padding interno de chips/pills, separación estándar entre filas.
  static const md = 12.0;

  /// 16px — el más usado en toda la app (99 padding / 74 radio). Default
  /// para padding de pantalla/tarjeta y radio de tarjeta estándar.
  static const lg = 16.0;

  /// 20px — padding de secciones grandes, radio de contenedores prominentes
  /// (hero cards, hojas inferiores).
  static const xl = 20.0;

  /// 24px — separación entre secciones, radio de modales/fotos grandes.
  static const xxl = 24.0;

  /// 32px — separación mayor (top/bottom de pantalla, bloques grandes).
  static const xxxl = 32.0;

  /// 112px — espacio que debe dejar libre el fondo de una pantalla con la
  /// barra de navegación flotante encima, para que el último elemento
  /// interactivo siga siendo alcanzable.
  ///
  /// No sale de la grilla de 4pt por estética: es la altura real de la barra
  /// más su margen inferior. Antes de existir este token, las cuatro
  /// pantallas que lo necesitan resolvían el mismo problema por separado
  /// (Inicio 110, Perfil 110, Rutas 108 como constante local, ECO 32) —
  /// cuatro implementaciones y tres valores distintos. Ninguna produce
  /// contenido inalcanzable hoy, pero el margen de ECO es tan ajustado que
  /// alcanza con agregar un elemento al final de esa lista para romperlo.
  static const navBarClearance = 112.0;
}

abstract class AppRadius {
  /// 8px — chips pequeños, íconos con fondo.
  static const xs = 8.0;

  /// 12px — inputs, botones compactos, filas de opción.
  static const sm = 12.0;

  /// 16px — el más común: tarjetas estándar, la mayoría de contenedores.
  static const md = 16.0;

  /// 20px — contenedores prominentes: hero cards, hojas inferiores (bottom
  /// sheets), tarjetas destacadas.
  static const lg = 20.0;

  /// 24px — modales grandes, fotos de portada, contenedores de foco.
  static const xl = 24.0;

  /// 999px — pill/stadium completo (chips, badges, botones redondeados).
  static const pill = 999.0;
}
