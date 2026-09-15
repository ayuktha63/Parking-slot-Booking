// ─────────────────────────────────────────────────────────────────────────────
// HOLD COUNTDOWN
//
// While a spot is held, a timer says so — computed from the server's expiry, not
// a local stopwatch. Calm grey while there is time; amber in the last 30 seconds.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/providers/booking_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// A full-width strip under the app bar.
class HoldCountdownBar extends StatelessWidget {
  const HoldCountdownBar({super.key, required this.state, this.onExtend});

  final HoldState state;
  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    final hold = state.hold;
    if (hold == null) return const SizedBox.shrink();
    final urgent = state.isExpiring;
    final fg = urgent ? AppColors.warning : AppColors.ink;

    return Semantics(
      liveRegion: true,
      label: 'Spot ${hold.slot.code} held for ${_spoken(state.secondsRemaining)}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageInset,
          AppSpacing.sm + 2,
          AppSpacing.sm,
          AppSpacing.sm + 2,
        ),
        color: urgent ? AppColors.warningSoft : AppColors.fillSubtle,
        child: Row(
          children: [
            Icon(Icons.lock_clock_outlined, size: AppSizes.iconSm, color: fg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                urgent
                    ? 'Spot ${hold.slot.code} is about to be released'
                    : 'Spot ${hold.slot.code} is held for you',
                style: context.text.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              state.countdownLabel,
              style: AppTypography.numeric(size: 15, weight: FontWeight.w700, color: fg),
            ),
            if (onExtend != null)
              TextButton(
                onPressed: state.isWorking ? null : onExtend,
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                child: const Text('+2 min'),
              )
            else
              const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  static String _spoken(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s seconds';
    return '$m minute${m == 1 ? '' : 's'} $s seconds';
  }
}

/// A compact timer for an app bar.
class HoldCountdownPill extends StatelessWidget {
  const HoldCountdownPill({super.key, required this.state});

  final HoldState state;

  @override
  Widget build(BuildContext context) {
    if (!state.hasHold) return const SizedBox.shrink();
    final urgent = state.isExpiring;
    final fg = urgent ? AppColors.warning : AppColors.ink;
    return Semantics(
      label: 'Spot held for ${state.countdownLabel}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: urgent ? AppColors.warningSoft : AppColors.fill,
          borderRadius: AppRadius.chip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: fg),
            const SizedBox(width: AppSpacing.xs),
            Text(
              state.countdownLabel,
              style: AppTypography.numeric(size: 14, weight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
