import 'package:flutter/material.dart';

/// Tokens de color extraídos del archivo Figma "UI-NÍKARA" (nodo 157:2).
/// [neutral1100] y [surface100]/[backgroundCream] son blanco/negro
/// suavizados a propósito — el sistema de diseño no usa negro/blanco puro.
abstract class AppColors {
  // ==========================================================================
  // CAPA CANÓNICA — primitivos de marca y tokens semánticos.
  //
  // Es la única capa que deberían tocar las pantallas nuevas. Todo lo que
  // viene después de esta sección es la paleta histórica extraída de Figma,
  // en proceso de consolidación hacia estos tokens (ver CLAUDE.md >
  // "Sistema de diseño"). Al escribir una pantalla, buscá acá primero: si
  // el color que necesitás no está, es una pregunta abierta de diseño, no
  // una constante nueva que se agrega al final del archivo.
  // ==========================================================================

  // --- Primitivos de marca: 3 familias, variante Fill y variante Text ---

  /// Dorado de marca. **Solo relleno** — su versión oscurecida a contraste
  /// seguro se lee como bronce, no como dorado, así que no existe `goldText`:
  /// sobre un relleno dorado va texto oscuro ([textPrimary]/[textInk]).
  static const goldFill = primary500;

  /// Oliva-lima de marca. **Solo relleno**, misma razón que [goldFill]: es
  /// tan claro (contraste 1.69 contra el fondo) que como color de texto es
  /// ilegible. Sobre un relleno oliva va texto oscuro — no blanco.
  static const oliveFill = ecoGreen500;

  /// Oliva oscuro para texto/íconos interactivos con significado ECO.
  /// Contraste 4.68 contra [background] y 4.82 contra [surface] — cumple
  /// WCAG AA. Reemplaza a `accent300` (3.21, incumplía) y a `ecoActive`
  /// (3.77, también incumplía).
  static const oliveText = Color(0xFF707536);

  // Nota: la especificación original declaraba una tercera familia de marca
  // (Orange `orangeFill`/`orangeText`). Se eliminó en la auditoría del
  // 2026-08-25 por tener **cero usos** en toda la app: el naranja solo vive
  // en el gradiente de Auth (`sunset*`) y en `coral500`. Declarar una
  // familia que ninguna pantalla usa hacía creer que había 3 acentos
  // disponibles cuando en la práctica el sistema son 2: Gold y Olive.

  // --- Tokens semánticos: neutros, superficies y estado ---

  /// Fondo de pantalla.
  static const background = backgroundCream;

  /// Fondo de tarjetas, inputs y hojas inferiores.
  static const surface = surface100;

  /// Texto e íconos principales.
  static const textPrimary = neutral1100;

  // `textSecondary` se define en la Fase 2 del refactor apuntando al gris
  // que realmente ganó (`settingsTextMuted` #8A7A65, 91 usos). El alias
  // anterior apuntaba a `neutral700` #725E5A y tenía **cero usos** — nunca
  // fue el destino de consolidación que decía ser.

  /// Texto sobre fondos oscuros o sobre un relleno de marca saturado.
  /// **No** se usa sobre [goldFill] ni [oliveFill] — esos son claros.
  static const textInverted = surface100;

  /// Borde estándar de tarjetas y separadores.
  static const border = cardBorder;

  /// Validación inline de formularios.
  static const error = formError;

  /// Confirmación de acción destructiva (eliminar, cerrar sesión).
  /// Deliberadamente distinto de [error]: uno señala "corregí este campo",
  /// el otro "esto no se puede deshacer".
  static const destructive = settingsDanger;

  /// Estado positivo/éxito — contraseña fuerte, badge conseguido, registro
  /// completado. Contraste 4.81 / 4.95, cumple AA. No pertenece a la
  /// familia ECO pese al tono verde: es un token de estado, igual que
  /// [error] y [destructive].
  static const success = Color(0xFF3A7D3A);

  // El módulo ECO no tiene color propio: usa `oliveFill`/`oliveText`
  // directamente. Los alias `ecoAccentFill`/`ecoAccentText` se eliminaron
  // (cero usos) — eran un tercer nombre para el mismo par, lo que hacía
  // parecer que ECO tenía una familia aparte.

  // ==========================================================================
  // PALETA HISTÓRICA (Figma "UI-NÍKARA") — en consolidación.
  // ==========================================================================

