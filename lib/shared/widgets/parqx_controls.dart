// ─────────────────────────────────────────────────────────────────────────────
// PARQX CONTROLS
//
// The handful of product-specific controls: the search pill, the segmented
// switch, status badges and the wordmark.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'interaction.dart';

/// The "Where to?" control. Opens search; shows the current term when one is
/// applied, with a way to clear it.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.onTap,
    this.hint = 'Where do you want to park?',
    this.term,
    this.onClear,
    this.floating = false,
  });

  final VoidCallback onTap;
  final String hint;
  final String? term;
  final VoidCallback? onClear;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final hasTerm = term != null && term!.trim().isNotEmpty;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: floating ? AppColors.surface : AppColors.fill,
        borderRadius: AppRadius.chip,
        boxShadow: floating ? AppShadows.floating : AppShadows.none,
      ),
      child: Row(
        children: [
          // The field and the clear button are separate controls, so each keeps
          // its own label for accessibility services.
          Expanded(
            child: Pressable(
              onTap: onTap,
              depth: PressDepth.subtle,
              borderRadius: AppRadius.chip,
              semanticLabel: hasTerm ? 'Search: $term' : 'Search for a place to park',
              tint: false,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: AppSizes.iconMd, color: AppColors.ink),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        hasTerm ? term! : hint,
                        style: context.text.titleMedium?.copyWith(
                          color: hasTerm ? AppColors.ink : AppColors.inkSecondary,
                          fontWeight: hasTerm ? FontWeight.w600 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasTerm && onClear != null)
            Pressable(
              onTap: onClear,
              depth: PressDepth.firm,
              tint: false,
              borderRadius: AppRadius.chip,
              semanticLabel: 'Clear search',
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.inkDisabled,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.white),
                ),
              ),
            )
          else
            const SizedBox(width: AppSpacing.lg),
        ],
      ),
    );
  }
}

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A two-to-four way switch: grey track, white sliding thumb.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.height = AppSizes.chipHeight + 4,
    this.segmentWidth,
    this.semanticLabel,
  });

  final T value;
  final List<SegmentOption<T>> options;
  final ValueChanged<T> onChanged;
  final double height;

  /// Fixed width per segment; when null the control fills its parent.
  final double? segmentWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final index = options.indexWhere((o) => o.value == value).clamp(0, options.length - 1);
    return Semantics(
      label: semanticLabel,
      value: options[index].label,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = segmentWidth != null
              ? segmentWidth! * options.length
              : constraints.maxWidth;
          // The thumb lives inside the 3px track padding.
          final each = (width - 6) / options.length;
          return Container(
            width: width,
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: AppMotion.quick,
                  curve: AppMotion.spring,
                  left: each * index,
                  top: 0,
                  bottom: 0,
                  width: each,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final option in options)
                      Expanded(
                        child: Pressable(
                          onTap: () => onChanged(option.value),
                          feedback: PressFeedback.selection,
                          depth: PressDepth.firm,
                          tint: false,
                          borderRadius: BorderRadius.circular(height / 2),
                          semanticLabel: option.label,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (option.icon != null) ...[
                                  Icon(
                                    option.icon,
                                    size: AppSizes.iconSm,
                                    color: option.value == value
                                        ? AppColors.ink
                                        : AppColors.inkTertiary,
                                  ),
                                  const SizedBox(width: AppSpacing.xs + 2),
                                ],
                                Text(
                                  option.label,
                                  style: context.text.labelMedium?.copyWith(
                                    color: option.value == value
                                        ? AppColors.ink
                                        : AppColors.inkTertiary,
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
          );
        },
      ),
    );
  }
}

enum BadgeTone { neutral, positive, warning, negative, info, dark }

/// A small tinted status label: "Confirmed", "Parked", "Full".
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.dot = false,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (tone) {
      BadgeTone.neutral => (AppColors.inkSecondary, AppColors.fill),
      BadgeTone.positive => (AppColors.positive, AppColors.positiveSoft),
      BadgeTone.warning => (AppColors.warning, AppColors.warningSoft),
      BadgeTone.negative => (AppColors.negative, AppColors.negativeSoft),
      BadgeTone.info => (AppColors.accent, AppColors.accentSoft),
      BadgeTone.dark => (AppColors.onInk, AppColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone == BadgeTone.positive ? AppColors.positiveBright : fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
          ] else if (icon != null) ...[
            Icon(icon, size: AppSizes.iconXs, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The PARQX mark: a black tile with a white P beside the wordmark.
class ParqxWordmark extends StatelessWidget {
  const ParqxWordmark({super.key, this.size = 24, this.showTile = true});

  final double size;
  final bool showTile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PARQX',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTile) ...[
            Container(
              width: size * 1.25,
              height: size * 1.25,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(size * 0.32),
              ),
              alignment: Alignment.center,
              child: Text('P', style: AppTypography.wordmark(size: size * 0.82, color: AppColors.white)),
            ),
            SizedBox(width: size * 0.4),
          ],
          Text('PARQX', style: AppTypography.wordmark(size: size)),
        ],
      ),
    );
  }
}
