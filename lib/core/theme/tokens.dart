// ─────────────────────────────────────────────────────────────────────────────
// PARQX DESIGN TOKENS — SINGLE SOURCE OF TRUTH
//
// Shared byte-for-byte between the customer app and the operator app.
//
// ─────────────────────────────────────────────────────────────────────────────
// THE IDENTITY: DEEP NAVY + ELECTRIC VIOLET + WHITE SHEETS
//
// PARQX is a DARK product with LIGHT content surfaces. That combination is the
// whole visual signature, and getting it the wrong way round is what made
// earlier versions look ordinary:
//
//   dark   — the app's ground. Home chrome, the map, Bookings, Profile, Active
//            Parking, the slot floor plan. Deep navy, never neutral black.
//   light  — the surfaces that carry a decision. The results sheet, the slot
//            confirmation sheet. Pure white, fully opaque, floating clear of
//            the dark ground on a large radius.
//   violet — spent on exactly one thing per screen: the action, or the
//            selection. It is the only saturated colour in the chrome.
//
// The contrast between those three is what reads as "expensive". A screen that
// is all dark is a dashboard; a screen that is all light is a form; the two
// stacked with violet between them is a product.
//
// NEUTRALS ARE NAVY-TINTED, NEVER GREY. Every neutral carries blue at low
// saturation, so the whole interface sits in one temperature. Greys read as
// unstyled — it is the cheapest premium signal there is and costs nothing.
//
// RULES
//   1. No screen defines a colour, radius, duration or text style. Ever.
//   2. Semantic names, not literal ones.
//   3. Slot state colours are defined once and mean the same in both apps.
//   4. Contrast ratios are recorded beside colours that carry text. Measured.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/widgets.dart';

abstract final class AppColors {
  const AppColors._();

  // ── Brand: electric violet ───────────────────────────────────────────────
  //
  // `brand` on white: 5.15:1 — white label text on a filled button passes AA.
  static const Color brand = Color(0xFF6D4AFF);
  static const Color brandBright = Color(0xFF8B6DFF); // hover, accents on dark
  static const Color brandDeep = Color(0xFF5433E0); // pressed
  static const Color brandStrong = Color(0xFF4B27CC); // text on a light tint
  static const Color brandMuted = Color(0xFFB5A0FF); // primary on deep navy
  static const Color onBrand = Color(0xFFFFFFFF);

  /// Violet tint on a WHITE surface — the secondary button fill on the results
  /// sheet, the selected nav pill.
  static const Color brandSoft = Color(0xFFEDE9FE);

  /// Violet tint on a DARK surface. The light tint would glare here.
  static const Color brandSoftDark = Color(0xFF241B4D);

  /// The deepest violet-navy. Hero surfaces, the celebration screen.
  static const Color brandInk = Color(0xFF130B33);

  // ── The dark ground ──────────────────────────────────────────────────────
  static const Color canvasDeep = Color(0xFF070B16); // behind everything
  static const Color canvas = Color(0xFF0B1020); // page background
  static const Color surfaceDark = Color(0xFF141B2D); // card on dark
  static const Color surfaceAltDark = Color(0xFF1B2337); // field, inactive chip
  static const Color surfaceRaisedDark = Color(0xFF232C42); // raised on dark
  static const Color borderDark = Color(0xFF263048);

  static const Color inkDark = Color(0xFFFFFFFF); // primary text on dark
  static const Color inkSecondaryDark = Color(0xFFA3ADC2); // 7.3:1 on canvas
  static const Color inkMutedDark = Color(0xFF77839B); // 4.6:1 on canvas — AA

  // ── The light surfaces ───────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF); // sheets, cards on light
  static const Color canvasLight = Color(0xFFF7F8FC); // light page background
  static const Color surfaceAlt = Color(0xFFF1F3F9); // field on white
  static const Color surfaceSunken = Color(0xFFE8EBF3); // wells, tracks
  static const Color border = Color(0xFFE6E9F2);
  static const Color borderStrong = Color(0xFFD3D8E6);

  static const Color ink = Color(0xFF0F1424); // primary text on white
  static const Color inkSecondary = Color(0xFF4A5468); // 8.6:1 on white
  static const Color inkMuted = Color(0xFF6B7588); // 5.2:1 on white — AA
  //
  // NOT for meaningful text: 3.4:1 on white. Decorative glyphs and dividers
  // only. Placeholder text a user must read uses `inkMuted`.
  static const Color inkSubtle = Color(0xFF929BAD);