  /// Superficie casi blanca de los campos de entrada.
  static const surface100 = Color(0xFFFDFDFD);

  /// Naranja-rojo, punto final de gradiente.
  static const primary400 = Color(0xFFFF600F);

  /// Dorado principal de marca.
  static const primary500 = Color(0xFFFDBE02);

  /// Gris-marrón apagado para texto secundario y bordes.
  static const neutral600 = Color(0xFF8C7373);

  /// Dorado claro, punto final de gradiente.
  static const primary700 = Color(0xFFFFD866);

  /// "Tinta" principal de texto/íconos — negro suavizado, no `#000000` puro.
  static const neutral1100 = Color(0xFF121212);

  /// Fondo crema de tarjetas y app (no es variable ligada en Figma).
  static const backgroundCream = Color(0xFFFFF9F0);

  // --- Pantalla Inicio (Figma nodo 124:37) ---

  /// Gris claro del divisor "Por región".
  static const surface200 = Color(0xFFE6E5E5);

  /// Gris apagado del texto de la barra de estado.
  static const neutral400 = Color(0xFFB7AEAE);

  /// Texto secundario/caption (ubicación en tarjeta, "Ver Mas").
  static const neutral700 = Color(0xFF725E5A);

  /// Marrón oscuro — precio y bordes del selector de miniaturas.
  static const neutral800 = Color(0xFF564343);

  /// Marrón casi negro.
  static const neutral900 = Color(0xFF3A2C2C);

  /// Verde oliva-lima del relleno del badge ECO.
  static const ecoGreen500 = Color(0xFFC2CA5B);

  /// Pill de etiqueta descriptiva en tarjeta destacada ("Laguna Volcánica").
  static const tagGold600 = Color(0xFFFFCC33);

  /// Relleno del pill de la campana de notificaciones.
  static const notificationPill = Color(0xFFD1D77E);

  /// Círculo contador del badge de notificaciones.
  static const notificationBadge = Color(0xFF404413);

  // --- Splash/precarga (Figma nodo 95:2) ---

  /// Punto inferior-derecho del gradiente de precarga.
  static const coral500 = Color(0xFFFF8243);

  // --- Perfil (Figma nodo 259:224) ---

  /// Taupe apagado para captions ("Granada", "520 puntos").
  static const neutral500 = Color(0xFFA19191);

  /// Punto superior del gradiente de encabezado — dorado pálido.
  static const profileHeaderGoldPale = Color(0xFFFFE599);

  /// Tercer punto del gradiente de encabezado — coral suave.
  static const profileHeaderCoral = Color(0xFFFFA375);

  // --- Ajustes (Figma nodo 361:323) — paleta neutro-cálida propia ---

  /// Fondo de la pantalla.
  static const settingsBackground = Color(0xFFF7F3EC);

  /// Acento dorado — tinte de ícono de fila, relleno de toggle activo.
  static const settingsAccent = Color(0xFFF0B500);

  /// Texto principal de filas/títulos.
  static const settingsTextDark = Color(0xFF261D0C);

  /// Texto secundario — labels de sección, valores de fila, captions.
  static const settingsTextMuted = Color(0xFF8A7A65);

  /// Color "peligro" canónico de la app: usar en toda confirmación
  /// destructiva (eliminar/cancelar/cerrar sesión), nunca un rojo ad-hoc.
  static const settingsDanger = Color(0xFFCC5510);

  /// Relleno del track de toggle en estado "off".
  static const settingsToggleOff = Color(0xFFC8BDB0);

  /// Tinte genérico de estado "éxito/confirmado" (ej. fuerza de contraseña).
  static const statusSuccess = Color(0xFF656B1F);

  /// Fondo de miniatura placeholder (también usado en Perfil).
  static const placeholderTan = Color(0xFFE5DFD2);

  // --- Tonos derivados en uso (antes "paleta maestra", Figma nodo 125:2) ---
  // El tablero completo de 9 escalones por familia se volcó al código como
  // `primario1..9`/`secundario1..9`/`complementario1..9`. Era documentación
  // de Figma en forma de constantes: de ~20, solo 6 tenían algún uso real y
  // sus nombres no decían nada de su función, así que nadie sabía cuándo
  // tomarlos. Los 6 vivos quedan renombrados por rol (mismo hex, cero cambio
  // visual); el resto se eliminó.

