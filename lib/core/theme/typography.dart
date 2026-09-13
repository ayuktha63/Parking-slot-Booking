// ─────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY
//
// One type scale, named by role rather than by size, so a screen asks for
// "sectionTitle" instead of picking 18px and hoping it matches the screen next
// to it. Shared byte-for-byte with the operator app.
//
// ─────────────────────────────────────────────────────────────────────────────
// TWO CHANGES THAT DO MOST OF THE WORK
//
// 1. THE FONT IS BUNDLED, NOT FETCHED.
//    This file used to build every style through google_fonts, which downloads
//    Inter over the network on first launch and caches it in app storage. Until
//    that request completes — and permanently, on a device that is offline, on a
//    captive portal, or behind a content filter — Flutter silently falls back to
//    Roboto. An app whose entire type system can quietly become stock Android
//    default does not have a type system. Inter now ships in the binary.
//
//    (This was not hypothetical: the render harness in test/ hit exactly this
//    failure, where letting google_fonts attempt a real fetch under
//    tester.runAsync() produced an async-zone error no FlutterError.onError could
//    catch.)
//
// 2. REAL OPTICAL SIZING.
//    Inter 4.0 ships a companion family, InterDisplay, drawn specifically for
//    large text: tighter default spacing, finer stroke joins, smaller apertures.
//    Display sizes use it; UI and body sizes use Inter. This is what makes a
//    headline look *set* rather than "the body font, but bigger" — and "the body
//    font but bigger" is a defining trait of an undesigned app.
//
// ACCESSIBILITY
//    Nothing here sets a fixed pixel size at the call site. Flutter's text
//    scaling applies on top, and the scale is designed to remain legible and
//    overflow-free at 130% (the clamp set in main.dart) and to degrade
//    gracefully to 200% in the render harness.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTypography {
  const AppTypography._();

  /// Body, UI, labels, dense data.
  static const String family = 'Inter';

  /// Headlines and numerals set large. Optically corrected for size.
  static const String displayFamily = 'InterDisplay';

  /// Proportional lining figures are the default; these are the tabular ones.
  ///
  /// Used anywhere digits change in place — a countdown, a running duration, a
  /// price column. Without them the text reflows every time a `1` becomes a `7`,
  /// which is the jitter the old hold-countdown had.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Slashed zero, for codes where 0/O ambiguity matters — slot identifiers,
  /// booking references, OTP.
  static const List<FontFeature> _code = [
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  static TextTheme textTheme(Color ink, Color inkSecondary) {
    return TextTheme(
      // ── Display: the one big statement per screen ──────────────────────
      // InterDisplay, tight tracking. Negative letter-spacing at these sizes is
      // not a style choice, it is a correction: type drawn for 16px is spaced
      // too loosely when set at 34px.
      displayLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 36,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        color: ink,
      ),
      displaySmall: TextStyle(
        fontFamily: displayFamily,
        fontSize: 26,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: ink,
      ),

      // ── Headline: screen and sheet titles ──────────────────────────────
      headlineLarge: TextStyle(
        fontFamily: displayFamily,
        fontSize: 23,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: displayFamily,
        fontSize: 20,
        height: 1.28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
        color: ink,
      ),
      // Below 20px the display cut stops helping and Inter's larger apertures
      // read better, so the family switches here.
      headlineSmall: TextStyle(
        fontFamily: family,
        fontSize: 18,
        height: 1.33,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        color: ink,
      ),

      // ── Title: card headers, list items ────────────────────────────────
      titleLarge: TextStyle(
        fontFamily: family,
        fontSize: 16.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontFamily: family,
        fontSize: 15,
        height: 1.38,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontFamily: family,
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: ink,
      ),

      // ── Body ───────────────────────────────────────────────────────────
      bodyLarge: TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: family,
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: inkSecondary,
      ),
      bodySmall: TextStyle(
        fontFamily: family,
        fontSize: 12.5,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: inkSecondary,
      ),

      // ── Label: buttons, chips, overlines ───────────────────────────────
      labelLarge: TextStyle(
        fontFamily: family,
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontFamily: family,
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: inkSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: family,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: inkSecondary,
      ),
    );
  }

  /* ── numerals ─────────────────────────────────────────────────────────── */

  /// Prices, countdowns and counts set inline.
  static TextStyle numeric({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.2,
  }) =>
      TextStyle(
        fontFamily: size >= 20 ? displayFamily : family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: _tabular,
      );

  /// The large amount on a review or receipt screen.
  static TextStyle priceHero({Color? color, double size = 34}) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        color: color ?? AppColors.ink,
        fontFeatures: _tabular,
      );

  /// A price on a card or map marker.
  static TextStyle priceCompact({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color ?? AppColors.ink,
        fontFeatures: _tabular,
      );

  /// A running clock or countdown — the hold timer, elapsed parking duration.
  ///
  /// Display-cut and tabular so a five-minute countdown does not shuffle its own
  /// digits sideways once a second for five minutes.
  static TextStyle timer({Color? color, double size = 28}) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
        fontFeatures: _tabular,
      );

  /// A slot identifier such as "A12", a booking reference, an OTP digit.
  static TextStyle slotCode({Color? color, double size = 13}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: color,
        fontFeatures: _code,
      );

  /* ── decoration ───────────────────────────────────────────────────────── */

  /// Small uppercase section label.
  ///
  /// Wide tracking is mandatory for uppercase at small sizes — caps set at
  /// default tracking read as a solid block rather than as words.
  static TextStyle overline({Color? color}) => TextStyle(
        fontFamily: family,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: color ?? AppColors.inkMuted,
      );

  /// The PARQX wordmark.
  static TextStyle wordmark({double size = 40, Color? color}) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: size * -0.045,
        color: color ?? AppColors.ink,
      );
}