  // ── Status ───────────────────────────────────────────────────────────────
  //
  // `success` is the availability green from the reference — brighter and more
  // saturated than a typical "ok" green, because on this product it is the
  // single most-read signal on the screen.
  static const Color success = Color(0xFF16A34A); // 3.9:1 white-on; large text
  static const Color successBright = Color(0xFF22C55E); // on dark
  static const Color successDeep = Color(0xFF15803D); // text on a light tint
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color successSoftDark = Color(0xFF0C2A1A);

  static const Color warning = Color(0xFFB45309); // 4.6:1 white-on — AA
  static const Color warningBright = Color(0xFFF59E0B); // on dark
  static const Color warningSoft = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFDC2626); // 4.8:1 white-on — AA
  static const Color dangerBright = Color(0xFFF87171); // on dark
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color dangerSoftDark = Color(0xFF2A1218);

  static const Color info = Color(0xFF2563EB);
  static const Color infoBright = Color(0xFF60A5FA); // on dark
  static const Color infoSoft = Color(0xFFDBEAFE);

  static const Color white = Color(0xFFFFFFFF);

  // ── Slot states ──────────────────────────────────────────────────────────
  //
  // `booked` is NOT red. The operator app's old constant was literally
  // `stateBooked = errorRed`, so a fully-let lot — the operator's best possible
  // outcome — rendered as a wall of error red. Occupied is settled, not wrong.
  static const Color slotAvailable = successBright;
  static const Color slotAvailableSoft = Color(0x1F22C55E);
  static const Color slotSelected = brand;
  static const Color slotSelectedSoft = Color(0x336D4AFF);
  static const Color slotHeld = warningBright;
  static const Color slotHeldSoft = Color(0x1FF59E0B);
  static const Color slotOccupied = Color(0xFF5A6480);
  static const Color slotOccupiedSoft = Color(0xFF1E2639);
  static const Color slotClosed = Color(0xFF3A4358);
  static const Color slotClosedSoft = Color(0xFF161C2B);

  // ── Availability pressure (map markers, cards) ───────────────────────────
  static const Color availabilityPlenty = success;
  static const Color availabilityLimited = warning;
  static const Color availabilityFull = Color(0xFF9F1239);

  // ── Elevation ────────────────────────────────────────────────────────────
  //
  // Shadows are navy-black, not neutral black: a pure black shadow over a
  // tinted ground muddies it.
  static const Color shadowTint = Color(0xFF060A14);
  static const Color shadow = Color(0x14060A14);
  static const Color shadowStrong = Color(0x24060A14);
  static const Color scrim = Color(0xB3060A14);

  /// Content over the map or over a photograph.
  static const Color mapOverlayInk = Color(0xFF0A0E1C);
  static const Color onMap = Color(0xFFFFFFFF);
  static const Color onMapMuted = Color(0xFFA3ADC2);
}

/// Gradients. Used sparingly — a gradient is a statement, and PARQX makes about
/// four of them.
abstract final class AppGradients {
  const AppGradients._();

  /// The primary action. A short, steep ramp reads as a lit surface; a long
  /// rainbow ramp reads as a 2014 mobile app.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C5CFF), Color(0xFF5433E0)],
  );

  /// The confirmation screen — the one moment the product celebrates.
  static const LinearGradient celebration = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A1A6B), Color(0xFF130B33)],
  );

  /// Hero surfaces on dark — Active Parking, the slot floor plan.
  static const LinearGradient ink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF161E33), Color(0xFF0B1020)],
  );

  /// The subtle top-left glow the reference puts behind dark screen headers.
  static const LinearGradient headerGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x2E6D4AFF), Color(0x000B1020)],
  );

  /// Fades map or photo content out from under floating chrome so text stays
  /// readable without a hard-edged bar.
  static const LinearGradient mapTopFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xCC070B16), Color(0x00070B16)],
  );

  static const LinearGradient mapBottomFade = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xE6070B16), Color(0x00070B16)],
  );

  /// Over a photograph, so overlaid text is legible regardless of the image.
  static const LinearGradient photoScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xF20B1020), Color(0x800B1020), Color(0x000B1020)],
    stops: [0, 0.45, 1],
  );
}