  /// Dorado pálido — fondo del avatar por defecto (con [goldDeepText] encima).
  static const goldPaleFill = Color(0xFFFFF2CC);

  /// Ámbar profundo legible como texto — inicial del avatar y pin de
  /// alojamiento. Es el único tono de la familia Gold que funciona como
  /// texto (por eso se lee bronce, no dorado; ver nota en [goldFill]).
  static const goldDeepText = Color(0xFF997300);

  /// Oliva medio — fondo de la transición de splash.
  static const oliveMidFill = Color(0xFFAEB738);

  /// Coral pálido — relleno del botón "ya inscrito"/estado neutro cálido.
  static const coralPaleFill = Color(0xFFFFEEE6);

  /// Borde del mismo par que [coralPaleFill].
  static const coralPaleBorder = Color(0xFFFFE7DB);

  /// Óxido profundo — pin de categoría artesanía.
  static const rustText = Color(0xFFA83800);

  // --- Detalle de negocio (Figma nodos 284:2256, 233:437) ---

  /// Fondo del track del control segmentado ("Información" / "Reseñas").
  static const segmentedTrackBg = Color(0xFFEDE9E1);

  /// Tinta casi negra para texto sobre botones/pills dorados.
  static const textInk = Color(0xFF1A1510);

  /// Texto de error de validación inline (Login/Registro) — distinto de
  /// [settingsDanger], que es para acciones destructivas, no validación.
  static const formError = Color(0xFFD64545);

  // --- Rediseño de Perfil (Figma nodos 377:483, 421:361) ---

  /// Taupe apagado — hora mock, caption de ubicación, badge bloqueado.
  static const profileMuted = Color(0xFFB8AA98);

  /// Divisores finos y relleno de botones editar/ajustes/compartir.
  static const profileDivider = Color(0xFFF2EBE0);

  /// Track de la barra de progreso de nivel y tarjeta de badge bloqueado.
  static const progressTrack = Color(0xFFEDE6D8);

  /// Tinte del badge "Guardián del Bosque".
  static const badgeForest = Color(0xFF7A8C28);

  /// Tinte del badge "Protector del Lago".
  static const badgeLake = Color(0xFF5A6B1A);

  // --- Detalle de negocio: paleta cálida de amenidades/actividades ---

  /// Relleno de chip de Comodidades.
  static const warmChipBackground = Color(0xFFFFF8E1);

  /// Borde de chip para Comodidades y Actividades.
  static const warmChipBorder = Color(0xFFFDE68A);

  /// Color de foco/acento del wizard de registro (inputs, stepper, CTA).
  static const wizardFocus = Color(0xFFF59E0B);

  // --- Sistema de profundidad ---
  // Par estándar borde + sombra suave para que una superficie se lea
  // "elevada" en vez de plana, usados juntos en tarjetas/hojas/botones.

  /// Borde de 1px casi imperceptible para tarjetas/inputs.
  static const cardBorder = Color(0x1F000000); // negro @ ~12% alpha

  /// Color de sombra ambiental suave para [cardShadow].
  static const shadowAmbient = Color(0x14261D0C); // settingsTextDark @ ~8%

