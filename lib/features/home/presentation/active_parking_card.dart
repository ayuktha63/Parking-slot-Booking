// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE PARKING — HOME CARD
//
// When something is happening, it is the first thing on Home.
//
// Three states, each a different thing the customer needs:
//   parked      → elapsed time, slot, check-out
//   arriving    → when and where, check in
//   unpaid      → the booking is not confirmed and will lapse
//
// Nothing renders when there is no active booking: an empty placeholder saying "no
// active parking" would occupy the most valuable space on the screen to say nothing.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/booking.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/live_duration.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/states.dart';
import '../../bookings/presentation/bookings_screen.dart' show openDirections;

class ActiveParkingCard extends ConsumerWidget {
  const ActiveParkingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentBookingProvider);

    return current.when(
      // A brief skeleton rather than a jump: the card appearing after the list has
      // already laid out is more jarring than a placeholder of the right height.
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageInset,
          AppSpacing.sm,
          AppSpacing.pageInset,
          AppSpacing.sm,
        ),
        child: LoadingSkeleton(height: 96),
      ),
      // A failure to load the active session must not break Home. The Bookings tab
      // is still there and will show the error properly.
      error: (_, __) => const SizedBox.shrink(),
      data: (booking) {
        if (booking == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.sm,
            AppSpacing.pageInset,
            AppSpacing.sm,
          ),
          child: _Card(booking: booking),
        );
      },
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parked = booking.isParked;
    final unpaid = booking.status == BookingStatus.pendingPayment;

    // ── the three states, and why they look different ───────────────────
    //
    // These were three colour swaps on one layout. They are three different
    // situations and the card should feel like three different things:
    //
    //   parked  — a LIVE session. Deep violet-black, the same ink as the map, a
    //             pulsing live dot, and the running clock as the largest object
    //             on the card. This is a status display, not a summary.
    //   upcoming— a promise. Jade, calmer, the time is the headline.
    //   unpaid  — unfinished business. Amber, and it says so plainly; this is
    //             the one state that is asking for something.
    final (List<Color> gradient, Color accent, String kicker, IconData icon) = unpaid
        ? (
            const [Color(0xFF4A2E08), Color(0xFF2E1C04)],
            const Color(0xFFE8A33D),
            'PAYMENT NOT COMPLETED',
            Icons.hourglass_top_rounded,
          )
        : parked
            ? (
                const [Color(0xFF241350), Color(0xFF150B30)],
                AppColors.brandMuted,
                'PARKED NOW',
                Icons.local_parking_rounded,
              )
            : (
                const [Color(0xFF06372A), Color(0xFF032019)],
                AppColors.successBright,
                'UPCOMING',
                Icons.event_available_rounded,
              );

    return Pressable(
      onTap: () => context.push(Routes.bookingDetail(booking.id)),
      borderRadius: AppRadius.cardLarge,
      tint: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: AppRadius.cardLarge,
          boxShadow: AppShadows.lg,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // A live dot only while a session is genuinely running. It is a
                // factual claim about a socket subscription, not decoration.
                if (parked)
                  LivePulse(color: accent, size: 7)
                else
                  Icon(icon, size: AppSizes.iconSm, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  kicker,
                  style: AppTypography.overline(color: accent),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.onMapMuted, size: AppSizes.iconMd),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Text(
              booking.parking.name,
              style: context.text.titleLarge?.copyWith(color: AppColors.onMap),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),
            Text(
              _subtitle(),
              style: context.text.bodySmall?.copyWith(color: AppColors.onMapMuted),
            ),

            // While parked, the elapsed time runs. A static "1h 24m elapsed"
            // that only moved when a provider refetched made the one screen
            // that most needs to feel live feel frozen. `checkedInAt` is the
            // server's own timestamp; only the rendering of it is local.
            if (parked && booking.checkedInAt != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _LiveSessionStrip(booking: booking),
            ],

            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _actionFor(context, ref)),
                if (booking.parking.hasCoordinates && !unpaid) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _GhostButton(
                    label: 'Directions',
                    icon: Icons.navigation_rounded,
                    onPressed: () => openDirections(context, booking),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    if (booking.status == BookingStatus.pendingPayment) {
      return 'Slot ${booking.slot?.code ?? '—'} · complete payment to confirm';
    }

    if (booking.isParked) {
      // Durations are no longer repeated here: the live strip below renders them,
      // ticking, and saying the same thing twice in two granularities invites the
      // two to disagree on screen.
      final slot = booking.slot?.code ?? '—';
      final session = booking.session;
      if (session != null && session.isOverstaying) {
        return 'Slot $slot · over your booked time';
      }
      return 'Slot $slot';
    }

    final entry = booking.window.entryTime;
    if (entry == null) return 'Slot ${booking.slot?.code ?? '—'}';

    final minutes = booking.window.minutesUntilEntry;
    final when = minutes != null && minutes >= 0 && minutes <= 90
        ? 'in ${_minutes(minutes)}'
        : DateFormat('EEE d MMM, h:mm a').format(entry);

    return 'Slot ${booking.slot?.code ?? '—'} · $when';
  }

  /// The single most useful action for this state.
  Widget _actionFor(BuildContext context, WidgetRef ref) {
    if (booking.status == BookingStatus.pendingPayment) {
      return _GhostButton(
        label: 'Complete payment',
        icon: Icons.lock_rounded,
        filled: true,
        onPressed: () => context.push(Routes.bookingDetail(booking.id)),
      );
    }

    if (booking.actions.canCheckOut) {
      return _GhostButton(
        label: 'Check out',
        icon: Icons.logout_rounded,
        filled: true,
        onPressed: () => context.push(Routes.bookingDetail(booking.id)),
      );
    }

    if (booking.actions.canCheckIn) {
      return _GhostButton(
        label: 'Check in',
        icon: Icons.login_rounded,
        filled: true,
        onPressed: () => context.push(Routes.bookingDetail(booking.id)),
      );
    }

    return _GhostButton(
      label: 'View booking',
      icon: Icons.receipt_long_outlined,
      filled: true,
      onPressed: () => context.push(Routes.bookingDetail(booking.id)),
    );
  }

  static String _minutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

