import 'package:flutter/material.dart';

/// Paper-ledger palette from the "ReceiptVault Screens" design (direction 2a):
/// warm paper ground, ink-black type, one green accent.
abstract final class AppColors {
  // Light (paper) mode.
  static const Color paper = Color(0xFFF4F1EA);
  static const Color paperDeep = Color(0xFFE9E5DB);
  static const Color paperCard = Color(0xFFFBF9F4);
  static const Color ink = Color(0xFF14140F);
  static const Color inkSoft = Color(0xFF4B483F);
  static const Color inkMuted = Color(0xFF6A675C);
  static const Color inkFaint = Color(0xFF8A8779);
  static const Color rule = Color(0xFFD8D3C6);
  static const Color ruleLight = Color(0xFFE2DDD1);
  static const Color accent = Color(0xFF0F6B3C);
  static const Color accentDeep = Color(0xFF0A4E2B);
  static const Color accentSoft = Color(0xFFD6DFD2);

  // Dark (ink) mode: the same ledger with paper and ink swapped.
  static const Color darkPaper = Color(0xFF14140F);
  static const Color darkPaperDeep = Color(0xFF0E0E0A);
  static const Color darkPaperCard = Color(0xFF1E1E18);
  static const Color darkInk = Color(0xFFF4F1EA);
  static const Color darkInkSoft = Color(0xFFCFCABD);
  static const Color darkInkMuted = Color(0xFFA19D8F);
  static const Color darkInkFaint = Color(0xFF7C7969);
  static const Color darkRule = Color(0xFF34342C);
  static const Color darkRuleLight = Color(0xFF2A2A23);
  static const Color darkAccent = Color(0xFF4E9E6F);
  static const Color darkAccentSoft = Color(0xFF1F3327);

  /// Stacked-bar shades for category shares, strongest first.
  static const List<Color> shareScale = [
    accent,
    Color(0xFF4E8C6A),
    Color(0xFF8FAF9B),
    rule,
  ];
  static const List<Color> darkShareScale = [
    darkAccent,
    Color(0xFF3E7A56),
    Color(0xFF2E5A40),
    darkRule,
  ];

  // Legacy names still referenced by older widgets.
  static const Color primary = accent;
  static const Color primaryDark = darkAccent;
}
