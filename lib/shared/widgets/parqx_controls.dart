// ─────────────────────────────────────────────────────────────────────────────
// PARQX CONTROLS — the floating chrome over the map
//
// Search, the vehicle switch, the discovery filters and the circular map
// controls. All of them sit on the dark ground, all of them float, and all of
// them are built here so they cannot drift apart.
//
// The ordering is deliberate and states the product's priorities: search is the
// widest and tallest control on the screen; the vehicle switch comes next
// because it changes the MEANING of every price and count below it; the
// discovery filters come last because they only narrow a list.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'interaction.dart';

/// The hero search control.
///
/// A tap target, not a text field: typing happens on the search screen, which
/// can show recent searches and suggestions. A live `TextField` here would put
/// the keyboard over the map the moment it was focused.
class ParqxSearchBar extends StatelessWidget {
  const ParqxSearchBar({
    super.key,
    required this.onTap,
    this.hint = 'Where are you parking?',
    this.onVoice,
  });

  final VoidCallback onTap;
  final String hint;

  /// Rendered only when voice search is actually wired. A microphone that does
  /// nothing is worse than no microphone.
  final VoidCallback? onVoice;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: PressDepth.subtle,
      borderRadius: AppRadius.chip,
      semanticLabel: 'Search for a place to park',
      tint: false,
      child: Container(
        height: AppSizes.heroFieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltDark,
          borderRadius: AppRadius.chip,
          border: Border.all(color: AppColors.borderDark),
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: AppSizes.iconMd, color: AppColors.inkSecondaryDark),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                hint,
                style: context.text.bodyLarge?.copyWith(
                  color: AppColors.inkMutedDark,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onVoice != null) ...[
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: AppColors.borderDark,
              ),
              Icon(Icons.mic_none_rounded,
                  size: AppSizes.iconMd, color: AppColors.inkSecondaryDark),
            ],
          ],
        ),
      ),
    );
  }
}

/// A two-position segmented switch with a sliding thumb.
///
/// The thumb slides rather than cutting because the movement is what tells the
/// user the two options are ONE setting — two independently-highlighting chips
/// read as two separate toggles that happen to be adjacent.
class ParqxSegmented<T> extends StatelessWidget {
  const ParqxSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.height = 44,
    this.segmentWidth = 86,
    this.onDark = true,
  });

  final T value;
  final List<ParqxSegment<T>> options;
  final ValueChanged<T> onChanged;
  final double height;
  final double segmentWidth;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final index = options.indexWhere((o) => o.value == value).clamp(0, options.length - 1);
    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      label: 'Vehicle type',
      value: options[index].label,
      child: Container(
        height: height,
        width: segmentWidth * options.length,
        decoration: BoxDecoration(
          color: onDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
          borderRadius: radius,
          border: Border.all(
            color: onDark ? AppColors.borderDark : AppColors.border,
            // Drawn OUTSIDE the box. A default (inside) border subtracts its
            // width from the content box, so the Row of N x segmentWidth
            // children overflowed the container by exactly 2px — one pixel per
            // side. Measured on device as "RenderFlex overflowed by 2.0 pixels".
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: AppMotion.quick,
              curve: AppMotion.spring,
              alignment: Alignment(
                options.length == 1 ? 0 : (index / (options.length - 1)) * 2 - 1,
                0,
              ),
              child: Container(
                width: segmentWidth - 8,
                height: height - 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: radius,
                  boxShadow: AppShadows.brandLift,
                ),
              ),
            ),
            Row(
              children: [
                for (final option in options)
                  SizedBox(
                    width: segmentWidth,
                    child: Pressable(
                      onTap: () => onChanged(option.value),
                      feedback: PressFeedback.selection,
                      depth: PressDepth.firm,
                      tint: false,
                      borderRadius: radius,
                      semanticLabel: option.label,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option.icon,
                              size: AppSizes.iconSm,
                              color: option.value == value
                                  ? AppColors.onBrand
                                  : (onDark
                                      ? AppColors.inkSecondaryDark
                                      : AppColors.inkSecondary),
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Text(
                              option.label,
                              style: context.text.labelMedium?.copyWith(
                                color: option.value == value
                                    ? AppColors.onBrand
                                    : (onDark
                                        ? AppColors.inkSecondaryDark
                                        : AppColors.inkSecondary),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ParqxSegment<T> {
  const ParqxSegment({required this.value, required this.label, required this.icon});
  final T value;
  final String label;
  final IconData icon;
}

/// A discovery filter — "Near me", "Cheapest".
///
/// Distinct from the vehicle switch on purpose: these narrow or reorder a list,
/// where the switch changes what every number on the screen means.
class ParqxFilterPill extends StatelessWidget {
  const ParqxFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onBrand : AppColors.inkSecondaryDark;

    return Pressable(
      onTap: onTap,
      feedback: PressFeedback.selection,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: AppRadius.chip,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.standard,
        height: AppSizes.chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surfaceAltDark,
          borderRadius: AppRadius.chip,
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.borderDark,
          ),
          boxShadow: selected ? AppShadows.brandLift : AppShadows.none,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconXs + 1, color: fg),
              const SizedBox(width: AppSpacing.sm - 2),
            ],
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

/// A circular control: the filter sheet trigger, recentre, map layers.
class ParqxRoundControl extends StatelessWidget {
  const ParqxRoundControl({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.badge = false,
    this.size,
    this.onDark = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  /// A dot rather than a count: the exact number of active filters is on the
  /// sheet, and a two-digit badge on a 48px circle is unreadable anyway.
  final bool badge;

  final double? size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? AppSizes.mapControl;

    return Pressable(
      onTap: onTap,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: BorderRadius.circular(dimension),
      semanticLabel: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: dimension,
            height: dimension,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.brand
                  : (onDark ? AppColors.surfaceAltDark : AppColors.surface),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? Colors.transparent
                    : (onDark ? AppColors.borderDark : AppColors.border),
              ),
              boxShadow: active ? AppShadows.brandLift : AppShadows.floating,
            ),
            child: Icon(
              icon,
              size: AppSizes.iconMd,
              color: active
                  ? AppColors.onBrand
                  : (onDark ? AppColors.inkDark : AppColors.ink),
            ),
          ),
          if (badge)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.brandBright,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: onDark ? AppColors.canvas : AppColors.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small status line — "Showing parking near you".
class ParqxStatusLine extends StatelessWidget {
  const ParqxStatusLine({
    super.key,
    required this.label,
    this.colour = AppColors.successBright,
    this.icon,
  });

  final String label;
  final Color colour;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: AppSizes.iconXs, color: colour)
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(color: AppColors.inkSecondaryDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A small solid label — "11 slots available", "Open 24/7", "Default".
class ParqxBadge extends StatelessWidget {
  const ParqxBadge({
    super.key,
    required this.label,
    this.icon,
    this.colour = AppColors.brand,
    this.onDark = false,
    this.solid = false,
  });

  final String label;
  final IconData? icon;
  final Color colour;
  final bool onDark;

  /// Filled with [colour] and reversed out, rather than tinted.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? AppColors.white : colour;
    final bg = solid
        ? colour
        : colour.withValues(alpha: onDark ? 0.18 : 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconXs, color: fg),
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Text(
            label,
            style: AppTypography.numeric(
              size: 12,
              weight: FontWeight.w700,
              color: fg,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