/// A button that reads correctly on a coloured surface, where the themed buttons
/// would fight the gradient behind them.
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    // IntrinsicWidth: a real crash, found only by actually running the app —
    // "BoxConstraints forces an infinite width" on this exact button, thrown
    // during performLayout(). It never surfaced before because every prior
    // state this session exercised (pending-payment, no active booking) hid
    // the Directions button (`!unpaid` below), leaving this the Row's ONLY
    // child and its own Expanded-wrapped sibling absent — nothing there to
    // reveal that this un-flexed child was receiving an unbounded width. The
    // moment a real CONFIRMED, paid, located booking put both buttons in the
    // Row side by side, it threw — a rendering exception, so it isn't caught
    // by the FutureProvider's `error` branch above; it silently blanked the
    // whole card instead. IntrinsicWidth makes this button report its own
    // natural width instead of trying to fill unbounded space, which is safe
    // here regardless of the exact upstream constraint source.
    return IntrinsicWidth(
      child: SizedBox(
        height: AppSizes.buttonHeightCompact,
        child: filled
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: AppSizes.iconSm),
                label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.onBrand,
                  foregroundColor: AppColors.brandStrong,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: AppSizes.iconSm),
                label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onBrand,
                  side: BorderSide(color: AppColors.onBrand.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
              ),
      ),
    );
  }
}

/// The running session: elapsed clock, time left, and what it costs so far.
///
/// Every value here is the server's. `checkedInAt` drives the clock,
/// `session.projectedTotal` is the server's own estimate from the same function
/// that settles the bill — this widget computes no money.
class _LiveSessionStrip extends StatelessWidget {
  const _LiveSessionStrip({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final session = booking.session;
    final overstaying = session?.isOverstaying == true;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.onBrand.withValues(alpha: 0.16),
        borderRadius: AppRadius.field,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  overstaying ? 'OVER TIME' : 'PARKED FOR',
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.onBrand.withValues(alpha: 0.85),
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                LiveDuration(
                  since: booking.checkedInAt!,
                  style: AppTypography.numeric(size: 26, weight: FontWeight.w800)
                      .copyWith(color: AppColors.onBrand),
                ),
              ],
            ),
          ),
          // The server's estimate, shown only when the server sent one. A locally
          // guessed running total would be a number the bill then contradicts.
          if (session?.projectedTotal != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ESTIMATE',
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.onBrand.withValues(alpha: 0.85),
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session!.projectedTotal!.display,
                  style: AppTypography.numeric(size: 26, weight: FontWeight.w800)
                      .copyWith(color: AppColors.onBrand),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
