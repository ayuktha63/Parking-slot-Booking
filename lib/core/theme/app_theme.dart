// ─────────────────────────────────────────────────────────────────────────────
// THEME
//
// Material is the engine, not the look. Every component theme below is set so
// that a stock Material widget dropped into a screen already speaks the PARQX
// language: white ground, black actions, grey fills, hairlines, no ripples.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  const AppTheme._();

  /// System bars for a light app: a transparent status bar and a white
  /// navigation bar, both with dark icons. `SystemUiOverlayStyle.dark` is NOT
  /// this — it paints the navigation bar black.
  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  static ThemeData light() {
    final text = AppTypography.textTheme();

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.ink,
      onPrimary: AppColors.onInk,
      primaryContainer: AppColors.fill,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.positiveBright,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.positiveSoft,
      onSecondaryContainer: AppColors.positive,
      tertiary: AppColors.accent,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.accentSoft,
      onTertiaryContainer: AppColors.accent,
      error: AppColors.negative,
      onError: AppColors.white,
      errorContainer: AppColors.negativeSoft,
      onErrorContainer: AppColors.negative,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceDim: AppColors.fillSubtle,
      surfaceBright: AppColors.surface,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.fillSubtle,
      surfaceContainer: AppColors.fill,
      surfaceContainerHigh: AppColors.fill,
      surfaceContainerHighest: AppColors.fillPressed,
      onSurfaceVariant: AppColors.inkSecondary,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
      shadow: AppColors.black,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.onInk,
      inversePrimary: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      textTheme: text,
      fontFamily: AppTypography.family,

      // No ink splashes: pressed states are handled by Pressable (a scale and a
      // faint tint), which reads as touching an object rather than paint.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: const Color(0x0A000000),
      hoverColor: const Color(0x06000000),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarHeight: AppSizes.appBarHeight,
        iconTheme: const IconThemeData(color: AppColors.ink, size: AppSizes.iconMd),
        systemOverlayStyle: overlay,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onInk,
          disabledBackgroundColor: AppColors.fill,
          disabledForegroundColor: AppColors.inkDisabled,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightCompact),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightCompact),
          side: const BorderSide(color: AppColors.lineStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: text.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: text.labelLarge,
          minimumSize: const Size(0, AppSizes.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.square(AppSizes.minTouchTarget),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fill,
        hintStyle: text.bodyLarge?.copyWith(color: AppColors.inkTertiary),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.labelSmall?.copyWith(color: AppColors.inkSecondary),
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
          borderSide: BorderSide(color: Colors.transparent, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: AppColors.ink, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: AppColors.negative, width: 2),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: AppColors.negative, width: 2),
        ),
        errorStyle: text.bodySmall?.copyWith(color: AppColors.negative),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        titleTextStyle: text.headlineMedium,
        contentTextStyle: text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
        insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: AppColors.scrim,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: false,
        clipBehavior: Clip.antiAlias,
      ),

      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: AppColors.ink,
        textColor: AppColors.ink,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
        minVerticalPadding: AppSpacing.md,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.onInk),
        actionTextColor: AppColors.white,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.pageInset,
          0,
          AppSpacing.pageInset,
          AppSpacing.lg,
        ),
        elevation: 0,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.fill,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => AppColors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.lineStrong,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: AppRadius.tile,
        ),
        textStyle: text.bodySmall?.copyWith(color: AppColors.onInk),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: AppColors.shadow,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        textStyle: text.bodyLarge,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.ink,
        headerForegroundColor: AppColors.onInk,
        todayBorder: const BorderSide(color: AppColors.ink),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.ink : null,
        ),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      ),

      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppColors.surface,
        dialBackgroundColor: AppColors.fill,
        hourMinuteColor: AppColors.fill,
        hourMinuteTextColor: AppColors.ink,
        dialHandColor: AppColors.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SlideTransitions(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Screens slide in from the right with the outgoing page easing back a little,
/// the way native mobility apps move between steps of a flow.
class _SlideTransitions extends PageTransitionsBuilder {
  const _SlideTransitions();

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
      curve: AppMotion.decelerate,
      reverseCurve: AppMotion.exit,
    );
    final behind = CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.standard);

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(-0.25, 0), end: Offset.zero)
          .animate(ReverseAnimation(behind)),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(enter),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 24)],
          ),
          child: child,
        ),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompactWidth => AppBreakpoints.isCompact(screenWidth);

  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}