/// The map's visual identity.
///
/// PARQX renders OpenStreetMap tiles through a colour matrix that turns them
/// into a deep navy basemap with the parks and water still readable. No API key,
/// no tile provider account, no extra dependency — the same tiles, art-directed.
///
/// Why bother: on a stock OSM basemap (beige roads, green parks, pink
/// motorways) a price marker is one more coloured object in a busy field. On
/// this one it is the brightest thing on screen, which is the entire job of a
/// parking map.
abstract final class AppMapStyle {
  const AppMapStyle._();

  // ── The filter ───────────────────────────────────────────────────────────
  //
  // The basemap is produced by INVERTING the tiles, not by dimming them.
  //
  // Dimming was the obvious first attempt and it is wrong. OSM draws place
  // labels and road casings in near-black; scaling every channel toward zero
  // takes the land from light beige to dark, but it takes the labels from dark
  // to invisible. The result is a dark map you cannot read.
  //
  // Inverting solves it in one move: land (light) becomes dark, and labels
  // (dark) become light.
  //
  // The maths, per channel:
  //   1. Blend toward luminance, keeping [_hueKeep] of the original channel so
  //      parks still read green and water still reads blue after the flip.
  //   2. Invert and remap onto a chosen output range, so source black lands on
  //      [_paper] (bright enough for labels) and source white lands on [_ink]
  //      (the app's own navy, so the map and the chrome are the same product).
  //
  //   out_i = paper_i - scale_i x blend_i,  scale_i = (paper_i - ink_i) / 255
  //
  // The constant term falls out as exactly paper_i, which is a useful sanity
  // check when tuning: the offsets ARE the colour that black becomes.
  static const double _hueKeep = 0.30;
  static const double _lr = 0.2126, _lg = 0.7152, _lb = 0.0722;

  /// What source BLACK becomes: labels and road casings.
  static const double _paperR = 173, _paperG = 186, _paperB = 214;

  /// What source WHITE becomes: land fill. Matches `AppColors.canvas`.
  static const double _inkR = 11, _inkG = 16, _inkB = 32;

  static const double _sR = (_paperR - _inkR) / 255;
  static const double _sG = (_paperG - _inkG) / 255;
  static const double _sB = (_paperB - _inkB) / 255;

  static const double _m = 1 - _hueKeep;

  static const List<double> desaturateDarken = <double>[
    -_sR * (_m * _lr + _hueKeep), -_sR * (_m * _lg), -_sR * (_m * _lb), 0, _paperR,
    -_sG * (_m * _lr), -_sG * (_m * _lg + _hueKeep), -_sG * (_m * _lb), 0, _paperG,
    -_sB * (_m * _lr), -_sB * (_m * _lg), -_sB * (_m * _lb + _hueKeep), 0, _paperB,
    0, 0, 0, 1, 0,
  ];

  /// Painted over the filtered tiles to seat them in the brand's navy.
  static const Color tint = Color(0x1A0B1020);

  /// The basemap's own background, visible for the instant before tiles land.
  static const Color base = Color(0xFF0B1020);
}

/// Spacing scale. A 4pt base grid.
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

  /// Standard horizontal page inset.
  static const double pageInset = 20;

  /// Space reserved at the bottom of scrollables so the floating nav never
  /// covers the last item.
  static const double bottomNavClearance = 108;
}

/// Corner radii.
///
/// Generous, matching the reference: pills are fully round, cards sit at 20,
/// sheets at 28, photographs at 14. Small radii on large surfaces read as
/// utilitarian.
abstract final class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 34;
  static const double pill = 999;

  static const Radius rXs = Radius.circular(xs);
  static const Radius rSm = Radius.circular(sm);
  static const Radius rMd = Radius.circular(md);
  static const Radius rLg = Radius.circular(lg);
  static const Radius rXl = Radius.circular(xl);
  static const Radius rXxl = Radius.circular(xxl);

  static const BorderRadius card = BorderRadius.all(rLg);
  static const BorderRadius cardLarge = BorderRadius.all(rXl);
  static const BorderRadius field = BorderRadius.all(rMd);
  static const BorderRadius button = BorderRadius.all(rMd);
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheet = BorderRadius.vertical(top: rXl);
  static const BorderRadius tile = BorderRadius.all(Radius.circular(14));
  static const BorderRadius photo = BorderRadius.all(Radius.circular(14));
}

