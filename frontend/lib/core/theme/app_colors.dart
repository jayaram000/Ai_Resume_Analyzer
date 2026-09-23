import 'package:flutter/material.dart';

/// Single source of truth for color design tokens in Flutter — "Casefile" Design System.
/// Mirrors backend `resume_undo/config/design_tokens.py`.
///
/// Concept: Your career is a working file under review, styled like paper, ink,
/// and a stamp of approval.
class AppColors {
  // ---------------------------------------------------------------------------
  // Light Mode ("Day desk")
  // ---------------------------------------------------------------------------
  static const Color lightPaper = Color(0xFFEEE9DC);      // background
  static const Color lightPaperAlt = Color(0xFFE4DDC9);   // cards, elevated surfaces
  static const Color lightInk = Color(0xFF211F1A);        // primary text
  static const Color lightInkSoft = Color(0xFF6B6455);    // secondary text
  static const Color lightRule = Color(0xFFCFC6AE);       // hairline borders/dividers
  static const Color lightCobalt = Color(0xFF2C4A7C);     // primary accent
  static const Color lightCobaltDeep = Color(0xFF1D3660); // hover/pressed state
  static const Color lightOchre = Color(0xFFB8862E);      // in-progress / warning
  static const Color lightForest = Color(0xFF3F6B4A);     // success / verified
  static const Color lightBrick = Color(0xFF9C3B34);      // error / flagged

  // ---------------------------------------------------------------------------
  // Dark Mode ("Night desk") — distinct stops engineered for contrast
  // ---------------------------------------------------------------------------
  static const Color darkPaper = Color(0xFF1B1914);       // background
  static const Color darkPaperAlt = Color(0xFF252119);    // cards, elevated surfaces
  static const Color darkInk = Color(0xFFECE6D6);         // primary text
  static const Color darkInkSoft = Color(0xFFA79C86);     // secondary text
  static const Color darkRule = Color(0xFF3A3527);        // hairline borders/dividers
  static const Color darkCobalt = Color(0xFF7EA1DA);      // primary accent
  static const Color darkCobaltDeep = Color(0xFFA8C2E8);  // hover/pressed state
  static const Color darkOchre = Color(0xFFE0A542);       // in-progress / warning
  static const Color darkForest = Color(0xFF7CB88A);      // success / verified
  static const Color darkBrick = Color(0xFFD9847A);       // error / flagged

  // ---------------------------------------------------------------------------
  // Canonical Brand / Semantic aliases (defaults to Dark "Night desk" as default mode)
  // ---------------------------------------------------------------------------
  static const Color paper = darkPaper;
  static const Color paperAlt = darkPaperAlt;
  static const Color ink = darkInk;
  static const Color inkSoft = darkInkSoft;
  static const Color rule = darkRule;
  static const Color cobalt = darkCobalt;
  static const Color cobaltDeep = darkCobaltDeep;
  static const Color ochre = darkOchre;
  static const Color forest = darkForest;
  static const Color brick = darkBrick;

  // Semantic compatibility aliases
  static const Color primary = cobalt;
  static const Color primaryAlt = cobaltDeep;
  static const Color secondary = ochre;
  static const Color background = paper;
  static const Color card = paperAlt;
  static const Color border = rule;
  static const Color textPrimary = ink;
  static const Color textSecondary = inkSoft;
  static const Color success = forest;
  static const Color warning = ochre;
  static const Color error = brick;

  // Light tints for badge chips
  static const Color primaryLight = Color(0xFFE0E8F5);
  static const Color secondaryLight = Color(0xFFF7EDDA);
  static const Color successLight = Color(0xFFE3EFE6);
  static const Color warningLight = Color(0xFFF7EDDA);
  static const Color errorLight = Color(0xFFF8E4E2);

  // Dark Canvas compatibility aliases
  static const Color bgDark = darkPaper;
  static const Color cardDark = darkPaperAlt;
  static const Color borderDark = darkRule;
  static const Color textPrimaryDark = darkInk;
  static const Color textSecondaryDark = darkInkSoft;

  // ---------------------------------------------------------------------------
  // Context-aware dynamic token resolvers
  // ---------------------------------------------------------------------------
  static Color resolvePaper(bool isDark) => isDark ? darkPaper : lightPaper;
  static Color resolvePaperAlt(bool isDark) => isDark ? darkPaperAlt : lightPaperAlt;
  static Color resolveInk(bool isDark) => isDark ? darkInk : lightInk;
  static Color resolveInkSoft(bool isDark) => isDark ? darkInkSoft : lightInkSoft;
  static Color resolveInkMuted(bool isDark) => isDark ? darkInkSoft : lightInkSoft;
  static Color resolveRule(bool isDark) => isDark ? darkRule : lightRule;
  static Color resolveCobalt(bool isDark) => isDark ? darkCobalt : lightCobalt;
  static Color resolveCobaltDeep(bool isDark) => isDark ? darkCobaltDeep : lightCobaltDeep;
  static Color resolveOchre(bool isDark) => isDark ? darkOchre : lightOchre;
  static Color resolveForest(bool isDark) => isDark ? darkForest : lightForest;
  static Color resolveBrick(bool isDark) => isDark ? darkBrick : lightBrick;

  static Color ofPaper(BuildContext context) =>
      resolvePaper(Theme.of(context).brightness == Brightness.dark);
  static Color ofPaperAlt(BuildContext context) =>
      resolvePaperAlt(Theme.of(context).brightness == Brightness.dark);
  static Color ofInk(BuildContext context) =>
      resolveInk(Theme.of(context).brightness == Brightness.dark);
  static Color ofInkSoft(BuildContext context) =>
      resolveInkSoft(Theme.of(context).brightness == Brightness.dark);
  static Color ofRule(BuildContext context) =>
      resolveRule(Theme.of(context).brightness == Brightness.dark);
  static Color ofCobalt(BuildContext context) =>
      resolveCobalt(Theme.of(context).brightness == Brightness.dark);
  static Color ofOchre(BuildContext context) =>
      resolveOchre(Theme.of(context).brightness == Brightness.dark);
  static Color ofForest(BuildContext context) =>
      resolveForest(Theme.of(context).brightness == Brightness.dark);
  static Color ofBrick(BuildContext context) =>
      resolveBrick(Theme.of(context).brightness == Brightness.dark);
}
