import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens extracted from the Figma file "UI-NIKARA" (node 157:2).
/// Names mirror the Local Variable scale defined in the Figma file.
abstract class AppColors {
  /// Variable "100" — near-white surface used for input fields.
  static const surface100 = Color(0xFFFDFDFD);

  /// Variable "300" — olive green used for links and accents.
  static const accent300 = Color(0xFF8B922A);

  /// Variable "400" — orange-red, gradient end stop.
  static const primary400 = Color(0xFFFF600F);

  /// Variable "500" — main brand gold.
  static const primary500 = Color(0xFFFDBE02);

  /// Variable "600" — muted brown-gray for secondary text and borders.
  static const neutral600 = Color(0xFF8C7373);

  /// Variable "700" — light gold, gradient end stop.
  static const primary700 = Color(0xFFFFD866);

  /// Variable "1100" — pure black, used for primary text.
  static const neutral1100 = Color(0xFF000000);

  /// Raw fill (not a bound variable in Figma) — cream card/app background.
  static const backgroundCream = Color(0xFFFFF9F0);

  // --- Home screen tokens (Figma node 124:37, "Inicio") ---
  // Same Local Variable collection as the login screen, but this frame
  // binds a wider slice of the neutral/brown scale plus its own accents.

  /// Variable "200" — light gray, used for the "Por región" divider rail.
  static const surface200 = Color(0xFFE6E5E5);

  /// Variable "400" — muted gray, status-bar time text.
  static const neutral400 = Color(0xFFB7AEAE);

  /// Variable "700" — secondary/caption text (card location, "Ver Mas").
  static const neutral700 = Color(0xFF725E5A);

  /// Variable "800" — dark brown, price text and thumbnail-selector borders.
  static const neutral800 = Color(0xFF564343);

  /// Variable "900" — near-black brown.
  static const neutral900 = Color(0xFF3A2C2C);

  /// Variable "500" (accent collection) — olive-lime ECO badge fill.
  static const ecoGreen500 = Color(0xFFC2CA5B);

  /// Variable "600" (gold collection — distinct from neutral600) — the
  /// featured-card descriptive tag pill ("Laguna Volcánica").
  static const tagGold600 = Color(0xFFFFCC33);

  /// Variable "600" (lime collection) — notification-bell pill fill.
  static const notificationPill = Color(0xFFD1D77E);

  /// Raw fill — notification badge counter circle.
  static const notificationBadge = Color(0xFF404413);

  // --- Splash/transition screen tokens (Figma node 95:2, "Precarga") ---

  /// Variable "500" (coral collection) — gradient's bottom-right stop.
  static const coral500 = Color(0xFFFF8243);

  // --- Profile screen tokens (Figma node 259:224, "Perfil") ---

  /// Variable "500" (a second, lighter neutral scale used on this screen) —
  /// muted taupe for captions ("Granada", "520 puntos").
  static const neutral500 = Color(0xFFA19191);

  /// Header gradient top stop — pale gold.
  static const profileHeaderGoldPale = Color(0xFFFFE599);

  /// Header gradient third stop — soft coral (distinct from [coral500]).
  static const profileHeaderCoral = Color(0xFFFFA375);

  // --- Settings screen tokens (Figma node 361:323, "Ajustes") ---
  // This frame binds a separate warm-neutral palette from the rest of the
  // app rather than the shared brown/gold scale above.

  /// Screen background.
  static const settingsBackground = Color(0xFFF7F3EC);

  /// Gold accent — row icon tint, "on" toggle fill.
  static const settingsAccent = Color(0xFFF0B500);

  /// Primary row/heading text.
  static const settingsTextDark = Color(0xFF261D0C);

  /// Secondary text — section labels, row values, captions.
  static const settingsTextMuted = Color(0xFF8A7A65);

  /// "Cerrar sesión" — destructive action tint.
  static const settingsDanger = Color(0xFFCC5510);

  /// "Off" toggle track fill.
  static const settingsToggleOff = Color(0xFFC8BDB0);

  // --- Bookings screen tokens (Figma node 170:23, "Reservas") ---

  /// Variable "200" (olive collection) — "Confirmada" status + paid-total.
  static const bookingConfirmed = Color(0xFF656B1F);

  /// Variable "300" (rust collection) — "Pendiente" status.
  static const bookingPending = Color(0xFFDB4900);

  /// Raw fill — placeholder thumbnail background (also used in Perfil).
  static const placeholderTan = Color(0xFFE5DFD2);

  // --- Paleta maestra (Figma node 125:2, "Paleta de colores") ---
  // This board is a raw canvas of swatches (not a component the
  // design-context tool can traverse), so these hex values were extracted
  // by pixel-sampling the rendered board instead of reading bound variable
  // names directly. Several swatches already had a confirmed name elsewhere
  // in this file (cross-checked by exact hex match) — those are reused
  // as-is and just annotated here; only the genuinely new swatches get a
  // fresh constant. Names below are positional (left-to-right on the
  // board) since the official Figma variable numbers weren't resolvable
  // for this specific node.

  /// Primario 1/9 — palest gold.
  static const primario1 = Color(0xFFFFF2CC);
  // Primario 2/9 == profileHeaderGoldPale (#FFE599).
  // Primario 3/9 == primary700 (#FFD866).
  // Primario 4/9 == tagGold600 (#FFCC33).
  // Primario 5/9 == primary500 (#FDBE02).
  /// Primario 6/9 — muted amber.
  static const primario6 = Color(0xFFCC9900);
  /// Primario 7/9 — deep amber.
  static const primario7 = Color(0xFF997300);
  /// Primario 8/9 — dark brown-gold.
  static const primario8 = Color(0xFF664C00);
  /// Primario 9/9 — near-black gold shadow.
  static const primario9 = Color(0xFF332600);

