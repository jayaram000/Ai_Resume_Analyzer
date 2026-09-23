import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Defines the three Casefile font roles:
/// - Display: Fraunces (italic for heroes/welcome, 500 for headings)
/// - Mono: JetBrains Mono (500–700 for scores, percentages, data labels)
/// - Body: Public Sans (for UI chrome, buttons, nav labels, paragraph text)
class AppTypography {
  // ---------------------------------------------------------------------------
  // 1. Display — Fraunces
  // ---------------------------------------------------------------------------
  static TextStyle displayHero({
    Color? color,
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.fraunces(
      color: color,
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle displayHeading({
    Color? color,
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.fraunces(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Mono — JetBrains Mono
  // ---------------------------------------------------------------------------
  static TextStyle monoScore({
    Color? color,
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing = -0.5,
  }) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle monoLabel({
    Color? color,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing = 0.2,
  }) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Body — Public Sans
  // ---------------------------------------------------------------------------
  static TextStyle bodyRegular({
    Color? color,
    double fontSize = 14,
    double? height = 1.45,
  }) {
    return GoogleFonts.publicSans(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: height,
    );
  }

  static TextStyle bodyMedium({
    Color? color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    double? height = 1.4,
  }) {
    return GoogleFonts.publicSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  static TextStyle buttonText({
    Color? color,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing = 0.2,
  }) {
    return GoogleFonts.publicSans(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }

  // TextTheme integration helper
  static TextTheme createTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkInk : AppColors.lightInk;
    final secondary = isDark ? AppColors.darkInkSoft : AppColors.lightInkSoft;

    final base = GoogleFonts.publicSansTextTheme();
    return base.copyWith(
      displayLarge: displayHero(color: primary, fontSize: 32),
      displayMedium: displayHero(color: primary, fontSize: 26),
      headlineMedium: displayHeading(color: primary, fontSize: 20),
      headlineSmall: displayHeading(color: primary, fontSize: 18),
      titleLarge: GoogleFonts.publicSans(color: primary, fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.publicSans(color: primary, fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: bodyRegular(color: primary, fontSize: 15),
      bodyMedium: bodyRegular(color: primary, fontSize: 13),
      bodySmall: bodyRegular(color: secondary, fontSize: 12),
      labelLarge: buttonText(color: primary, fontSize: 13),
      labelMedium: monoLabel(color: secondary, fontSize: 11),
    );
  }
}
