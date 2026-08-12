import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nikara_app/theme/app_colors.dart';

export 'package:nikara_app/theme/app_colors.dart';

/// Text styles extracted from the Figma "Text Styles".
abstract class AppTextStyles {
  /// Figma style "HL4": League Spartan Bold 24/36.
  static TextStyle get heading => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 24,
    height: 36 / 24,
    fontWeight: FontWeight.w700,
  );

  /// Figma style "Boton Lg": Nunito Bold 15/26.
  static TextStyle get buttonLarge => GoogleFonts.nunito(
    color: const Color(0xFF1A1510),
    fontSize: 15,
    height: 26 / 15,
    fontWeight: FontWeight.w700,
  );

  /// Logo wordmark "NÍKARA" — Quintessential Regular 40.
  static TextStyle get logoWordmark => GoogleFonts.quintessential(
    color: Colors.white,
    fontSize: 40,
    height: 1.0,
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

  // --- Home screen styles (Figma node 124:37) ---

  /// Figma style "HL3": League Spartan Bold 32/48 — the "Níkara" wordmark.
  static TextStyle get headingXL => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 32,
    height: 48 / 32,
    fontWeight: FontWeight.w700,
  );

  /// League Spartan ExtraBold 16/24 — section titles ("Más visitados").
  static TextStyle get sectionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w800,
  );

  /// Figma style "Leyenda": Nunito Regular 12/18 — search placeholder.
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

  /// Bottom-nav label. Color is intentionally omitted — callers pick the
  /// active (primary500) or inactive (neutral700) tint.
  static TextStyle get navLabel => GoogleFonts.leagueSpartan(
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  // --- Profile screen styles (Figma node 259:224 legacy + 377:483 redesign) ---

  /// Figma style "HL5": League Spartan Bold 20/30 — profile name.
  static TextStyle get profileName => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 20,
    height: 30 / 20,
    fontWeight: FontWeight.w700,
  );

  /// Figma style "Subtitulo 1": Nunito SemiBold 16/24 — "lv 4/12".
  static TextStyle get profileLevel => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Nunito Regular 12/18, [AppColors.profileMuted] — "León, Nicaragua".
  static TextStyle get profileLocation => GoogleFonts.nunito(
    color: AppColors.profileMuted,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// "Perfil" header title: League Spartan Black 24/36.
  static TextStyle get profileScreenTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 24,
    height: 36 / 24,
    fontWeight: FontWeight.w900,
  );

  /// Stat counter value ("6" / "3" / "520"): League Spartan Black 20/20.
  static TextStyle get profileStatValue => GoogleFonts.leagueSpartan(
    color: AppColors.settingsAccent,
    fontSize: 20,
    height: 1.0,
    fontWeight: FontWeight.w900,
  );

  /// Stat counter label ("Viajes" / "Insignias" / "Puntos").
  static TextStyle get profileStatLabel => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// "Próximo: Guardián del Territorio" caption.
  static TextStyle get profileLevelNext => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Circular progress ring percentage ("52%").
  static TextStyle get profileProgressPercent => GoogleFonts.leagueSpartan(
    color: AppColors.tagGold600,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w900,
  );

  /// Shared 10px caption — progress bar footer and favorite-card price
  /// suffix ("520 puntos" / "Meta: 1,000 pts" / "/persona").
  static TextStyle get profileCaption10 => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w400,
  );

  /// Favorite-card title: League Spartan ExtraBold 13/15.6.
  static TextStyle get favoriteCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 15.6 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Favorite-card location caption.
  static TextStyle get favoriteCardCaption => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w400,
  );

  /// Favorite-card price ("C$480").
  static TextStyle get favoriteCardPrice => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 13,
    height: 19.5 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Badge grid card title: League Spartan ExtraBold 9/10.8.
  static TextStyle get badgeCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 9,
    height: 10.8 / 9,
    fontWeight: FontWeight.w800,
  );

  /// Badge grid status pill ("✓ Obtenida" / "Bloqueada"). Color is
  /// intentionally omitted — callers use the badge's own tint or
  /// [AppColors.profileMuted] when locked.
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

  // --- Settings screen styles (Figma node 361:323) ---

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

  // --- Map screen styles (Figma node 167:1849) ---

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

  // --- Bookings screen styles (Figma node 170:23) ---

  /// Figma names this text node's style "H5" — Nunito Bold, not the
  /// League Spartan used by most other screen headings; matches the
  /// literal spec returned for node 170:23, not a generic-font oversight.
  static TextStyle get bookingHeaderTitle => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
  );

  /// Figma names this text node's style "H6" — Nunito Bold, same note as
  /// [bookingHeaderTitle].
  static TextStyle get bookingCardTitle => GoogleFonts.nunito(
    color: Colors.white,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bookingMeta => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get bookingLabel => GoogleFonts.nunito(
    color: AppColors.neutral800,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static TextStyle get bookingCode => GoogleFonts.robotoMono(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bookingTotal => GoogleFonts.nunito(
    color: AppColors.bookingConfirmed,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bookingStatusChip => GoogleFonts.nunito(
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bookingPillCount => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bookingActionLabel => GoogleFonts.nunito(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );

  // --- Register screen styles (Figma nodes 157:96, 113:95) ---

  /// League Spartan Bold 22/28 — "Crea una cuenta".
  static TextStyle get registerHeading => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );

  /// Nunito Regular 14 — the step-indicator digit inside each circle.
  static TextStyle get stepIndicatorNumber => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Nunito Regular 12 — the step-indicator caption ("Datos Personales").
  static TextStyle get stepIndicatorCaption => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  // --- Escala tipográfica base (Figma node 134:25, "TIpografias") ---
  // The board's own specimen colors (#212B36/#637381/#919EAB) come from a
  // generic starter-kit palette that never actually appears in any built
  // screen, so these getters intentionally leave color unset — callers
  // apply one of the app's own neutral tokens instead. Sizes/weights were
  // cross-validated: "Boton Lg" here matches [buttonLarge] byte-for-byte.

  /// Text style "H1": Nunito Bold 64/80.
  static TextStyle get h1 => GoogleFonts.nunito(
    fontSize: 64,
    height: 80 / 64,
    fontWeight: FontWeight.w700,
  );

  /// Text style "H2": Nunito Bold 48/64.
  static TextStyle get h2 => GoogleFonts.nunito(
    fontSize: 48,
    height: 64 / 48,
    fontWeight: FontWeight.w700,
  );

  /// Text style "H3": Nunito Bold 32/48.
  static TextStyle get h3 => GoogleFonts.nunito(
    fontSize: 32,
    height: 48 / 32,
    fontWeight: FontWeight.w700,
  );

  /// Text style "H4": Nunito Bold 24/36.
  static TextStyle get h4 => GoogleFonts.nunito(
    fontSize: 24,
    height: 36 / 24,
    fontWeight: FontWeight.w700,
  );

  /// Text style "H5": Nunito Bold 20/30.
  static TextStyle get h5 => GoogleFonts.nunito(
    fontSize: 20,
    height: 30 / 20,
    fontWeight: FontWeight.w700,
  );

  /// Text style "H6": Nunito Bold 18/28.
  static TextStyle get h6 => GoogleFonts.nunito(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w700,
  );

  /// Text style "Subtitulo 1": Nunito SemiBold 16/24.
  static TextStyle get subtitle1 => GoogleFonts.nunito(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Text style "Subtitulo 2": Nunito SemiBold 14/22.
  static TextStyle get subtitle2 => GoogleFonts.nunito(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w600,
  );

  /// Text style "Cuerpo 1": Nunito Regular 16/24.
  static TextStyle get bodyText1 => GoogleFonts.nunito(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  /// Text style "Cuerpo 2": Nunito Regular 14/22.
  static TextStyle get bodyText2 => GoogleFonts.nunito(
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Text style "Leyenda": Nunito Regular 12/18.
  static TextStyle get legend => GoogleFonts.nunito(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Text style "Overline": Nunito Bold 12/18, uppercase, tracked.
  static TextStyle get overline => GoogleFonts.nunito(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Text style "Boton Lg" — identical to [buttonLarge] (Nunito Bold 15/26).
  static TextStyle get buttonLg => buttonLarge;

  /// Text style "Boton Md": Nunito Bold 14/24.
  static TextStyle get buttonMd => GoogleFonts.nunito(
    fontSize: 14,
    height: 24 / 14,
    fontWeight: FontWeight.w700,
  );

  /// Text style "Boton pq" (small): Nunito Bold 13/22.
  static TextStyle get buttonSm => GoogleFonts.nunito(
    fontSize: 13,
    height: 22 / 13,
    fontWeight: FontWeight.w700,
  );

  // --- Business detail screen styles (Figma nodes 284:2256, 233:437) ---

  /// Cover title ("Laguna de Apoyo"): League Spartan Black 26/1.15, per
  /// Claude Design Pantalla 3a.
  static TextStyle get detailTitle => GoogleFonts.leagueSpartan(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w900,
  );

  /// Category tag pill: League Spartan ExtraBold 11/15, per Pantalla 3a.
  static TextStyle get detailTagPill => GoogleFonts.leagueSpartan(
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w800,
  );

  /// Cover rating value ("4.9"): League Spartan ExtraBold 13/16, per
  /// Pantalla 3a.
  static TextStyle get detailRatingValue => GoogleFonts.leagueSpartan(
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Cover rating count ("(203 reseñas)"): Nunito Regular 12/18, per
  /// Pantalla 3a (the cover's rating row is Nunito, not League Spartan).
  static TextStyle get detailRatingCount => GoogleFonts.nunito(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Floating quick-info label ("Ubicación"/"Distancia"/"Hoy") — Nunito
  /// Regular 10/15, per Claude Design Pantalla 3a.
  static TextStyle get quickInfoLabel => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w400,
  );

  /// Floating quick-info value ("Masaya, NI") — League Spartan ExtraBold
  /// 12.5, per Claude Design Pantalla 3a.
  static TextStyle get quickInfoValue => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  /// Segmented-control tab label ("Información" / "Reseñas & Fotos").
  static TextStyle get segmentedTabLabel => GoogleFonts.leagueSpartan(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Section heading ("Actividades", "Servicios del lugar", "Anfitrión"...):
  /// League Spartan ExtraBold 15, per Claude Design Pantalla 3a.
  static TextStyle get detailSectionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w800,
  );

  /// Row label inside a detail card (amenity/activity name).
  static TextStyle get detailRowText => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 14,
    height: 19.25 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Small "Eco" tag chip inside an amenity row.
  static TextStyle get ecoTagChip => GoogleFonts.leagueSpartan(
    color: AppColors.ecoForest,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  /// Review author name.
  static TextStyle get reviewAuthor => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Review relative-date caption ("hace 2 días").
  static TextStyle get reviewMeta => GoogleFonts.leagueSpartan(
    color: AppColors.neutral600,
    fontSize: 9,
    height: 13.5 / 9,
    fontWeight: FontWeight.w400,
  );

  /// Review comment body.
  static TextStyle get reviewComment => GoogleFonts.leagueSpartan(
    color: AppColors.neutral800,
    fontSize: 12,
    height: 19.5 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Big rating summary number ("4.9"): League Spartan Black 36/36.
  static TextStyle get ratingBig => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 36,
    height: 1.0,
    fontWeight: FontWeight.w900,
  );

  /// "Reservar Ahora — C$350" button label.
  static TextStyle get reserveButtonLabel => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w700,
  );

  /// "Cancela gratis hasta 48 horas antes" caption.
  static TextStyle get reserveCaption => GoogleFonts.leagueSpartan(
    color: AppColors.neutral600,
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w400,
  );

  // --- Business detail redesign (Claude Design turn 3, Pantalla 3a) ---

  /// Description paragraph body: Nunito Regular 12.5/1.65.
  static TextStyle get detailDescriptionText => GoogleFonts.nunito(
    color: AppColors.detailBodyBrown,
    fontSize: 12.5,
    height: 1.65,
    fontWeight: FontWeight.w400,
  );

  /// Inline expand link ("Mostrar más" / "Ver las N actividades"): League
  /// Spartan Bold 11.5, [AppColors.accent300].
  static TextStyle get detailInlineLink => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 11.5,
    height: 15 / 11.5,
    fontWeight: FontWeight.w700,
  );

  /// Actividad/servicio row label: Nunito SemiBold 12.5.
  static TextStyle get detailActivityLabel => GoogleFonts.nunito(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 16 / 12.5,
    fontWeight: FontWeight.w600,
  );

  /// "ECO" badge on an activity row: League Spartan ExtraBold 9.5.
  static TextStyle get detailEcoBadge => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 9.5,
    height: 12 / 9.5,
    fontWeight: FontWeight.w800,
  );

  /// "Servicios del lugar" pill label: Nunito SemiBold 11.5.
  static TextStyle get detailServicePill => GoogleFonts.nunito(
    color: AppColors.detailBodyBrown,
    fontSize: 11.5,
    height: 15 / 11.5,
    fontWeight: FontWeight.w600,
  );

  /// Host name ("Aníbal Ortega"): League Spartan ExtraBold 13.5.
  static TextStyle get detailHostName => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13.5,
    height: 16 / 13.5,
    fontWeight: FontWeight.w800,
  );

  /// "VERIFICADO" badge on the host row: League Spartan ExtraBold 9.
  static TextStyle get detailVerifiedBadge => GoogleFonts.leagueSpartan(
    color: AppColors.accent300,
    fontSize: 9,
    height: 11 / 9,
    fontWeight: FontWeight.w800,
  );

  /// Horario card's bold day/value label: League Spartan ExtraBold 12.
  static TextStyle get detailScheduleLabel => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w800,
  );

  /// A contact/pill action label ("Abrir"): League Spartan Bold 11.
  static TextStyle get detailPillAction => GoogleFonts.leagueSpartan(
    color: AppColors.detailBodyBrown,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w700,
  );

  /// "Cómo llegar" mini-map address line: Nunito SemiBold 12.
  static TextStyle get detailMapAddress => GoogleFonts.nunito(
    color: AppColors.settingsTextDark,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// The sticky bottom bar's two action labels: League Spartan ExtraBold,
  /// [AppColors.settingsTextDark] — 12.5 for the secondary ("Cómo llegar"),
  /// 13 for the primary ("Escribir por WhatsApp").
  static TextStyle get detailBottomBarSecondary => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 16 / 12.5,
    fontWeight: FontWeight.w800,
  );

  static TextStyle get detailBottomBarPrimary => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  // --- Wizard redesign (Claude Design turn 4, Pantallas 4a-4e) ---

  /// App bar title ("Registra tu negocio" / "Editar negocio").
  static TextStyle get wizardAppBarTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w800,
  );

  /// Step heading ("Datos generales", "¿Dónde te encuentran?"...).
  static TextStyle get wizardStepHeading => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 19,
    height: 24 / 19,
    fontWeight: FontWeight.w900,
  );

  /// Step subheading, right under [wizardStepHeading].
  static TextStyle get wizardStepSubtitle => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12,
    height: 17 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Uppercase field label ("NOMBRE DEL NEGOCIO", "CATEGORÍA"...).
  static TextStyle get wizardFieldLabel => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextMuted,
    fontSize: 10,
    height: 13 / 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.9,
  );

  /// Card section title ("Contacto", "Horarios de atención"...).
  static TextStyle get wizardCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Filled-field display text ("Finca El Ceibo", "Masaya"...).
  static TextStyle get wizardFieldValue => GoogleFonts.nunito(
    color: AppColors.settingsTextDark,
    fontSize: 12.5,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  /// Placeholder/hint text inside a wizard field — same size as
  /// [wizardFieldValue], muted and regular-weight.
  static TextStyle get wizardFieldHint => GoogleFonts.nunito(
    color: AppColors.profileMuted,
    fontSize: 12.5,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  /// Helper caption under a field or card ("Aparece solo en 'Cómo
  /// llegar'..."). 10.5/400 Nunito, muted.
  static TextStyle get wizardCaption => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10.5,
    height: 15 / 10.5,
    fontWeight: FontWeight.w400,
  );

  /// Selected/emphasized chip label (category, activity, amenity):
  /// League Spartan ExtraBold 11.5 — callers pick the ink ([settingsTextDark]
  /// selected) or brown ([detailBodyBrown] unselected) tint themselves.
  static TextStyle get wizardChipLabel => GoogleFonts.leagueSpartan(
    fontSize: 11.5,
    height: 15 / 11.5,
    fontWeight: FontWeight.w800,
  );

  /// Sticky-footer secondary/primary action label — same family/weight as
  /// [detailBottomBarSecondary]/[detailBottomBarPrimary] (12.5 / 13),
  /// reused verbatim since the wizard's sticky footer is the same
  /// component.
  static TextStyle get wizardFooterSecondary => detailBottomBarSecondary;
  static TextStyle get wizardFooterPrimary => detailBottomBarPrimary;

  // --- Home redesign (Claude Design turn 2, Pantalla 2a "Inicio") ---
  // Dedicated getters (not reusing sectionTitle/caption/cardTitle/etc. —
  // those are shared with Bookings/Map/legacy destination cards, and this
  // pass is scoped to matching 2a's Home exactly without touching those
  // other screens).

  /// "Buen día, Ana": Nunito Regular 11.
  static TextStyle get homeGreeting => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w400,
  );

  /// "¿A dónde vamos?": League Spartan Black 22/1.2.
  static TextStyle get homeHeading => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );

  /// Search field hint/placeholder: Nunito Regular 12.5.
  static TextStyle get homeSearchHint => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  /// Hero card's category/ECO pill: League Spartan ExtraBold 11 — callers
  /// pick the tint ([AppColors.settingsTextDark] on the gold category
  /// pill, [AppColors.surface100] on the green ECO pill).
  static TextStyle get homeHeroPill => GoogleFonts.leagueSpartan(
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w800,
  );

  /// Hero card title ("Laguna de Apoyo"): League Spartan Bold 20/1.2, white.
  static TextStyle get homeHeroTitle => GoogleFonts.leagueSpartan(
    color: Colors.white,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Hero card location line: Nunito Regular 12, white @88%.
  static TextStyle get homeHeroLocation => GoogleFonts.nunito(
    color: Colors.white.withValues(alpha: 0.88),
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// "Ver detalle →" pill on the hero card: League Spartan Bold 11, white.
  static TextStyle get homeCtaPill => GoogleFonts.leagueSpartan(
    color: Colors.white,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w700,
  );

  /// Category filter chip label: League Spartan Bold 12 — callers pick
  /// [AppColors.settingsTextDark] (selected) or [AppColors.settingsTextMuted]
  /// (unselected).
  static TextStyle get homeChipLabel => GoogleFonts.leagueSpartan(
    fontSize: 12,
    height: 15 / 12,
    fontWeight: FontWeight.w700,
  );

  /// "Destacados" / "Cerca de ti" section heading: League Spartan
  /// ExtraBold 15.
  static TextStyle get homeSectionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w800,
  );

  /// "Ver todos": Nunito Bold 11.
  static TextStyle get homeSeeMore => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 11,
    height: 15 / 11,
    fontWeight: FontWeight.w700,
  );

  /// Destacados/Cerca-de-ti card title: League Spartan ExtraBold 13.
  static TextStyle get homeCardTitle => GoogleFonts.leagueSpartan(
    color: AppColors.settingsTextDark,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w800,
  );

  /// Destacados/Cerca-de-ti card location line: Nunito Regular 10.5 — no
  /// leading pin icon in Pantalla 2a, unlike the hero card's location line.
  static TextStyle get homeCardLocation => GoogleFonts.nunito(
    color: AppColors.settingsTextMuted,
    fontSize: 10.5,
    height: 14 / 10.5,
    fontWeight: FontWeight.w400,
  );

  /// Small "ECO" badge text on a card thumbnail: League Spartan ExtraBold 9.
  static TextStyle get homeMiniBadge => GoogleFonts.leagueSpartan(
    fontSize: 9,
    height: 12 / 9,
    fontWeight: FontWeight.w800,
  );
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
      // Every slot filled — not just the 3 this app happens to reach via
      // Theme.of(context).textTheme — so ANY widget that falls back to
      // Material's default typography (AppBar/Dialog/SnackBar/TextField
      // titles, a bare Text() with no style, etc.) still lands on one of
      // the two official brand fonts instead of the generic Roboto
      // default. Sizes follow Material 3's standard type scale; only the
      // family, weight and color are swapped to match the brand.
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
