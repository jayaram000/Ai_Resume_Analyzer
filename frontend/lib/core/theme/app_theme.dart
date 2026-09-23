import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Manages global theme mode toggling (defaults to Dark "Night desk" mode per Casefile spec)
class ThemeController {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static bool get isDark => themeModeNotifier.value == ThemeMode.dark;

  static void toggleTheme() {
    themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  static void setTheme(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }
}

class AppTheme {
  // Brand Color Palette (Casefile semantic palette)
  static const Color primary = AppColors.cobalt;
  static const Color primaryDark = AppColors.cobaltDeep;
  static const Color secondary = AppColors.ochre;
  static const Color success = AppColors.forest;
  static const Color warning = AppColors.ochre;
  static const Color error = AppColors.brick;

  static const Color accentGreen = AppColors.forest;
  static const Color accentOrange = AppColors.ochre;
  static const Color accentPurple = AppColors.cobalt;
  static const Color accentBlue = AppColors.cobalt;

  // Neutral Light Canvas Palette ("Day desk")
  static const Color bgLight = AppColors.lightPaper;
  static const Color surfaceLight = AppColors.lightPaperAlt;
  static const Color borderLight = AppColors.lightRule;
  static const Color textPrimaryLight = AppColors.lightInk;
  static const Color textSecondaryLight = AppColors.lightInkSoft;

  // Neutral Dark Canvas Palette ("Night desk")
  static const Color bgDark = AppColors.darkPaper;
  static const Color surfaceDark = AppColors.darkPaperAlt;
  static const Color borderDark = AppColors.darkRule;
  static const Color textPrimaryDark = AppColors.darkInk;
  static const Color textSecondaryDark = AppColors.darkInkSoft;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      textTheme: AppTypography.createTextTheme(Brightness.light),
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightCobalt,
        secondary: AppColors.lightOchre,
        surface: surfaceLight,
        error: AppColors.lightBrick,
        onError: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.lightCobalt,
        unselectedLabelColor: textSecondaryLight,
        indicatorColor: AppColors.lightCobalt,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightCobalt,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightCobalt,
          side: const BorderSide(color: AppColors.lightRule, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightCobalt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      textTheme: AppTypography.createTextTheme(Brightness.dark),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkCobalt,
        secondary: AppColors.darkOchre,
        surface: surfaceDark,
        error: AppColors.darkBrick,
        onError: Colors.black,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimaryDark,
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryDark),
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.darkCobalt,
        unselectedLabelColor: textSecondaryDark,
        indicatorColor: AppColors.darkCobalt,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkCobalt,
          foregroundColor: const Color(0xFF1B1914),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkCobalt,
          side: const BorderSide(color: AppColors.darkRule, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkCobalt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}
