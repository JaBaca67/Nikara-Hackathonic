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

  // --- Profile screen styles (Figma node 259:224) ---

  /// Figma style "HL6": League Spartan Bold 18/28 — profile name.
  static TextStyle get profileName => GoogleFonts.leagueSpartan(
    color: AppColors.neutral1100,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w700,
  );

  /// Figma style "Subtitulo 1": Nunito SemiBold 16/24 — "lv 4/12".
  static TextStyle get profileLevel => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Figma style "Subtitulo 2": Nunito SemiBold 14/22 — "León, Nicaragua".
  static TextStyle get profileLocation => GoogleFonts.nunito(
    color: AppColors.neutral1100,
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w600,
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
