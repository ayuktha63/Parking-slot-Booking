// ─────────────────────────────────────────────────────────────────────────────
// HOLD COUNTDOWN
//
// The visible promise that a slot is genuinely reserved.
//
// The number shown is recomputed every second from the server's `expires_at`, not
// decremented locally — see HoldController. This widget only renders it.
//
// It changes character as it runs down: calm while there is time, urgent under
// thirty seconds. That escalation is the whole reason a countdown is worth showing
// rather than just saying "your slot is held".
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/providers/booking_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

class HoldCountdownBar extends StatelessWidget {
  const HoldCountdownBar({
    super.key,
    required this.state,
    this.onExtend,
    this.showSlot = true,
  });

  final HoldState state;

  /// Null when the hold cannot be extended again — the button is then absent
  /// rather than present and inert.
  final VoidCallback? onExtend;

  final bool showSlot;

  @override
  Widget build(BuildContext context) {
    final hold = state.hold;
    if (hold == null) return const SizedBox.shrink();

    final urgent = state.isExpiring;
    final background = urgent ? AppColors.dangerSoft : AppColors.brandSoft;
    final foreground = urgent ? AppColors.danger : AppColors.brandStrong;

    return AnimatedContainer(
      duration: AppMotion.quick,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageInset,
        vertical: AppSpacing.md,
      ),
      color: background,
      child: Semantics(
        liveRegion: true,
        label: 'Slot ${hold.slot.code} held, ${_spoken(state.secondsRemaining)} remaining',
        child: Row(
          children: [
            Icon(
              urgent ? Icons.timer_outlined : Icons.lock_clock_rounded,
              size: AppSizes.iconMd,
              color: foreground,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    showSlot ? 'Slot ${hold.slot.code} is held for you' : 'Slot held for you',
                    style: context.text.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    urgent
                        ? 'Releasing soon — complete your booking'
                        : 'Nobody else can book it while the timer runs',
                    style: context.text.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Tabular figures so the digits do not jitter as the seconds change.
            Text(
              state.countdownLabel,
              style: context.text.titleMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            if (onExtend != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: state.isWorking ? null : onExtend,
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(0, AppSizes.minTouchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                child: const Text('+2 min'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Screen readers should hear "1 minute 58 seconds", not "one colon fifty-eight".
  static String _spoken(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s seconds';
    return '$m minute${m == 1 ? '' : 's'} $s seconds';
  }
}

/// The same countdown as a compact pill, for screens where the full bar is too
/// heavy — the review screen's app bar, for instance.
class HoldCountdownPill extends StatelessWidget {
  const HoldCountdownPill({super.key, required this.state});

  final HoldState state;

  @override
  Widget build(BuildContext context) {
    if (!state.hasHold) return const SizedBox.shrink();

    final urgent = state.isExpiring;
    final colour = urgent ? AppColors.danger : AppColors.brandStrong;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: urgent ? AppColors.dangerSoft : AppColors.brandSoft,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: AppSizes.iconXs, color: colour),
          const SizedBox(width: AppSpacing.xs),
          Text(
            state.countdownLabel,
            style: context.text.labelMedium?.copyWith(
              color: colour,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
