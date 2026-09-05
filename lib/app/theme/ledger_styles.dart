import 'package:flutter/material.dart';
import 'package:receipt_vault_ai/app/theme/app_colors.dart';

/// Typography and colour helpers for the paper-ledger design.
///
/// Numbers are always set in JetBrains Mono with tabular figures so amounts
/// align down a column. Section labels are small, tracked, uppercase mono.
abstract final class LedgerStyles {
  static const String sansFamily = 'InstrumentSans';
  static const String monoFamily = 'JetBrainsMono';

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color ink(BuildContext context) =>
      isDark(context) ? AppColors.darkInk : AppColors.ink;
  static Color inkSoft(BuildContext context) =>
      isDark(context) ? AppColors.darkInkSoft : AppColors.inkSoft;
  static Color inkMuted(BuildContext context) =>
      isDark(context) ? AppColors.darkInkMuted : AppColors.inkMuted;
  static Color inkFaint(BuildContext context) =>
      isDark(context) ? AppColors.darkInkFaint : AppColors.inkFaint;
  static Color rule(BuildContext context) =>
      isDark(context) ? AppColors.darkRule : AppColors.rule;
  static Color ruleLight(BuildContext context) =>
      isDark(context) ? AppColors.darkRuleLight : AppColors.ruleLight;
  static Color accent(BuildContext context) =>
      isDark(context) ? AppColors.darkAccent : AppColors.accent;
  static Color accentSoft(BuildContext context) =>
      isDark(context) ? AppColors.darkAccentSoft : AppColors.accentSoft;
  static Color paper(BuildContext context) =>
      isDark(context) ? AppColors.darkPaper : AppColors.paper;
  static Color paperDeep(BuildContext context) =>
      isDark(context) ? AppColors.darkPaperDeep : AppColors.paperDeep;
  static Color paperCard(BuildContext context) =>
      isDark(context) ? AppColors.darkPaperCard : AppColors.paperCard;
  static List<Color> shareScale(BuildContext context) =>
      isDark(context) ? AppColors.darkShareScale : AppColors.shareScale;

  /// Small tracked uppercase label, e.g. "SEP 2026 · 18 RECEIPTS".
  static TextStyle eyebrow(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: color ?? inkMuted(context),
  );

  /// Secondary mono line under a row title, e.g. "SEP 03 · GROCERIES".
  static TextStyle meta(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w400,
    color: color ?? inkMuted(context),
    fontFeatures: tabular,
  );

  /// Mono amount used at the end of a ledger row.
  static TextStyle rowAmount(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: 18,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: color ?? ink(context),
    fontFeatures: tabular,
  );

  /// Mono amount in a section header, e.g. a week total.
  static TextStyle headerAmount(BuildContext context) => TextStyle(
    fontFamily: monoFamily,
    fontSize: 12,
    height: 1,
    fontWeight: FontWeight.w700,
    color: ink(context),
    fontFeatures: tabular,
  );

  /// Body mono used inside the receipt card.
  static TextStyle receiptLine(BuildContext context, {Color? color}) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: 13,
        height: 1,
        fontWeight: FontWeight.w400,
        color: color ?? ink(context),
        fontFeatures: tabular,
      );

  /// Sans row title, e.g. a merchant name.
  static TextStyle rowTitle(BuildContext context, {Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: 16,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: color ?? ink(context),
  );

  /// Screen title, e.g. "Ledger".
  static TextStyle screenTitle(BuildContext context) => TextStyle(
    fontFamily: sansFamily,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -1,
    color: ink(context),
  );

  /// Mono filter chip text, e.g. "ALL", "STARRED".
  static TextStyle chip(BuildContext context, {Color? color}) =>
      chipFor(Theme.of(context).brightness, color: color);

  /// [chip] without a build context, for use while building the theme.
  static TextStyle chipFor(Brightness brightness, {Color? color}) => TextStyle(
    fontFamily: monoFamily,
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color:
        color ??
        (brightness == Brightness.dark
            ? AppColors.darkInkSoft
            : AppColors.inkSoft),
  );
}
