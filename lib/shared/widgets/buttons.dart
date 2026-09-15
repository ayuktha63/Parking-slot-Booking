// ─────────────────────────────────────────────────────────────────────────────
// BUTTONS
//
//   PrimaryButton    black, full width. The one obvious next step.
//   SecondaryButton  grey fill. A real alternative, never competing with black.
//   TertiaryButton   text only. Escape hatches: "Skip", "Keep my booking".
//   PillButton       small grey pill with an icon. Row-level actions.
//   CircleButton     round icon control — white over the map, grey on a page.
//   AppFilterChip    a toggle. Grey when off, black when on.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'interaction.dart';

enum AppButtonSize { regular, compact }

enum ButtonTone { primary, danger }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
    this.size = AppButtonSize.regular,
    this.tone = ButtonTone.primary,
    this.feedback = PressFeedback.none,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool expand;
  final AppButtonSize size;
  final ButtonTone tone;
  final PressFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final background = switch (tone) {
      ButtonTone.primary => AppColors.ink,
      ButtonTone.danger => AppColors.negative,
    };
    // A loading button keeps its colour: it is busy, not unavailable.
    final fill = enabled || isLoading ? background : AppColors.fill;
    final ink = enabled || isLoading ? AppColors.onInk : AppColors.inkDisabled;

    return _ButtonShell(
      onPressed: enabled ? onPressed : null,
      feedback: feedback,
      expand: expand,
      size: size,
      semanticLabel: isLoading ? '$label, in progress' : label,
      background: fill,
      child: _ButtonContent(
        label: label,
        icon: icon,
        trailingIcon: trailingIcon,
        isLoading: isLoading,
        foreground: ink,
      ),
    );
  }
}

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
    return _ButtonShell(
      onPressed: enabled ? onPressed : null,
      expand: expand,
      size: size,
      semanticLabel: isLoading ? '$label, in progress' : label,
      background: AppColors.fill,
      child: _ButtonContent(
        label: label,
        icon: icon,
        isLoading: isLoading,
        foreground: enabled || isLoading ? AppColors.ink : AppColors.inkDisabled,
      ),
    );
  }
}

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
        ? AppColors.inkDisabled
        : danger
            ? AppColors.negative
            : AppColors.ink;
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

/// A small grey pill: "Directions", "Cancel", "Book again".
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.inverted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Black instead of grey — for the one action on a row that matters most.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final fg = !enabled && !isLoading
        ? AppColors.inkDisabled
        : inverted
            ? AppColors.onInk
            : AppColors.ink;
    return Pressable(
      onTap: enabled ? onPressed : null,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: AppRadius.chip,
      semanticLabel: label,
      child: Container(
        height: AppSizes.pillHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: inverted ? AppColors.ink : AppColors.fill,
          borderRadius: AppRadius.chip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: AppSizes.iconXs,
                height: AppSizes.iconXs,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else if (icon != null)
              Icon(icon, size: AppSizes.iconSm - 2, color: fg),
            if (isLoading || icon != null) const SizedBox(width: AppSpacing.xs + 2),
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round icon control.
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = AppSizes.mapControl,
    this.floating = false,
    this.dark = false,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  /// White with a shadow — for controls over the map or a photograph.
  final bool floating;

  /// Black — the primary round action (the "next" arrow).
  final bool dark;

  /// A small black dot: "something here is active".
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? (onPressed == null ? AppColors.fill : AppColors.ink)
        : floating
            ? AppColors.surface
            : AppColors.fill;
    final foreground = dark
        ? (onPressed == null ? AppColors.inkDisabled : AppColors.onInk)
        : AppColors.ink;
    return Pressable(
      onTap: onPressed,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: BorderRadius.circular(size),
      semanticLabel: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: AppMotion.quick,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: floating ? AppShadows.floating : AppShadows.none,
            ),
            child: Icon(icon, size: size * 0.46, color: foreground),
          ),
          if (badge)
            Positioned(
              top: size * 0.14,
              right: size * 0.14,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Back arrow as a grey circle, for screens without an app bar.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, this.floating = false, this.onPressed});

  final bool floating;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back',
      size: 44,
      floating: floating,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Back for a collapsing header: a white floating circle while the header
/// image or map is showing, a plain arrow once the bar has collapsed to white.
class CollapsingBackButton extends StatelessWidget {
  const CollapsingBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final delta = (settings?.maxExtent ?? 0) - (settings?.minExtent ?? 0);
    final collapsed = delta <= 0 ||
        (1 - ((settings!.currentExtent - settings.minExtent) / delta)).clamp(0.0, 1.0) > 0.85;
    return AnimatedSwitcher(
      duration: AppMotion.quick,
      child: collapsed
          ? IconButton(
              key: const ValueKey('plain'),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : const BackCircleButton(key: ValueKey('floating'), floating: true),
    );
  }
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.badgeCount,
    this.floating = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? badgeCount;

  /// White with a shadow, for chips laid over the map.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onInk : AppColors.ink;
    final bg = selected
        ? AppColors.ink
        : floating
            ? AppColors.surface
            : AppColors.fill;
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
        // No `alignment` here: an aligned Container grows to the width its parent
        // allows, which stretched every chip across a Wrap.
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.chip,
          boxShadow: floating && !selected ? AppShadows.floating : AppShadows.none,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconSm - 2, color: fg),
              const SizedBox(width: AppSpacing.xs + 2),
            ],
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                '$badgeCount',
                style: context.text.labelMedium?.copyWith(
                  color: selected ? AppColors.onInk : AppColors.inkTertiary,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ── internals ─────────────────────────────────────────────────────────────── */

class _ButtonShell extends StatelessWidget {
  const _ButtonShell({
    required this.child,
    required this.onPressed,
    required this.expand,
    required this.size,
    required this.background,
    required this.semanticLabel,
    this.feedback = PressFeedback.none,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool expand;
  final AppButtonSize size;
  final Color background;
  final String semanticLabel;
  final PressFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final height =
        size == AppButtonSize.compact ? AppSizes.buttonHeightCompact : AppSizes.buttonHeight;
    final button = Pressable(
      onTap: onPressed,
      feedback: feedback,
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
        decoration: BoxDecoration(color: background, borderRadius: AppRadius.button),
        child: child,
      ),
    );
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
    this.trailingIcon,
  });

  final String label;
  final bool isLoading;
  final Color foreground;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelLarge?.copyWith(color: foreground);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppSizes.iconSm + 1, color: foreground),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(trailingIcon, size: AppSizes.iconSm + 1, color: foreground),
        ],
      ],
    );
    if (!isLoading) return content;
    // The spinner takes the content's place; the content stays laid out, unseen,
    // so a button that sizes to its label does not shrink while busy.
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility.maintain(visible: false, child: content),
        SizedBox(
          height: AppSizes.iconMd,
          width: AppSizes.iconMd,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
        ),
      ],
    );
  }
}
