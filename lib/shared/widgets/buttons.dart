// ─────────────────────────────────────────────────────────────────────────────
// BUTTONS
//
// Three levels, and the levels are the point.
//
// ─────────────────────────────────────────────────────────────────────────────
// THE HIERARCHY
//
//   PrimaryButton    filled brand, lit by its own shadow.  ONE per screen.
//   SecondaryButton  filled tonal — a quiet surface, ink label.  No outline.
//   TertiaryButton   text only.
//
// The old set was filled / OUTLINED / text. Outlined is a poor middle term: it
// has the same footprint and visual weight as the primary button, differing only
// in fill, so a screen with both showed two equally-sized rectangles competing
// for the same attention. It also added yet another 1px box to a UI that already
// outlined its cards, chips, fields and banners.
//
// Filled-tonal solves both. It is unmistakably subordinate to the brand fill,
// and it separates from the page by surface step rather than by yet another
// border.
//
// ─────────────────────────────────────────────────────────────────────────────
// WHY THESE ARE NOT MATERIAL BUTTONS ANY MORE
//
// `AppTheme` switches the ink ripple off globally (it is the single most
// recognisable Material gesture, and this product wants its own). A
// `FilledButton` with no ripple has NO press feedback at all, which is worse
// than the ripple it replaced.
//
// These are built on `Pressable` instead, so a button compresses and springs
// back exactly like every card, chip and tile in the app — one interaction model
// everywhere. `Pressable` emits `Semantics(button:, enabled:)` itself, so screen
// readers and the accessibility tree see a real button.
//
// LOADING is built in, because it is the thing screens forget: the old app left
// buttons live during a request, so double-taps produced duplicate bookings.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'interaction.dart';

enum AppButtonSize { regular, compact }

/// What a filled button MEANS, which decides its colour.
///
/// Colour on a primary action is not decoration — it is the product telling the
/// user what kind of thing is about to happen. Three meanings, three fills:
///
///   brand      the ordinary next step, and anything involving money.
///   complete   a successful conclusion — checking out of a session you paid
///              for. Deliberately not brand (that reads as "pay") and
///              deliberately not danger (that reads as "you are about to lose
///              something").
///   danger     destructive and hard to undo — cancelling, removing.
enum ButtonTone { brand, complete, danger }

/// Filled brand. The single most important action on a screen.
///
/// If a screen has two of these, one of them is not the most important action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.size = AppButtonSize.regular,
    this.danger = false,
    this.tone = ButtonTone.brand,
    this.feedback = PressFeedback.none,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final AppButtonSize size;

  /// For destructive actions — cancelling a booking, removing a vehicle.
  ///
  /// Retained for the many call sites that use it; equivalent to
  /// `tone: ButtonTone.danger`.
  final bool danger;

  /// What this action means. See [ButtonTone].
  final ButtonTone tone;

  /// Most primary buttons commit something, but the haptic belongs to the
  /// SERVER's answer, not to the tap. Screens that confirm optimistically pass
  /// this; screens that wait for a response fire `Haptics.success()` themselves.
  final PressFeedback feedback;

  @override
  Widget build(BuildContext context) {
    // A loading button is disabled, so a double-tap cannot fire twice.
    final enabled = onPressed != null && !isLoading;
    final effectiveTone = danger ? ButtonTone.danger : tone;
    final background = switch (effectiveTone) {
      ButtonTone.brand => AppColors.brand,
      ButtonTone.complete => AppColors.success,
      ButtonTone.danger => AppColors.danger,
    };

    return _ButtonShell(
      onPressed: enabled ? onPressed : null,
      feedback: feedback,
      expand: expand,
      size: size,
      semanticLabel: label,
      background: enabled ? background : AppColors.surfaceAlt,
      foreground: enabled ? AppColors.onBrand : AppColors.inkMuted,
      // Only an enabled primary glows. A disabled one that still throws brand
      // light looks available and is not.
      // Only the brand action glows. A glowing green or red would put two lit
      // controls on one screen, and then neither is the primary.
      shadow: enabled && effectiveTone == ButtonTone.brand
          ? AppShadows.brandLift
          : AppShadows.none,
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        foreground: enabled ? AppColors.onBrand : AppColors.inkMuted,
      ),
    );
  }
}

/// Filled tonal. The alternative beside a primary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.size = AppButtonSize.regular,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final AppButtonSize size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final foreground = enabled ? context.colors.onSurface : AppColors.inkMuted;

    return _ButtonShell(
      onPressed: enabled ? onPressed : null,
      expand: expand,
      size: size,
      semanticLabel: label,
      background: context.colors.surfaceContainer,
      foreground: foreground,
      shadow: AppShadows.none,
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        foreground: foreground,
      ),
    );
  }
}

