import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color Palette (Clean Modern Light & Dark Support)
  static const Color primary = Color(0xFF6366F1);     // Indigo 500
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo 600
  static const Color secondary = Color(0xFF14B8A6);   // Teal 500
  static const Color accentGreen = Color(0xFF22C55E); // Success Green
  static const Color accentOrange = Color(0xFFF59E0B); // Amber / Orange
  static const Color accentPurple = Color(0xFF8B5CF6); // Purple 500
  static const Color accentBlue = Color(0xFF3B82F6);   // Blue 500

  // Neutral Light Canvas Palette
  static const Color bgLight = Color(0xFFF8FAFC);     // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White
  static const Color borderLight = Color(0xFFE2E8F0);  // Slate 200
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500

  // Neutral Dark Canvas Palette
  static const Color bgDark = Color(0xFF0F172A);      // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color borderDark = Color(0xFF334155);   // Slate 700
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surfaceLight,
        background: bgLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        elevation: 0,
        shadowColor: const Color(0x0F000000),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondaryLight,
        indicatorColor: primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surfaceDark,
        background: bgDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimaryDark),
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondaryDark,
        indicatorColor: primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
