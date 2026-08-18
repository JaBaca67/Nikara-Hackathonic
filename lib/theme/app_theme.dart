import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nikara_app/theme/app_colors.dart';

export 'package:nikara_app/theme/app_colors.dart';

/// Estilos de texto extraídos de "Text Styles" en Figma "UI-NÍKARA".
abstract class AppTextStyles {
  /// Figma "HL4".
  static TextStyle get heading => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 24,
    height: 36 / 24,
    fontWeight: FontWeight.w700,
  );

  /// Figma "Boton Lg".
  static TextStyle get buttonLarge => GoogleFonts.nunito(
    color: const Color(0xFF1A1510),
    fontSize: 15,
    height: 26 / 15,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get body => GoogleFonts.nunito(
    color: AppColors.neutral600,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get inputLabel => GoogleFonts.nunito(
    color: AppColors.neutral600,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static TextStyle get inputText => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get link => GoogleFonts.nunito(
    color: AppColors.accent300,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get registerPrompt => GoogleFonts.nunito(
    color: AppColors.neutral600,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get registerLink => GoogleFonts.nunito(
    color: AppColors.accent300,
    fontSize: 15,
    height: 24 / 15,
    fontWeight: FontWeight.w700,
  );

  // --- Pantalla Inicio (Figma nodo 124:37) ---

  /// Figma "HL3" — wordmark "Níkara".
  static TextStyle get headingXL => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 32,
    height: 48 / 32,
    fontWeight: FontWeight.w700,
  );

  /// Títulos de sección ("Más visitados").
  static TextStyle get sectionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w800,
  );

  /// Figma "Leyenda" — placeholder de búsqueda.
  static TextStyle get caption => GoogleFonts.nunito(
    color: AppColors.neutral700,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get cardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 11,
    height: 13.75 / 11,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get cardLocation => GoogleFonts.leagueSpartan(
    color: AppColors.neutral700,
    fontSize: 9,
    height: 13.5 / 9,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get cardPrice => GoogleFonts.leagueSpartan(
    color: AppColors.neutral800,
    fontSize: 14,
    height: 1.0,
    fontWeight: FontWeight.w900,
  );

  static TextStyle get cardPriceSuffix => GoogleFonts.leagueSpartan(
    color: AppColors.neutral700,
    fontSize: 9,
    height: 1.0,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get cardRating => GoogleFonts.leagueSpartan(
    color: AppColors.surface100,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get tagPill => GoogleFonts.leagueSpartan(
    color: AppColors.surface100,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w900,
  );

  static TextStyle get regionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get seeMore => GoogleFonts.leagueSpartan(
    color: AppColors.neutral700,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get heroTitle => GoogleFonts.leagueSpartan(
    color: AppColors.surface100,
    fontSize: 20,
    height: 30 / 20,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get heroLocation => GoogleFonts.nunito(
    color: AppColors.surface100,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get heroPrice => GoogleFonts.leagueSpartan(
    color: AppColors.surface100,
    fontSize: 20,
    height: 1.0,
    fontWeight: FontWeight.w900,
  );

  static TextStyle get ctaPill => GoogleFonts.leagueSpartan(
    color: AppColors.surface100,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w700,
  );

  /// Sin color: el caller elige el tinte activo (primary500) o inactivo (neutral700).
  static TextStyle get navLabel => GoogleFonts.leagueSpartan(
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  // --- Pantalla Perfil (Figma nodo 259:224 + rediseño 377:483) ---

  /// Figma "HL5" — nombre de perfil.
  static TextStyle get profileName => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 20,
    height: 30 / 20,
    fontWeight: FontWeight.w700,
  );

  /// Figma "Subtitulo 1" — "lv 4/12".
  static TextStyle get profileLevel => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// "León, Nicaragua".
  static TextStyle get profileLocation => GoogleFonts.nunito(
    color: AppColors.profileMuted,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Título del header "Perfil".
  static TextStyle get profileScreenTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 24,
    height: 36 / 24,
    fontWeight: FontWeight.w900,
  );

  /// Valor del contador de stats ("6" / "3" / "520").
  static TextStyle get profileStatValue => GoogleFonts.leagueSpartan(
    color: AppColors.settingsAccent,
    fontSize: 20,
    height: 1.0,
    fontWeight: FontWeight.w900,
  );

  /// Label del contador de stats ("Viajes" / "Insignias" / "Puntos").
  static TextStyle get profileStatLabel => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Caption "Próximo: Guardián del Territorio".
  static TextStyle get profileLevelNext => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Porcentaje del anillo de progreso circular ("52%").
  static TextStyle get profileProgressPercent => GoogleFonts.leagueSpartan(
    color: AppColors.tagGold600,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w900,
  );

  /// Caption de 10px compartida — footer de progreso y sufijo de precio en tarjeta favorita.
  static TextStyle get profileCaption10 => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w400,
  );

  /// Título de tarjeta favorita.
  static TextStyle get favoriteCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 15.6 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Caption de ubicación en tarjeta favorita.
  static TextStyle get favoriteCardCaption => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w400,
  );

  /// Precio en tarjeta favorita ("C$480").
  static TextStyle get favoriteCardPrice => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 13,
    height: 19.5 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Título de tarjeta de badge en la grilla.
  static TextStyle get badgeCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 9,
    height: 10.8 / 9,
    fontWeight: FontWeight.w800,
  );

  /// Pill de estado de badge ("✓ Obtenida" / "Bloqueada") — sin color: el
  /// caller usa el tinte propio del badge o [AppColors.profileMuted] si está bloqueado.
  static TextStyle get badgeStatusPill => GoogleFonts.nunito(
    fontSize: 8,
    height: 12 / 8,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get listCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 19.25 / 14,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get listCardCaption => GoogleFonts.leagueSpartan(
    color: AppColors.neutral500,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get listCardPrice => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get listCardPriceSuffix => GoogleFonts.leagueSpartan(
    color: AppColors.neutral500,
    fontSize: 10,
    height: 14.286 / 10,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get badgeTitle => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 10,
    height: 12.5 / 10,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get badgeStatus => GoogleFonts.leagueSpartan(
    fontSize: 9,
    height: 13.5 / 9,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get sectionSubLabel => GoogleFonts.leagueSpartan(
    color: AppColors.neutral500,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w400,
  );

  // --- Pantalla Ajustes (Figma nodo 361:323) ---

  static TextStyle get settingsTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 20,
    height: 1.0,
    fontWeight: FontWeight.w900,
  );

  static TextStyle get settingsSubtitle => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get settingsSectionLabel => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  static TextStyle get settingsRowTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 14,
    height: 21 / 14,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get settingsRowValue => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get settingsRowCaption => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w500,
  );

  // --- Pantalla Mapa (Figma nodo 167:1849) ---

  static TextStyle get headerTitleMd => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 18,
    height: 22.5 / 18,
    fontWeight: FontWeight.w900,
  );

  static TextStyle get mapListLabel => GoogleFonts.leagueSpartan(
    color: AppColors.neutral500,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 1,
  );

  static TextStyle get mapRowTitle => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get mapRowCaption => GoogleFonts.leagueSpartan(
    color: AppColors.neutral500,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get mapRowRating => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get mapRowPrice => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w900,
  );

  // --- Feedback de formularios (auditoría de tipografía) ---

  /// Texto de error de validación inline, [AppColors.formError].
  static TextStyle get errorText => GoogleFonts.nunito(
    color: AppColors.formError,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  /// Texto de ayuda/hint bajo un campo (no es error).
  static TextStyle get helperText => GoogleFonts.nunito(
    color: AppColors.neutral600,
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  // --- Links de texto ---
  // Consolida lo que antes eran 6 estilos de link casi duplicados dispersos
  // por varias pantallas. `link`/`registerLink` siguen existiendo por
  // compatibilidad, pero todo link nuevo debería usar uno de estos tres.

  /// League Spartan Bold 12 — link más pequeño.
  static TextStyle get linkSm => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// League Spartan Bold 14 — link por defecto.
  static TextStyle get linkMd => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );

  /// League Spartan Bold 15 — link más prominente.
  static TextStyle get linkLg => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w700,
  );

  // --- Rediseño de Auth (Login v3 + Registro en 3 pasos) ---

  /// Label de campo en mayúsculas ("CORREO ELECTRÓNICO").
  static TextStyle get authFieldLabel => GoogleFonts.leagueSpartan(
    color: AppColors.authMuted,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  /// Caption de paso ("Paso 1 de 3 · Identidad").
  static TextStyle get authStepCaption => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// Label del botón primario ("Siguiente", "Crear mi cuenta") — este
  /// rediseño cambió la familia de Nunito ([buttonLarge]) a League Spartan
  /// solo para el flujo de Auth.
  static TextStyle get authButtonLabel => GoogleFonts.leagueSpartan(
    color: AppColors.authInk,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w700,
  );

  /// Label del divisor "o continúa con".
  static TextStyle get authDividerLabel => GoogleFonts.nunito(
    color: AppColors.authMuted,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// Label del pill "Explorar como invitado".
  static TextStyle get authGuestPillLabel => GoogleFonts.leagueSpartan(
    color: AppColors.authGuestIconText,
    fontSize: 13.5,
    height: 18 / 13.5,
    fontWeight: FontWeight.w800,
  );

  // --- Pantalla Registro (Figma nodos 157:96, 113:95) ---

  /// "Crea una cuenta".
  static TextStyle get registerHeading => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );

  /// Dígito dentro del círculo indicador de paso.
  static TextStyle get stepIndicatorNumber => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Caption del indicador de paso ("Datos Personales").
  static TextStyle get stepIndicatorCaption => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  // --- Escala tipográfica base (Figma nodo 134:25, "Tipografias") ---
  // Los colores del tablero (#212B36/#637381/#919EAB) vienen de una paleta
  // genérica de starter-kit que nunca aparece en pantalla real, por eso
  // estos getters no fijan color — el caller aplica un token propio.
  // `h1`/`h2`/`h3`/`overline`/`bodyText1` se removieron (auditoría de
  // tipografía) por no tener ningún uso real en la app.

  /// Figma "H4".
  static TextStyle get h4 => GoogleFonts.nunito(
    fontSize: 24,
    height: 36 / 24,
    fontWeight: FontWeight.w700,
  );

  /// Figma "H5".
  static TextStyle get h5 => GoogleFonts.nunito(
    fontSize: 20,
    height: 30 / 20,
    fontWeight: FontWeight.w700,
  );

  /// Figma "H6".
  static TextStyle get h6 => GoogleFonts.nunito(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w700,
  );

  /// Figma "Subtitulo 1".
  static TextStyle get subtitle1 => GoogleFonts.nunito(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Figma "Subtitulo 2".
  static TextStyle get subtitle2 => GoogleFonts.nunito(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w600,
  );

  /// Figma "Cuerpo 1".
  static TextStyle get bodyText1 => GoogleFonts.nunito(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// Figma "Cuerpo 2".
  static TextStyle get bodyText2 => GoogleFonts.nunito(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Figma "Leyenda".
  static TextStyle get legend => GoogleFonts.nunito(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Figma "Boton Lg" — idéntico a [buttonLarge].
  static TextStyle get buttonLg => buttonLarge;

  /// Figma "Boton Md".
  static TextStyle get buttonMd => GoogleFonts.nunito(
    fontSize: 14,
    height: 24 / 14,
    fontWeight: FontWeight.w700,
  );

  /// Figma "Boton pq".
  static TextStyle get buttonSm => GoogleFonts.nunito(
    fontSize: 13,
    height: 22 / 13,
    fontWeight: FontWeight.w700,
  );

  // --- Pantalla detalle de negocio (Figma nodos 284:2256, 233:437) ---

  /// Título de portada ("Laguna de Apoyo").
  static TextStyle get detailTitle => GoogleFonts.leagueSpartan(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w900,
  );

  /// Pill de categoría.
  static TextStyle get detailTagPill => GoogleFonts.leagueSpartan(
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w800,
  );

  /// Valor de calificación en portada ("4.9").
  static TextStyle get detailRatingValue => GoogleFonts.leagueSpartan(
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Conteo de reseñas en portada ("(203 reseñas)") — Nunito, no League Spartan.
  static TextStyle get detailRatingCount => GoogleFonts.nunito(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Label de info rápida flotante ("Ubicación"/"Distancia"/"Hoy").
  static TextStyle get quickInfoLabel => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w400,
  );

  /// Valor de info rápida flotante ("Masaya, NI").
  static TextStyle get quickInfoValue => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  /// Label de pestaña del control segmentado ("Información" / "Reseñas & Fotos").
  static TextStyle get segmentedTabLabel => GoogleFonts.leagueSpartan(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Encabezado de sección ("Actividades", "Servicios del lugar", "Anfitrión"...).
  static TextStyle get detailSectionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w800,
  );

  /// Label de fila dentro de una tarjeta de detalle (amenidad/actividad).
  static TextStyle get detailRowText => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 14,
    height: 19.25 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Chip pequeño "Eco" dentro de una fila de amenidad.
  static TextStyle get ecoTagChip => GoogleFonts.leagueSpartan(
    color: AppColors.ecoForest,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  /// Nombre del autor de una reseña.
  static TextStyle get reviewAuthor => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Caption de fecha relativa de reseña ("hace 2 días").
  static TextStyle get reviewMeta => GoogleFonts.leagueSpartan(
    color: AppColors.neutral600,
    fontSize: 9,
    height: 13.5 / 9,
    fontWeight: FontWeight.w400,
  );

  /// Cuerpo de comentario de reseña.
  static TextStyle get reviewComment => GoogleFonts.leagueSpartan(
    color: AppColors.neutral800,
    fontSize: 12,
    height: 19.5 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Número grande de calificación resumen ("4.9").
  static TextStyle get ratingBig => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 36,
    height: 1.0,
    fontWeight: FontWeight.w900,
  );

  /// Label del botón "Reservar Ahora — C$350".
  static TextStyle get reserveButtonLabel => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
  );

  /// Caption "Cancela gratis hasta 48 horas antes".
  static TextStyle get reserveCaption => GoogleFonts.leagueSpartan(
    color: AppColors.neutral600,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w400,
  );

  // --- Rediseño de detalle de negocio ---

  /// Párrafo de descripción.
  static TextStyle get detailDescriptionText => GoogleFonts.nunito(
    color: AppColors.detailBodyBrown,
    fontSize: 12.5,
    height: 1.65,
    fontWeight: FontWeight.w400,
  );

  /// Link de expandir inline ("Mostrar más" / "Ver las N actividades").
  static TextStyle get detailInlineLink => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 11.5,
    height: 15 / 11.5,
    fontWeight: FontWeight.w700,
  );

  /// Label de fila de actividad/servicio.
  static TextStyle get detailActivityLabel => GoogleFonts.nunito(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 16 / 12.5,
    fontWeight: FontWeight.w600,
  );

  /// Badge "ECO" en una fila de actividad.
  static TextStyle get detailEcoBadge => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 9.5,
    height: 12 / 9.5,
    fontWeight: FontWeight.w800,
  );

  /// Label de pill de "Servicios del lugar".
  static TextStyle get detailServicePill => GoogleFonts.nunito(
    color: AppColors.detailBodyBrown,
    fontSize: 11.5,
    height: 15 / 11.5,
    fontWeight: FontWeight.w600,
  );

  /// Nombre del anfitrión ("Aníbal Ortega").
  static TextStyle get detailHostName => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13.5,
    height: 16 / 13.5,
    fontWeight: FontWeight.w800,
  );

  /// Badge "VERIFICADO" en la fila del anfitrión.
  static TextStyle get detailVerifiedBadge => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 9,
    height: 11 / 9,
    fontWeight: FontWeight.w800,
  );

  /// Label día/valor en la tarjeta de horario.
  static TextStyle get detailScheduleLabel => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w800,
  );

  /// Label de acción de pill de contacto ("Abrir").
  static TextStyle get detailPillAction => GoogleFonts.leagueSpartan(
    color: AppColors.detailBodyBrown,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w700,
  );

  /// Línea de dirección del mini-mapa "Cómo llegar".
  static TextStyle get detailMapAddress => GoogleFonts.nunito(
    color: AppColors.settingsTextDark,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// Barra inferior fija — label secundario ("Cómo llegar").
  static TextStyle get detailBottomBarSecondary => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 16 / 12.5,
    fontWeight: FontWeight.w800,
  );

  /// Barra inferior fija — label primario ("Escribir por WhatsApp").
  static TextStyle get detailBottomBarPrimary => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  // --- Rediseño del wizard de registro de negocio ---

  /// Título de la app bar ("Registra tu negocio" / "Editar negocio").
  static TextStyle get wizardAppBarTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w800,
  );

  /// Encabezado de paso ("Datos generales", "¿Dónde te encuentran?"...).
  static TextStyle get wizardStepHeading => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 19,
    height: 24 / 19,
    fontWeight: FontWeight.w900,
  );

  /// Subtítulo de paso, debajo de [wizardStepHeading].
  static TextStyle get wizardStepSubtitle => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 17 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Label de campo en mayúsculas ("NOMBRE DEL NEGOCIO", "CATEGORÍA"...).
  static TextStyle get wizardFieldLabel => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 13 / 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.9,
  );

  /// Título de sección de tarjeta ("Contacto", "Horarios de atención"...).
  static TextStyle get wizardCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Texto de un campo lleno ("Finca El Ceibo", "Masaya"...).
  static TextStyle get wizardFieldValue => GoogleFonts.nunito(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  /// Placeholder de un campo del wizard.
  static TextStyle get wizardFieldHint => GoogleFonts.nunito(
    color: AppColors.profileMuted,
    fontSize: 12.5,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  /// Caption de ayuda bajo un campo o tarjeta.
  static TextStyle get wizardCaption => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10.5,
    height: 15 / 10.5,
    fontWeight: FontWeight.w400,
  );

  /// Label de chip seleccionado/enfatizado (categoría, actividad, amenidad)
  /// — sin color: el caller elige tinta ([AppColors.settingsTextDark]
  /// seleccionado) o marrón ([AppColors.detailBodyBrown] no seleccionado).
  static TextStyle get wizardChipLabel => GoogleFonts.leagueSpartan(
    fontSize: 11.5,
    height: 15 / 11.5,
    fontWeight: FontWeight.w800,
  );

  /// Footer fijo del wizard — mismo componente que la barra inferior de detalle.
  static TextStyle get wizardFooterSecondary => detailBottomBarSecondary;
  static TextStyle get wizardFooterPrimary => detailBottomBarPrimary;

  // --- Rediseño de Inicio ---
  // Getters propios (no reusan sectionTitle/caption/cardTitle/etc., que se
  // comparten con Reservas/Mapa/tarjetas legacy) para no tocar esas otras
  // pantallas al ajustar el detalle visual de Inicio.

  /// "Buen día, Ana".
  static TextStyle get homeGreeting => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w400,
  );

  /// "¿A dónde vamos?".
  static TextStyle get homeHeading => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );

  /// Placeholder del campo de búsqueda.
  static TextStyle get homeSearchHint => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  /// Pill de categoría/ECO en la tarjeta hero — sin color: el caller elige
  /// [AppColors.settingsTextDark] (pill dorado) o [AppColors.surface100] (pill verde ECO).
  static TextStyle get homeHeroPill => GoogleFonts.leagueSpartan(
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w800,
  );

  /// Título de la tarjeta hero ("Laguna de Apoyo").
  static TextStyle get homeHeroTitle => GoogleFonts.leagueSpartan(
    color: Colors.white,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Línea de ubicación de la tarjeta hero.
  static TextStyle get homeHeroLocation => GoogleFonts.nunito(
    color: Colors.white.withValues(alpha: 0.88),
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Pill "Ver detalle →" en la tarjeta hero.
  static TextStyle get homeCtaPill => GoogleFonts.leagueSpartan(
    color: Colors.white,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w700,
  );

  /// Label de chip de filtro por categoría — sin color: el caller elige
  /// [AppColors.settingsTextDark] (seleccionado) o [AppColors.settingsTextMuted] (no seleccionado).
  static TextStyle get homeChipLabel => GoogleFonts.leagueSpartan(
    fontSize: 12,
    height: 15 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Encabezado de sección "Destacados" / "Cerca de ti".
  static TextStyle get homeSectionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w800,
  );

  /// "Ver todos".
  static TextStyle get homeSeeMore => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w700,
  );

  /// Título de tarjeta en Destacados/Cerca de ti.
  static TextStyle get homeCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Línea de ubicación de tarjeta en Destacados/Cerca de ti (sin ícono de pin).
  static TextStyle get homeCardLocation => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10.5,
    height: 14 / 10.5,
    fontWeight: FontWeight.w400,
  );

  /// Badge "ECO" pequeño sobre una miniatura de tarjeta.
  static TextStyle get homeMiniBadge => GoogleFonts.leagueSpartan(
    fontSize: 9,
    height: 12 / 9,
    fontWeight: FontWeight.w800,
  );
}

/// Gradiente de fondo compartido por el flujo de Auth (Splash → Login →
/// Registro), para que las tres pantallas se lean como una sola superficie
/// continua — `linear-gradient(180deg, #FFD028 0%, #FDB828 32%, #FF8A35 68%, #F97316 100%)`.
abstract class AppGradients {
  static const authBackgroundBegin = Alignment.topCenter;
  static const authBackgroundEnd = Alignment.bottomCenter;

  static const List<Color> authBackgroundColors = [
    AppColors.sunsetStart,
    AppColors.sunsetMid1,
    AppColors.sunsetMid2,
    AppColors.sunsetEnd,
  ];

  static const List<double> authBackgroundStops = [0.0, 0.32, 0.68, 1.0];
}

abstract class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.backgroundCream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        primary: AppColors.primary500,
        secondary: AppColors.accent300,
        surface: AppColors.backgroundCream,
      ),
      // Se llena cada slot (no solo los 3 que la app usa vía
      // Theme.of(context).textTheme) para que cualquier widget que caiga en
      // la tipografía default de Material (AppBar/Dialog/SnackBar/TextField,
      // un Text() sin estilo) use igual una de las dos fuentes de marca en
      // vez del Roboto genérico. Los tamaños siguen la escala estándar de
      // Material 3; solo se cambia familia, peso y color.
      textTheme: TextTheme(
        // Encabezados y títulos — League Spartan.
        displayLarge: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 57,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 45,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 36,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: AppTextStyles.heading,
        titleLarge: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.leagueSpartan(
          color: AppColors.neutral1100,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        // Cuerpo, descripciones, precios, fechas y botones — Nunito.
        bodyLarge: GoogleFonts.nunito(
          color: AppColors.neutral600,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: AppTextStyles.body,
        bodySmall: GoogleFonts.nunito(
          color: AppColors.neutral600,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: AppTextStyles.buttonLarge,
        labelMedium: GoogleFonts.nunito(
          color: AppColors.neutral1100,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: GoogleFonts.nunito(
          color: AppColors.neutral1100,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