/// Text only, for tertiary actions.
class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colour = onPressed == null
        ? AppColors.inkMuted
        : danger
            ? AppColors.danger
            : context.colors.primary;

    return Pressable(
      onTap: onPressed,
      depth: PressDepth.firm,
      borderRadius: AppRadius.button,
      semanticLabel: label,
      tint: false,
      child: Container(
        height: AppSizes.minTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconSm, color: colour),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                style: context.text.labelLarge?.copyWith(color: colour),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared geometry and press behaviour for the filled variants.
class _ButtonShell extends StatelessWidget {
  const _ButtonShell({
    required this.child,
    required this.onPressed,
    required this.expand,
    required this.size,
    required this.background,
    required this.foreground,
    required this.shadow,
    required this.semanticLabel,
    this.feedback = PressFeedback.none,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool expand;
  final AppButtonSize size;
  final Color background;
  final Color foreground;
  final List<BoxShadow> shadow;
  final String semanticLabel;
  final PressFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final height =
        size == AppButtonSize.compact ? AppSizes.buttonHeightCompact : AppSizes.buttonHeight;

    final button = Pressable(
      onTap: onPressed,
      feedback: feedback,
      // Full-width controls take the gentlest squeeze: the same ratio that reads
      // as a firm press on a chip looks like the whole screen flinching here.
      depth: expand ? PressDepth.subtle : PressDepth.standard,
      borderRadius: AppRadius.button,
      semanticLabel: semanticLabel,
      tint: false,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.standard,
        height: height,
        padding: EdgeInsets.symmetric(horizontal: expand ? AppSpacing.lg : AppSpacing.xl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.button,
          boxShadow: shadow,
        ),
        child: DefaultTextStyle.merge(
          style: context.text.labelLarge!.copyWith(color: foreground),
          child: IconTheme(
            data: IconThemeData(color: foreground, size: AppSizes.iconSm),
            child: child,
          ),
        ),
      ),
    );

    // `IntrinsicWidth`, not a bare return: the shell's AnimatedContainer has no
    // width of its own, so an unconstrained parent let a supposedly inline
    // button fill the screen. Seen on the Active Parking empty state, where
    // `expand: false` produced a full-width button inside a SliverFillRemaining.
    return expand
        ? SizedBox(width: double.infinity, child: button)
        : IntrinsicWidth(child: button);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.isLoading,
    required this.foreground,
    this.icon,
  });

  final String label;
  final bool isLoading;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // The spinner replaces the label IN PLACE, so the button does not resize and
    // shift the layout around it.
    if (isLoading) {
      return SizedBox(
        height: AppSizes.iconMd,
        width: AppSizes.iconMd,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground),
      );
    }

    if (icon == null) return Text(label, overflow: TextOverflow.ellipsis);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSm),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// Circular icon button that floats over content — map recentre, back over a
/// photo, a dismiss over a sheet.
class FloatingIconButton extends StatelessWidget {
  const FloatingIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.onDark = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool isActive;

  /// Over the dark map, where a white circle is correct, versus over a light
  /// page, where it needs its own surface step.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: BorderRadius.circular(AppSizes.minTouchTarget),
      semanticLabel: tooltip ?? '',
      child: Container(
        width: AppSizes.minTouchTarget,
        height: AppSizes.minTouchTarget,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.brand : context.colors.surface,
          boxShadow: isActive
              ? AppShadows.brandLift
              : onDark
                  ? AppShadows.floating
                  : AppShadows.md,
        ),
        child: Icon(
          icon,
          size: AppSizes.iconMd,
          color: isActive ? AppColors.onBrand : context.colors.onSurface,
        ),
      ),
    );
  }
}

/// Selectable chip used for quick filters and other narrowing controls.
///
/// NOT for vehicle type — that is a segmented switch on Home, because changing
/// it changes the meaning of every price and count on the screen rather than
/// merely hiding some rows.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.badgeCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Shown on the "Filters" chip when filters are active.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onBrand : context.colors.onSurfaceVariant;

    return Pressable(
      onTap: onTap,
      feedback: PressFeedback.selection,
      depth: PressDepth.firm,
      borderRadius: AppRadius.chip,
      semanticLabel: label,
      tint: false,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.standard,
        height: AppSizes.chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Selected chips fill with the brand rather than tinting and adding a
          // border. One strong state beats two weak signals stacked.
          color: selected ? AppColors.brand : context.colors.surfaceContainer,
          borderRadius: AppRadius.chip,
          boxShadow: selected ? AppShadows.sm : AppShadows.none,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconXs, color: fg),
              const SizedBox(width: AppSpacing.xs + 2),
            ],
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: AppSpacing.xs + 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? AppColors.onBrand : AppColors.brand,
                  borderRadius: AppRadius.chip,
                ),
                child: Text(
                  '$badgeCount',
                  style: context.text.labelSmall?.copyWith(
                    color: selected ? AppColors.brand : AppColors.onBrand,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