  /// Secundario 1/9 — palest olive.
  static const secundario1 = Color(0xFFF3F5DB);
  /// Secundario 2/9 — pale olive.
  static const secundario2 = Color(0xFFEDEFCC);
  /// Secundario 3/9 — light olive.
  static const secundario3 = Color(0xFFDFE3A5);
  // Secundario 4/9 == notificationPill (#D1D77E).
  // Secundario 5/9 == ecoGreen500 (#C2CA5B).
  /// Secundario 6/9 — mid olive.
  static const secundario6 = Color(0xFFAEB738);
  // Secundario 7/9 == accent300 (#8B922A).
  // Secundario 8/9 == bookingConfirmed (#656B1F).
  // Secundario 9/9 == notificationBadge (#404413).

  /// Complementario 1/9 — palest coral.
  static const complementario1 = Color(0xFFFFEEE6);
  /// Complementario 2/9 — pale coral.
  static const complementario2 = Color(0xFFFFE7DB);
  /// Complementario 3/9 — light coral.
  static const complementario3 = Color(0xFFFFC5A8);
  // Complementario 4/9 == profileHeaderCoral (#FFA375).
  // Complementario 5/9 == coral500 (#FF8243).
  // Complementario 6/9 == primary400 (#FF600F).
  // Complementario 7/9 == bookingPending (#DB4900).
  /// Complementario 8/9 — deep rust.
  static const complementario8 = Color(0xFFA83800);
  /// Complementario 9/9 — near-black rust shadow.
  static const complementario9 = Color(0xFF752700);

  /// Neutro 100 — pure white (distinct from [surface100]'s off-white).
  static const neutral100 = Color(0xFFFFFFFF);
  // Neutro 200 == surface200 (#E6E5E5).
  /// Neutro 300 — light warm gray.
  static const neutral300 = Color(0xFFCECACA);
  // Neutro 400..900 and 1100 == neutral400..neutral900 and neutral1100
  // above, confirmed by exact hex match at their expected board position.
  /// Neutro 1000 — near-black warm gray.
  static const neutral1000 = Color(0xFF1E1515);
  // Neutro 1100 == neutral1100 (#000000).

  // --- Business detail screen tokens (Figma nodes 284:2256, 233:437) ---

  /// Forest green — eco activity icons/tags and review-avatar fill. Distinct
  /// from the brand's [ecoGreen500] (olive), this is a separate accent used
  /// only on this screen.
  static const ecoForest = Color(0xFF3A7D3A);

  /// Segmented-control track background ("Información" / "Reseñas & Fotos").
  static const segmentedTrackBg = Color(0xFFF4EDE8);

  /// Solid near-black ink used for text on gold buttons/pills throughout
  /// the app (previously inlined as a literal hex in several screens).
  static const textInk = Color(0xFF1A1510);

  // --- Profile screen full redesign (Figma nodes 377:483, 421:361) ---

  /// Muted taupe — "9:41" mock status text, location caption, locked-badge
  /// title/status text. Distinct from [neutral500] (#A19191).
  static const profileMuted = Color(0xFFB8AA98);

  /// Hairline dividers and the edit/settings/share button fill.
  static const profileDivider = Color(0xFFF2EBE0);

  /// Level progress bar track + locked-badge card fill.
  static const progressTrack = Color(0xFFEDE6D8);

  /// "Guardián del Bosque" badge tint.
  static const badgeForest = Color(0xFF7A8C28);

  /// "Protector del Lago" badge tint.
  static const badgeLake = Color(0xFF5A6B1A);
}

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

  /// Logo wordmark "NIKARA" — Quintessential Regular 40.
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

  /// Figma style "HL3": League Spartan Bold 32/48 — the "Nikara" wordmark.
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

  static TextStyle get bookingHeaderTitle => GoogleFonts.playfairDisplay(
    color: AppColors.neutral1100,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get bookingCardTitle => GoogleFonts.playfairDisplay(
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

  /// Cover title ("Laguna de Apoyo"): League Spartan Bold 24/32.
  static TextStyle get detailTitle => GoogleFonts.leagueSpartan(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
  );

  /// Category tag pill: League Spartan Bold 10/15.
  static TextStyle get detailTagPill => GoogleFonts.leagueSpartan(
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w700,
  );

  /// Cover rating value ("4.9"): League Spartan Bold 12/16.
  static TextStyle get detailRatingValue => GoogleFonts.leagueSpartan(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Cover rating count ("(203 reseñas)"): League Spartan Regular 11/16.5.
  static TextStyle get detailRatingCount => GoogleFonts.leagueSpartan(
    fontSize: 11,
    height: 16.5 / 11,
    fontWeight: FontWeight.w400,
  );

  /// Floating quick-info label ("Ubicación"/"Distancia"/"Precio").
  static TextStyle get quickInfoLabel => GoogleFonts.leagueSpartan(
    color: AppColors.neutral600,
    fontSize: 10,
    height: 15 / 10,
    fontWeight: FontWeight.w600,
  );

  /// Floating quick-info value ("Masaya, NI").
  static TextStyle get quickInfoValue => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );

  /// Segmented-control tab label ("Información" / "Reseñas & Fotos").
  static TextStyle get segmentedTabLabel => GoogleFonts.leagueSpartan(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
  );

  /// Section heading ("Actividades", "Descripción", "Opiniones"...).
  static TextStyle get detailSectionTitle => GoogleFonts.leagueSpartan(
    color: AppColors.textInk,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
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
      textTheme: TextTheme(
        headlineSmall: AppTextStyles.heading,
        bodyMedium: AppTextStyles.body,
        labelLarge: AppTextStyles.buttonLarge,
      ),
    );
  }
}
