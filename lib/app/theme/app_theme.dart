import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:receipt_vault_ai/app/theme/app_colors.dart';
import 'package:receipt_vault_ai/app/theme/ledger_styles.dart';

/// Material theme for the paper-ledger design: warm paper ground, ink type,
/// a single green accent, hairline rules instead of elevation, and small
/// corner radii so surfaces read as paper rather than pills.
abstract final class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    paper: AppColors.paper,
    paperCard: AppColors.paperCard,
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
    inkMuted: AppColors.inkMuted,
    rule: AppColors.rule,
    ruleLight: AppColors.ruleLight,
    accent: AppColors.accent,
    accentDeep: AppColors.accentDeep,
    accentSoft: AppColors.accentSoft,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    paper: AppColors.darkPaper,
    paperCard: AppColors.darkPaperCard,
    ink: AppColors.darkInk,
    inkSoft: AppColors.darkInkSoft,
    inkMuted: AppColors.darkInkMuted,
    rule: AppColors.darkRule,
    ruleLight: AppColors.darkRuleLight,
    accent: AppColors.darkAccent,
    accentDeep: AppColors.darkInk,
    accentSoft: AppColors.darkAccentSoft,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color paper,
    required Color paperCard,
    required Color ink,
    required Color inkSoft,
    required Color inkMuted,
    required Color rule,
    required Color ruleLight,
    required Color accent,
    required Color accentDeep,
    required Color accentSoft,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? AppColors.darkPaper : AppColors.paper,
      primaryContainer: accentSoft,
      onPrimaryContainer: accentDeep,
      secondary: inkSoft,
      onSecondary: paper,
      secondaryContainer: ruleLight,
      onSecondaryContainer: ink,
      tertiary: accent,
      onTertiary: paper,
      tertiaryContainer: accentSoft,
      onTertiaryContainer: accentDeep,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: const Color(0xFFF9DEDC),
      onErrorContainer: const Color(0xFF410E0B),
      surface: paperCard,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      surfaceContainerHighest: ruleLight,
      surfaceContainerHigh: ruleLight,
      surfaceContainer: paper,
      surfaceContainerLow: paper,
      surfaceContainerLowest: paperCard,
      outline: rule,
      outlineVariant: ruleLight,
      shadow: AppColors.ink,
      scrim: AppColors.ink,
      inverseSurface: isDark ? AppColors.paper : AppColors.ink,
      onInverseSurface: isDark ? AppColors.ink : AppColors.paper,
      inversePrimary: accentSoft,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: LedgerStyles.sansFamily,
      scaffoldBackgroundColor: paper,
    );

    TextStyle sans(
      double size,
      FontWeight weight, {
      double letterSpacing = 0,
      double height = 1.25,
      Color? color,
    }) => TextStyle(
      fontFamily: LedgerStyles.sansFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color ?? ink,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: sans(36, FontWeight.w600, letterSpacing: -1.4, height: 1),
      headlineMedium: sans(28, FontWeight.w600, letterSpacing: -1, height: 1.1),
      headlineSmall: sans(
        24,
        FontWeight.w600,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      titleLarge: sans(20, FontWeight.w600, letterSpacing: -0.4),
      titleMedium: sans(16, FontWeight.w600, letterSpacing: -0.2),
      titleSmall: sans(14, FontWeight.w600),
      bodyLarge: sans(16, FontWeight.w400, height: 1.5),
      bodyMedium: sans(14, FontWeight.w400, height: 1.45, color: inkSoft),
      bodySmall: sans(12, FontWeight.w400, height: 1.4, color: inkMuted),
      labelLarge: sans(14, FontWeight.w600),
      labelMedium: sans(12, FontWeight.w600),
      labelSmall: sans(11, FontWeight.w500),
    );

    final smallShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerColor: ruleLight,
      dividerTheme: DividerThemeData(color: ruleLight, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: paperCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: rule),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: paper,
        foregroundColor: ink,
        titleTextStyle: sans(20, FontWeight.w600, letterSpacing: -0.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: smallShape,
          textStyle: sans(15, FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: BorderSide(color: rule),
          shape: smallShape,
          textStyle: sans(15, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: smallShape,
          textStyle: sans(14, FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: inkSoft),
      ),
      iconTheme: IconThemeData(color: inkSoft),
      chipTheme: ChipThemeData(
        backgroundColor: paper,
        selectedColor: ink,
        side: BorderSide(color: rule),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: LedgerStyles.chipFor(brightness, color: inkSoft),
        secondaryLabelStyle: LedgerStyles.chipFor(brightness, color: paper),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: sans(14, FontWeight.w500, color: inkMuted),
        hintStyle: sans(14, FontWeight.w400, color: inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: inkSoft,
        textColor: ink,
        titleTextStyle: sans(15, FontWeight.w600),
        subtitleTextStyle: sans(13, FontWeight.w400, color: inkMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paperCard,
        shape: smallShape,
        titleTextStyle: sans(20, FontWeight.w600, letterSpacing: -0.4),
        contentTextStyle: sans(14, FontWeight.w400, color: inkSoft),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paperCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.paper : AppColors.ink,
        contentTextStyle: sans(
          14,
          FontWeight.w500,
          color: isDark ? AppColors.ink : AppColors.paper,
        ),
        shape: smallShape,
        behavior: SnackBarBehavior.floating,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: ink,
          selectedForegroundColor: paper,
          foregroundColor: inkSoft,
          side: BorderSide(color: rule),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: LedgerStyles.chipFor(brightness),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
