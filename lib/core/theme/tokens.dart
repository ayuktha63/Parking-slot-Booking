// ─────────────────────────────────────────────────────────────────────────────
// PARQX DESIGN TOKENS — customer app
//
// THE LANGUAGE: mobility-class. Light, calm, monochrome.
//
//   black   — the brand and the action. Every primary button, the selected
//             state, the wordmark. One black thing is the obvious next step.
//   white   — every surface. The map, sheets and lists sit on one plane.
//   greys   — fills and hairlines instead of cards and shadows. Structure comes
//             from spacing and type weight, not from boxes.
//   blue    — information only: links, focus, your location.
//   green   — availability, and nothing else. On a parking product it is the
//             most-read signal on screen, so it is never decoration.
//
// RULES
//   1. Screens never define a colour, radius, duration or text style.
//   2. Semantic names, not literal ones.
//   3. Colours that carry text record their contrast on white. Measured.
//
// The operator app keeps its own dark console language; the two products are
// deliberately not the same app.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';

abstract final class AppColors {
  const AppColors._();

  // ── Ink ──────────────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF000000); // 21:1
  static const Color inkSecondary = Color(0xFF545454); // 7.6:1
  static const Color inkTertiary = Color(0xFF6B6B6B); // 5.3:1 — AA for body text
  static const Color inkDisabled = Color(0xFFAFAFAF); // decorative / disabled only
  static const Color onInk = Color(0xFFFFFFFF);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  /// Inputs, chips, icon discs, secondary buttons.
  static const Color fill = Color(0xFFF3F3F3);
  static const Color fillPressed = Color(0xFFE6E6E6);

  /// Grouped content that needs to read as one object without a border.
  static const Color fillSubtle = Color(0xFFF8F8F8);

  /// Hairline dividers between rows.
  static const Color line = Color(0xFFEEEEEE);

  /// Borders on white controls (a free parking spot, an outlined option).
  static const Color lineStrong = Color(0xFFDDDDDD);

  // ── Information ──────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF276EF1); // 4.6:1
  static const Color accentSoft = Color(0xFFEBF1FE);

  // ── Status ───────────────────────────────────────────────────────────────
  static const Color positive = Color(0xFF067F42); // 5.1:1 — text
  static const Color positiveBright = Color(0xFF05A357); // dots, fills
  static const Color positiveSoft = Color(0xFFE7F5ED);

  static const Color warning = Color(0xFF9A5B00); // 5.4:1 — text
  static const Color warningBright = Color(0xFFFFB020); // dots, fills
  static const Color warningSoft = Color(0xFFFFF4DE);

  static const Color negative = Color(0xFFE11900); // 4.8:1
  static const Color negativeSoft = Color(0xFFFDEEEB);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ── Parking spots ────────────────────────────────────────────────────────
  //
  // Booked is grey, not red: a full row is a settled fact, not an error.
  static const Color spotFree = surface;
  static const Color spotFreeLine = lineStrong;
  static const Color spotSelected = ink;
  static const Color spotHeld = warningSoft;
  static const Color spotHeldLine = Color(0xFFFFD58A);
  static const Color spotYours = accentSoft;
  static const Color spotBooked = Color(0xFFEDEDED);
  static const Color spotClosed = fillSubtle;

  // ── Availability pressure (markers, rows) ────────────────────────────────
  static const Color availabilityPlenty = positiveBright;
  static const Color availabilityLimited = warningBright;
  static const Color availabilityFull = negative;

  // ── Elevation ────────────────────────────────────────────────────────────
  static const Color shadow = Color(0x14000000);
  static const Color scrim = Color(0x66000000);
}

/// The map's identity: a quiet light basemap on which the price markers are the
/// only high-contrast objects.
abstract final class AppMapStyle {
  const AppMapStyle._();

  /// Visible for the instant before tiles land — the basemap's own land colour.
  static const Color base = Color(0xFFF1F1EF);

  // ── The silver filter ────────────────────────────────────────────────────
  //
  // Standard OpenStreetMap tiles are beige, green and orange. Mobility maps are
  // grey: colour on the map belongs to the things you act on. This keeps a trace
  // of the original hue (parks still faintly green, water faintly blue), lifts
  // the blacks so labels soften, and compresses the range slightly:
  //
  //   c' = k · (lum · (1 − s) + c · s) + o
  static const double _s = 0.1; // hue kept
  static const double _k = 0.86; // contrast
  static const double _o = 34; // lift (0–255)
  static const double _lr = 0.2126, _lg = 0.7152, _lb = 0.0722;
  static const double _m = 1 - _s;

  static const List<double> silver = <double>[
    _k * (_m * _lr + _s), _k * _m * _lg, _k * _m * _lb, 0, _o,
    _k * _m * _lr, _k * (_m * _lg + _s), _k * _m * _lb, 0, _o,
    _k * _m * _lr, _k * _m * _lg, _k * (_m * _lb + _s), 0, _o,
    0, 0, 0, 1, 0,
  ];
}

/// 4pt grid.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// Horizontal page inset.
  static const double pageInset = 16;

  /// Space kept free at the end of a scrollable inside the tab shell when the
  /// shell's own inset is not available (sheets over the map).
  static const double bottomNavClearance = 96;
}

/// Corner radii. Controls are gently rounded; sheets are soft; pills are round.
abstract final class AppRadius {
  const AppRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);

  static const BorderRadius button = BorderRadius.all(rMd);
  static const BorderRadius field = BorderRadius.all(rMd);
  static const BorderRadius card = BorderRadius.all(rLg);
  static const BorderRadius tile = BorderRadius.all(rSm);
  static const BorderRadius photo = BorderRadius.all(rMd);
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheet = BorderRadius.vertical(top: rXl);
  static const BorderRadius dialog = BorderRadius.all(rXl);
}

/// Elevation is rare. Only things that float over the map or above content get
/// a shadow; everything else is separated by space and hairlines.
abstract final class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// A control floating over the map.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// A sheet or bar sitting above scrolled content.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, -4)),
  ];

  /// A card lifted off a white page (the live session).
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Motion, named by intent.
abstract final class AppMotion {
  const AppMotion._();

  static const Duration press = Duration(milliseconds: 90);
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration camera = Duration(milliseconds: 450);
  static const Duration emphasis = Duration(milliseconds: 650);
  static const Duration stagger = Duration(milliseconds: 40);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve decelerate = Curves.easeOutQuart;
  static const Curve emphasised = Curves.easeOutBack;
  static const Curve spring = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve exit = Curves.easeInCubic;
}

/// Fixed component sizes.
abstract final class AppSizes {
  const AppSizes._();

  static const double minTouchTarget = 48;

  static const double buttonHeight = 56;
  static const double buttonHeightCompact = 44;
  static const double pillHeight = 36;
  static const double fieldHeight = 56;
  static const double chipHeight = 36;
  static const double navBarHeight = 64;
  static const double appBarHeight = 56;

  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;

  /// The grey circle behind a row's leading icon.
  static const double iconDisc = 40;

  static const double avatarSm = 36;
  static const double avatarMd = 44;
  static const double avatarLg = 64;

  /// Photo on a parking row.
  static const double rowPhoto = 64;

  /// A spot in the floor plan.
  static const double spotWidth = 54;
  static const double spotHeight = 70;

  /// A round control floating over the map.
  static const double mapControl = 48;
}

abstract final class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 360;
  static const double medium = 600;
  static const double expanded = 905;

  static bool isCompact(double width) => width < medium;
}
