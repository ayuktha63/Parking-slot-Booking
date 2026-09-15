// ─────────────────────────────────────────────────────────────────────────────
// TYPE
//
// One family in two cuts: Inter for reading, Inter Display for anything set
// large. Hierarchy comes from size and weight, never from colour alone — titles
// are black and bold, supporting text is grey and regular.
//
// Large titles are tight (negative tracking) the way mobility apps set them;
// body text is left at its natural spacing so it stays easy to read.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTypography {
  const AppTypography._();

  static const String family = 'Inter';
  static const String displayFamily = 'InterDisplay';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme() {
    return const TextTheme(
      // Page titles: "Activity", "What's your number?"
      displayLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        color: AppColors.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        color: AppColors.ink,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFamily,
        fontSize: 28,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.ink,
      ),

      // Sheet and section titles.
      headlineLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 24,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: displayFamily,
        fontSize: 19,
        height: 1.28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),

      // Row titles.
      titleLarge: TextStyle(
        fontFamily: family,
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 1.32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: AppColors.ink,
      ),
      titleSmall: TextStyle(
        fontFamily: family,
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),

      bodyLarge: TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: AppColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: family,
        fontSize: 14,
        height: 1.43,
        fontWeight: FontWeight.w400,
        color: AppColors.inkSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: family,
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: AppColors.inkTertiary,
      ),

      // Buttons, chips, captions.
      labelLarge: TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: AppColors.ink,
      ),
      labelMedium: TextStyle(
        fontFamily: family,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
      labelSmall: TextStyle(
        fontFamily: family,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: AppColors.inkSecondary,
      ),
    );
  }

  /* ── numerals ─────────────────────────────────────────────────────────── */

  /// Prices, counts and times: tabular so digits do not jitter as they change.
  static TextStyle numeric({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: size >= 20 ? displayFamily : family,
        fontSize: size,
        height: 1.15,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing ?? (size >= 28 ? -0.8 : -0.2),
        fontFeatures: _tabular,
      );

  /// The live parking timer.
  static TextStyle timer({double size = 52, Color color = AppColors.ink}) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: color,
        fontFeatures: _tabular,
      );

  /// Spot codes and booking codes: readable at a glance, zero slashed.
  static TextStyle code({double size = 14, Color color = AppColors.ink, double spacing = 0.2}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: spacing,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.slashedZero()],
      );

  /// Small uppercase label above a group.
  static TextStyle overline({Color color = AppColors.inkTertiary}) => TextStyle(
        fontFamily: family,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
      );

  static TextStyle wordmark({double size = 28, Color color = AppColors.ink}) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: size * -0.04,
        color: color,
      );
}
