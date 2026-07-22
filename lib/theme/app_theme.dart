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