  /// Elevación estándar de tarjeta — combinar con un [BoxDecoration] redondeado.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: shadowAmbient, offset: Offset(0, 4), blurRadius: 10),
  ];

  // --- Rediseño de Mapa (Pantalla 2b) ---
  // Bordes/sombras propios tintados con settingsTextDark en vez de negro
  // puro, para no sobrecargar cardBorder/shadowAmbient con otro alpha.

  /// Borde de los controles flotantes del mapa — settingsTextDark @ 6%.
  static const mapControlBorder = Color(0x0F261D0C);

  /// Sombra bajo la barra de búsqueda y botón de filtro — @ 12%.
  static const mapControlShadow = Color(0x1F261D0C);

  /// Sombra del chip de categoría activo y botón de recentrar — @ 14%.
  static const mapControlShadowStrong = Color(0x24261D0C);

  /// Sombra de chips de categoría inactivos — @ 10%.
  static const mapControlShadowSoft = Color(0x1A261D0C);

  /// Sombra bajo la tarjeta flotante de vista previa de negocio — @ 16%.
  static const mapCardShadow = Color(0x29261D0C);

  /// Sombra de un pin de mapa activo/seleccionado — negro @ 22%.
  static const mapPinShadowActive = Color(0x38000000);

  /// Sombra de un pin de mapa inactivo — negro @ 18%.
  static const mapPinShadowInactive = Color(0x2E000000);

  /// Corazón de favorito en la tarjeta de vista previa del mapa.
  static const favoriteActive = Color(0xFFE8798F);

  /// Relleno de agua del estilo JSON personalizado de Google Maps
  /// (`mapStyleJson` en `map_screen.dart`) — Maps solo acepta hex literal,
  /// no hay variable Figma equivalente.
  static const mapStyleWater = Color(0xFFCFE3EA);

  /// Relleno de carreteras del mismo estilo de mapa personalizado.
  static const mapStyleRoad = Color(0xFFF5E9D6);

  /// Fondo circular pálido tras el corazón de favorito en el carrusel del mapa.
  static const mapFavoriteBackground = Color(0xFFFCEBEE);

  /// Tinte de pin para categorías de agua/naturaleza (lagunas, playas, ríos)
  /// — el único tono azul nuevo en la paleta; el resto de categorías
  /// reusa tokens existentes (ver [mapPinCategoryFor] en `business_icons.dart`).
  static const mapPinWater = Color(0xFF3E8FB0);

  // --- Rediseño de detalle de negocio (Pantalla 3a) ---

  /// Fondo del chip-ícono de fila de Actividad — oliva pálido.
  static const detailActivityIconBg = Color(0xFFEFF2DF);

  /// Marrón oscuro cálido — párrafo de descripción, dirección, pill de contacto.
  static const detailBodyBrown = Color(0xFF4A3D2A);

  /// Texto secundario apagado de fila (horarios no-hoy, caption de mapa).
  static const detailMutedRow = Color(0xFF6B5B45);

  /// Fondo del círculo-ícono de la fila de contacto WhatsApp.
  static const detailWhatsappIconBg = Color(0xFFE7F0E4);

  /// Tinte del ícono de WhatsApp.
  static const detailWhatsappIcon = Color(0xFF4E8A50);

  /// Fondo del círculo-ícono de la fila de contacto Instagram.
  static const detailInstagramIconBg = Color(0xFFFBECEF);

  /// Ilustración mini-mapa "Cómo llegar": fondo base, franja de carretera,
  /// área verde (en ese orden de capas) y sombra bajo su pin.
  static const detailMapBg = Color(0xFFE9E5DC);
  static const detailMapRoad = Color(0xFFDCD6C8);
  static const detailMapGreen = Color(0xFFDDE7DC);
  static const detailMapPinShadow = Color(0x38261D0C);

  /// Scrim degradado sobre la foto de portada — punto superior, inferior
  /// y el extremo totalmente transparente. Compartido por negocio y ECO.
  static const detailCoverScrimTop = Color(0x6B1A1510);
  static const detailCoverScrimBottom = Color(0xCC1A1510);
  static const detailCoverScrimClear = Color(0x001A1510);

  /// Pill contador "1 / N" sobre la portada — fondo y borde fino.
  static const detailCoverCounterBg = Color(0x801A1510);
  static const detailCoverCounterBorder = Color(0x40FDFDFD);

  /// Resplandor dorado bajo la pestaña segmentada seleccionada — primary500 @ 28%.
  static const detailSegmentGlow = Color(0x47F0B500);

  /// Realce dorado sutil bajo la tarjeta de organizador — primary500 @ 8%.
  static const detailCardGlow = Color(0x14F0B500);

  /// Sombra hacia arriba de la barra de acciones inferior fija — @ 8%.
  static const detailBottomBarShadow = Color(0x14261D0C);

  /// Halo dorado bajo el CTA primario de la barra inferior — primary500 @ 32%.
  static const detailPrimaryButtonGlow = Color(0x52F0B500);

  /// Resplandor dorado bajo tarjetas/badges en Inicio, Perfil y Ajustes.
  static const cardGlowSoft = Color(0x1AF0B500);

  // --- Wizard de creación/edición de negocio (Pantallas 4a-4e) ---

  /// Anillo del círculo-paso no alcanzado en el stepper de progreso.
  static const wizardStepInactiveBorder = Color(0xFFF0DFAE);

  /// Pill "REVISIÓN" / fila de advertencia de galería incompleta.
  static const wizardReviewBadgeBg = Color(0xFFFFF6DC);
  static const wizardReviewBadgeText = Color(0xFF8A6A00);

  /// Fila de contacto Facebook — fondo de círculo y tinte de ícono.
  static const wizardFacebookIconBg = Color(0xFFE7EDF7);
  static const wizardFacebookIcon = Color(0xFF5B7FB5);

  /// Fondo de la zona de arrastre (drop zone) de foto de portada.
  static const wizardUploadZoneBg = Color(0xFFFFFBEF);

  /// Link "Eliminar este negocio" — distinto de [settingsDanger].
  static const wizardDangerLink = Color(0xFFC4756A);

  /// Ámbar de ícono de verificación/confirmación de pin.
  static const wizardAmber = Color(0xFFF0B500);

  // --- Flujo de Auth (Login v3 + Registro en 3 pasos) ---

  /// Gradiente atardecer, punto 1/4 — superior.
  static const sunsetStart = Color(0xFFFFD028);

  /// Gradiente atardecer, punto 2/4.
  static const sunsetMid1 = Color(0xFFFDB828);

  /// Gradiente atardecer, punto 3/4.
  static const sunsetMid2 = Color(0xFFFF8A35);

  /// Gradiente atardecer, punto 4/4 — inferior.
  static const sunsetEnd = Color(0xFFF97316);

  /// Fondo de tarjeta en Login/Registro — distinto de [backgroundCream]
  /// (más cálido/claro).
  static const authCardBackground = Color(0xFFFFFDF8);

  /// Oliva profundo de todo link de texto en Auth. Casi idéntico a
  /// [oliveText] (#707536) — candidato a colapsar en él.
  static const authLink = Color(0xFF6E7522);

  /// Pill "Explorar como invitado" — gradiente y tinte del ícono circular.
  static const authGuestPillStart = Color(0xFFEFF2DF);
  static const authGuestPillEnd = Color(0xFFE4EAC0);
  static const authGuestIconText = Color(0xFF4C5218);

  /// Tinte de la etiqueta/barra "Débil" de fuerza de contraseña.
  static const strengthWeak = Color(0xFFD2691E);

  /// "Tinta" de Auth — encabezados, texto de botón primario, íconos
  /// principales. Distinto de [textInk] (valor propio de este flujo).
  static const authInk = Color(0xFF3D2110);

  /// Labels de campo, íconos secundarios y borde de campo (@ 35% alpha).
  static const authMuted = Color(0xFF9A8A82);

  /// Texto de subtítulo/cuerpo bajo un encabezado en Auth.
  static const authBodyMuted = Color(0xFF6B5B45);

  /// Texto placeholder de campos en Auth.
  static const authPlaceholder = Color(0xFFB7A9A0);

  // --- Módulo ECO ("Actividades Ambientales") ---

  /// Colores del stack de avatares de participantes ("+18") — `eco_participants`
  /// no trae foto, se ciclan estos tonos neutros para simular variedad.
  static const ecoAvatarStack = <Color>[
    Color(0xFFD9C9A8),
    Color(0xFFCEC1A1),
    Color(0xFFB6AFAE),
    Color(0xFFE4DCCB),
  ];

  // --- Tokens de saneamiento (pase final: colores antes hardcodeados) ---

  /// Sombra sutil de tarjeta de perfil — negro @ 5%.
  static const profileCardShadow = Color(0x0D000000);

  /// Overlay de carga sobre el mapa — backgroundCream @ 35%.
  static const mapLoadingOverlay = Color(0x59FFF9F0);

  /// Fondo del botón circular "eliminar" sobre una miniatura de foto —
  /// textInk @ 55%. Compartido por el wizard de negocio, el detalle de
  /// negocio y el wizard de rutas.
  static const removeButtonBackground = Color(0x8C1A1510);

  /// Sombra bajo la foto de portada/avatar del wizard de negocio —
  /// settingsTextDark @ 26%.
  static const wizardPhotoShadow = Color(0x42261D0C);

  /// Resplandor bajo el botón primario de Auth — primary500 @ 35%.
  static const authPrimaryButtonGlow = Color(0x59FDBE02);

  /// Punto final del gradiente del ícono de éxito de registro de negocio —
  /// variante más profunda de [primary500].
  static const successBadgeGradientEnd = Color(0xFFF5A800);

  /// Resplandor bajo el ícono de éxito de registro de negocio —
  /// primary500 @ 40%.
  static const successBadgeGlow = Color(0x66FDBE02);
}
