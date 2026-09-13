// ─────────────────────────────────────────────────────────────────────────────
// APP THEME
//
// Builds a complete ThemeData from the tokens, so a default-styled Material
// widget already looks right and no screen needs to restyle it.
//
// Shared byte-for-byte with the operator app, which calls `AppTheme.dark()`.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT CHANGED, AND WHY IT MATTERS MORE THAN IT SOUNDS
//
// DEPTH REPLACES OUTLINES. The previous theme drew a 1px border around cards,
// chips, fields, dialogs and list tiles. Outlining everything is the visual
// equivalent of italicising every word: when all separation is the same
// separation, nothing has hierarchy, and the result reads as a wireframe that
// was never finished. Containers here separate by surface step and tinted
// shadow; a border appears only where it carries meaning (a selected state, a
// destructive confirmation).
//
// SPLASH IS GONE. `InkSparkle` is Android's signature, not this product's. It
// fires a shader-based glitter burst on every tap, and it is one of the loudest
// "this is a Material app" tells there is. Feedback here is scale + haptics,
// applied by the shared button and card primitives.
//
// SURFACE TINT IS ZEROED EVERYWHERE. Material 3 tints elevated surfaces toward
// the primary colour automatically. With a violet primary that turns every
// raised white card faintly lilac, in a way nobody chose and which fights the
// deliberately violet-tinted neutrals.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  const AppTheme._();

  /// Customer app.
  ///
  /// DARK, despite the name — kept as `light()` because every call site and
  /// both integration suites reference it, and renaming it would be churn for
  /// no gain. The name is a leftover; the theme is the product.
  ///
  /// PARQX is a dark app with LIGHT content surfaces. The results sheet and the
  /// slot confirmation sheet are pure white and opaque, floating clear of a
  /// deep navy ground. That contrast is the signature, and it is why this is
  /// not simply "dark mode": the light surfaces are not an alternative theme,
  /// they are a component of this one. Screens that need a white surface ask
  /// for `AppColors.surface` explicitly.
  static ThemeData light() => _build(
        brightness: Brightness.dark,
        canvas: AppColors.canvas,
        surface: AppColors.surfaceDark,
        surfaceAlt: AppColors.surfaceAltDark,
        surfaceRaised: AppColors.surfaceRaisedDark,
        border: AppColors.borderDark,
        ink: AppColors.inkDark,
        inkSecondary: AppColors.inkSecondaryDark,
        inkMuted: AppColors.inkMutedDark,
      );

  /// Operator app. The same ground, tuned denser — see the operator screens for
  /// where they diverge. Used in a booth, often at night, for hours.
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        canvas: AppColors.canvasDeep,
        surface: AppColors.surfaceDark,
        surfaceAlt: AppColors.surfaceAltDark,
        surfaceRaised: AppColors.surfaceRaisedDark,
        border: AppColors.borderDark,
        ink: AppColors.inkDark,
        inkSecondary: AppColors.inkSecondaryDark,
        inkMuted: AppColors.inkMutedDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color surfaceAlt,
    required Color surfaceRaised,
    required Color border,
    required Color ink,
    required Color inkSecondary,
    required Color inkMuted,
  }) {
    final isDark = brightness == Brightness.dark;
    final text = AppTypography.textTheme(ink, inkSecondary);

    // On dark the full-strength brand does not have the luminance to carry white
    // text, so the dark theme promotes the muted tint to primary and puts dark
    // ink on it. Same brand, correctly inverted — not a second brand.
    // Full-strength violet on both builds. It is used as a FILLED button
    // colour carrying white text (5.15:1), not as text on the dark ground, so
    // the usual "lighten the brand for dark mode" move would only wash out the
    // one saturated colour the product has.
    final primary = AppColors.brand;
    final onPrimary = AppColors.onBrand;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark ? AppColors.brandSoftDark : AppColors.brandSoft,
      onPrimaryContainer: isDark ? AppColors.brandMuted : AppColors.brandStrong,
      secondary: isDark ? AppColors.successBright : AppColors.success,
      onSecondary: isDark ? AppColors.canvasDeep : AppColors.white,
      secondaryContainer: isDark ? AppColors.surfaceAltDark : AppColors.successSoft,
      onSecondaryContainer: isDark ? AppColors.successBright : AppColors.success,
      tertiary: AppColors.info,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.infoSoft,
      onTertiaryContainer: AppColors.info,
      error: AppColors.danger,
      onError: AppColors.white,
      errorContainer: isDark ? AppColors.surfaceAltDark : AppColors.dangerSoft,
      onErrorContainer: AppColors.danger,
      surface: surface,
      onSurface: ink,
      surfaceDim: canvas,
      surfaceBright: surfaceRaised,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceAlt,
      surfaceContainerHigh: surfaceAlt,
      surfaceContainerHighest: surfaceRaised,
      onSurfaceVariant: inkSecondary,
      outline: border,
      outlineVariant: border,
      shadow: AppColors.shadowTint,
      scrim: AppColors.scrim,
      inverseSurface: isDark ? AppColors.surface : AppColors.brandInk,
      onInverseSurface: isDark ? AppColors.ink : AppColors.onMap,
      inversePrimary: isDark ? AppColors.brand : AppColors.brandMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: text,
      fontFamily: AppTypography.family,

      // Material's stock ripple is a strong platform signature. PARQX gives
      // feedback through scale and haptics in its own primitives instead, so the
      // ripple is suppressed globally rather than fought per-widget.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      // Not transparent: this is what an InkWell uses for its press state
      // once the splash is gone. A flat tint is the quiet, non-Material
      // equivalent of the ripple.
      highlightColor: isDark ? const Color(0x14FFFFFF) : const Color(0x0F1B1035),
      hoverColor: isDark ? const Color(0x0DFFFFFF) : const Color(0x085B34E8),

      // ── App bar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        toolbarHeight: AppSizes.appBarHeight,
        iconTheme: IconThemeData(color: ink, size: AppSizes.iconMd),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // ── Buttons ──────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: surfaceAlt,
          disabledForegroundColor: inkMuted,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: text.labelLarge,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.transparent,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          // The one place an outline survives: a secondary button needs an edge
          // to be a button at all, and it is the weaker half of a real pair.
          side: BorderSide(color: isDark ? border : AppColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        ),
      ),

      // NB: `splashFactory` is NoSplash for the whole app, so a stock Material
      // button has no press feedback of its own. Anything the product styles
      // itself uses `Pressable` (scale + haptics); the buttons that remain
      // stock — TextButton, IconButton, and the pickers' internals — get an
      // explicit overlay here instead. Without it they are visually dead to the
      // touch, which is a worse outcome than the ripple this replaced.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primary.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return primary.withValues(alpha: 0.07);
            }
            return null;
          }),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.square(AppSizes.minTouchTarget),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return ink.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return ink.withValues(alpha: 0.06);
            }
            return null;
          }),
        ),
      ),

      // ── Input ────────────────────────────────────────────────────────────
      //
      // Filled, not outlined. A filled field says "type here" through its
      // surface; an outlined one says it with a rectangle. The border appears
      // only on focus and on error — the two moments it means something.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        // `inkMuted`, not `inkSubtle`: a hint a user has to read is text, and
        // text has to clear 4.5:1.
        hintStyle: text.bodyLarge?.copyWith(color: inkMuted),
        labelStyle: text.bodyMedium?.copyWith(color: inkSecondary),
        floatingLabelStyle: text.labelMedium?.copyWith(color: primary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        errorStyle: text.bodySmall?.copyWith(color: AppColors.danger),
      ),

      // ── Containers ───────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        // No side. Cards are separated by shadow and surface step; see
        // AppShadows.md, which is two layers rather than one blur.
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.rXl),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
        insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
        dragHandleColor: isDark ? AppColors.borderDark : AppColors.borderStrong,
        dragHandleSize: const Size(40, 4),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Small components ─────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: isDark ? AppColors.brandSoftDark : AppColors.brandSoft,
        // Unselected chips have no outline; the fill is the affordance. The
        // selected state earns its border, because that is a state worth
        // marking twice.
        side: BorderSide.none,
        labelStyle: text.labelMedium!.copyWith(color: inkSecondary),
        secondaryLabelStyle:
            text.labelMedium!.copyWith(color: isDark ? AppColors.brandMuted : AppColors.brandStrong),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chip),
        showCheckmark: false,
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: inkSecondary,
        textColor: ink,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.md,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.field),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceRaisedDark : AppColors.brandInk,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.onMap),
        actionTextColor: AppColors.brandMuted,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.field),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 0,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceAlt,
        circularTrackColor: surfaceAlt,
        linearMinHeight: 3,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceRaisedDark : AppColors.brandInk,
          borderRadius: AppRadius.tile,
        ),
        textStyle: text.bodySmall?.copyWith(color: AppColors.onMap),
      ),

      // Date and time pickers inherit the theme properly, so no screen needs to
      // re-wrap them in a corrective Theme.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primary,
        headerForegroundColor: onPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.rXl),
        ),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: surfaceAlt,
        hourMinuteColor: surfaceAlt,
        hourMinuteTextColor: ink,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.rXl),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: AppSizes.navBarHeight,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelSmall!.copyWith(color: primary)
              : text.labelSmall!.copyWith(color: inkMuted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.iconMd,
            color: states.contains(WidgetState.selected) ? primary : inkMuted,
          ),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ParqxPageTransitions(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Screen transition.
///
/// Material's `FadeForwardsPageTransitionsBuilder` slides a new route in from
/// the right while the old one fades — readable, but it is the Android system
/// transition, and it reads as such.
///
/// This one is the product's own: the incoming page rises a short distance while
/// scaling up from 96%, and the outgoing page scales *down* slightly and dims.
/// The two moving together read as depth — one card lifting off a stack — rather
/// than as two flat pages sliding past each other. Short (280ms) and on a
/// decelerating curve, so it never becomes something to sit through.
class _ParqxPageTransitions extends PageTransitionsBuilder {
  const _ParqxPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: AppMotion.spring,
      reverseCurve: AppMotion.exit,
    );
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.standard);

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1)
          .chain(CurveTween(curve: const Interval(0, 0.55)))
          .animate(enter),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
            .animate(enter),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(enter),
          child: ScaleTransition(
            // The page being covered recedes instead of sitting still.
            scale: Tween<double>(begin: 1, end: 0.97).animate(exit),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Convenience accessors so widgets read `context.colors.primary` rather than
/// reaching for `Theme.of(context).colorScheme` every time.
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Screen width, for the breakpoint helpers.
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompactWidth => AppBreakpoints.isCompact(screenWidth);

  /// True when the user has asked the OS to minimise animation. Motion that is
  /// decorative must check this; motion that conveys state may stay.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