/// Elevation presets.
///
/// Every preset above `sm` is TWO layers: a tight contact shadow that anchors
/// the element to the surface, and a wide ambient shadow that gives it height.
/// One blurred layer reads as a sticker; two read as an object.
abstract final class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> none = <BoxShadow>[];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F060A14), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0D060A14), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x14060A14), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x12060A14), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1F060A14), blurRadius: 30, offset: Offset(0, 14)),
  ];

  /// For elements floating over the map, where there is no surface to sit on
  /// and the shadow is doing all the work of separation.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x33060A14), blurRadius: 8, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x40060A14), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// Under a bottom sheet, thrown upward.
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x40060A14), blurRadius: 40, offset: Offset(0, -10)),
  ];

  /// The primary action, lit by its own colour. Used on exactly one control per
  /// screen; if two things glow, neither is primary.
  static const List<BoxShadow> brandLift = [
    BoxShadow(color: Color(0x4D6D4AFF), blurRadius: 22, offset: Offset(0, 8)),
  ];
}

/// Motion. Durations and curves named by intent — motion only where it aids
/// understanding. Nothing here animates decoration.
abstract final class AppMotion {
  const AppMotion._();

  /// A press-down scale. Shorter than [instant] because it must feel like
  /// contact, not like an animation.
  static const Duration press = Duration(milliseconds: 90);

  /// Immediate feedback — a tap, a toggle.
  static const Duration instant = Duration(milliseconds: 120);

  /// Standard transition — a card expanding, a chip selecting.
  static const Duration quick = Duration(milliseconds: 200);

  /// Screen and sheet transitions.
  static const Duration normal = Duration(milliseconds: 280);

  /// Map camera movement, which needs to feel physical rather than instant.
  static const Duration camera = Duration(milliseconds: 450);

  /// Deliberate emphasis — a booking confirming.
  static const Duration emphasis = Duration(milliseconds: 600);

  /// The confirmation sequence, which is choreographed rather than animated.
  static const Duration celebration = Duration(milliseconds: 900);

  /// Interval between staggered children entering a list.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve decelerate = Curves.easeOutQuart;
  static const Curve emphasised = Curves.easeOutBack;

  /// Settles with a little weight behind it, without the overshoot of
  /// [emphasised]. The default for anything that changes size.
  static const Curve spring = Cubic(0.22, 1.0, 0.36, 1.0);

  /// For an element leaving: fast out, no lingering.
  static const Curve exit = Curves.easeInCubic;
}

/// Fixed component sizes, so touch targets are consistent and accessible.
abstract final class AppSizes {
  const AppSizes._();

  /// Minimum touch target. Below this, controls fail accessibility guidance.
  static const double minTouchTarget = 48;

  static const double buttonHeight = 54;
  static const double buttonHeightCompact = 40;
  static const double fieldHeight = 52;

  /// The hero search control. Taller than a field on purpose: it is the one
  /// thing on Home the product wants you to touch.
  static const double heroFieldHeight = 56;

  static const double chipHeight = 40;
  static const double navBarHeight = 64;
  static const double appBarHeight = 56;

  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;

  static const double avatarSm = 34;
  static const double avatarMd = 44;
  static const double avatarLg = 64;

  /// The photograph on a discovery card.
  static const double cardPhoto = 96;

  /// Parking card imagery aspect.
  static const double cardImageAspect = 16 / 9;

  /// A slot tile in the layout view.
  static const double slotTileWidth = 58;
  static const double slotTileHeight = 74;

  /// A floating control over the map.
  static const double mapControl = 48;
}

/// Breakpoints.
abstract final class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 360;
  static const double medium = 600;
  static const double expanded = 905;
  static const double large = 1240;

  static bool isCompact(double width) => width < medium;
  static bool isMedium(double width) => width >= medium && width < expanded;
  static bool isExpanded(double width) => width >= expanded;

  static int cardColumns(double width) {
    if (width >= large) return 4;
    if (width >= expanded) return 3;
    if (width >= medium) return 2;
    return 1;
  }
}
