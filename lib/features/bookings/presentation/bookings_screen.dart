// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY
//
// Every booking, by where it is in its life: upcoming, active, past, cancelled.
// Live bookings are cards with their next action on them; finished ones are a
// quiet list you can rebook from. Counts and states are the server's.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/directions.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import 'cancel_booking_sheet.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  /// The filter picked by the customer, or followed to after a booking moved.
  BookingBucket? _bucket;

  /// What was on screen at the last build, and whether the tab was in view.
  BookingBucket? _shown;
  bool _inView = true;

  static const _labels = {
    BookingBucket.upcoming: 'Upcoming',
    BookingBucket.active: 'Active',
    BookingBucket.completed: 'Past',
    BookingBucket.cancelled: 'Cancelled',
  };

  BookingBucket _defaultBucket(BookingCounts? counts) {
    if (counts == null) return BookingBucket.upcoming;
    if (counts.active > 0) return BookingBucket.active;
    if (counts.upcoming > 0) return BookingBucket.upcoming;
    if (counts.completed > 0) return BookingBucket.completed;
    return BookingBucket.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final countsValue = ref.watch(bookingCountsProvider);
    final counts = countsValue.valueOrNull;

    // Bookings move between filters — made, parked, finished, cancelled.
    //  · Out of view (booked from Home, cancelled on the booking's own page),
    //    follow the booking: open on the one filter that gained. A filter left
    //    from an earlier visit otherwise hid the booking just made.
    //  · In view, nothing jumps: cancelling from Upcoming used to throw the
    //    customer onto Past. The chip counts show where things went.
    // Inactive tabs and screens under a full-screen route have tickers off.
    _inView = TickerMode.of(context);
    ref.listen(bookingCountsProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (before == null || after == null || _inView) return;
      final gained = [
        for (final b in BookingBucket.values)
          if (after.forBucket(b) > before.forBucket(b)) b,
      ];
      if (gained.length == 1) setState(() => _bucket = gained.single);
    });

    final bucket = _bucket ?? (_inView ? _shown : null) ?? _defaultBucket(counts);
    // Before the counts arrive the default is a placeholder; only a filter
    // chosen from real counts may hold its place.
    _shown = counts == null ? null : bucket;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.ink,
        onRefresh: () async {
          ref.invalidate(bookingCountsProvider);
          ref.invalidate(bookingListProvider(bucket));
          await ref.read(bookingListProvider(bucket).future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageInset,
                    AppSpacing.xl,
                    AppSpacing.pageInset,
                    AppSpacing.lg,
                  ),
                  child: Text('Activity', style: context.text.displayMedium),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppSizes.chipHeight,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
                  children: [
                    for (final b in BookingBucket.values) ...[
                      AppFilterChip(
                        label: _labels[b]!,
                        selected: b == bucket,
                        badgeCount: counts?.forBucket(b),
                        onTap: () => setState(() => _bucket = b),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            _BucketSliver(bucket: bucket),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset + AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

class _BucketSliver extends ConsumerWidget {
  const _BucketSliver({required this.bucket});

  final BookingBucket bucket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingListProvider(bucket));
    return bookings.when(
      skipLoadingOnRefresh: true,
      loading: () => SliverList.builder(
        itemCount: 3,
        itemBuilder: (_, __) => const _RowSkeleton(),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: ErrorStateView(
          error: asApiException(error),
          onRetry: () => ref.invalidate(bookingListProvider(bucket)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return SliverToBoxAdapter(child: _EmptyBucket(bucket: bucket));
        final live = bucket == BookingBucket.upcoming || bucket == BookingBucket.active;
        if (live) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (_, i) => LiveBookingCard(booking: items[i]),
            ),
          );
        }
        return SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Hairline(indent: 88, endIndent: AppSpacing.pageInset),
          itemBuilder: (_, i) => _PastBookingRow(booking: items[i]),
        );
      },
    );
  }
}

/* ── shared status vocabulary ──────────────────────────────────────────────── */

BadgeTone bookingStatusTone(BookingStatus status) {
  switch (status) {
    case BookingStatus.pendingPayment:
      return BadgeTone.warning;
    case BookingStatus.confirmed:
      return BadgeTone.positive;
    case BookingStatus.checkedIn:
      return BadgeTone.dark;
    case BookingStatus.completed:
      return BadgeTone.neutral;
    case BookingStatus.cancelled:
    case BookingStatus.expired:
    case BookingStatus.unknown:
      return BadgeTone.neutral;
    case BookingStatus.noShow:
      return BadgeTone.negative;
  }
}

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final label = booking.status == BookingStatus.checkedIn
        ? 'Parked'
        : (booking.statusLabel.isEmpty ? booking.status.name : booking.statusLabel);
    return StatusBadge(
      label: label,
      tone: bookingStatusTone(booking.status),
      dot: booking.status == BookingStatus.checkedIn || booking.status == BookingStatus.confirmed,
    );
  }
}

String bookingWhenLabel(Booking booking) {
  // A finished session is described by when the car was actually there; the
  // booked window only matters while it is still ahead.
  final actualIn = booking.checkedInAt;
  final actualOut = booking.checkedOutAt;
  final entry = actualIn != null && actualOut != null ? actualIn : booking.window.entryTime;
  if (entry == null) return booking.window.durationLabel;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(entry.year, entry.month, entry.day);
  final diff = day.difference(today).inDays;
  final dayLabel = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => DateFormat(entry.year == now.year ? 'EEE d MMM' : 'd MMM yyyy').format(entry),
  };
  final exit = actualIn != null && actualOut != null ? actualOut : booking.window.expectedExitTime;
  final range = exit == null
      ? DateFormat('h:mm a').format(entry)
      : '${DateFormat('h:mm a').format(entry)} – ${DateFormat('h:mm a').format(exit)}';
  return '$dayLabel, $range';
}

/* ── live card ─────────────────────────────────────────────────────────────── */

class LiveBookingCard extends ConsumerStatefulWidget {
  const LiveBookingCard({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<LiveBookingCard> createState() => _LiveBookingCardState();
}

class _LiveBookingCardState extends ConsumerState<LiveBookingCard> {
  bool _checkingIn = false;

  Future<void> _checkIn() async {
    setState(() => _checkingIn = true);
    try {
      await ref.read(bookingActionsProvider).checkIn(widget.booking.id);
      if (mounted) showToast(context, 'Checked in. Enjoy your stay.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final actions = <Widget>[
      if (booking.actions.canPay)
        PillButton(
          label: 'Complete payment',
          icon: Icons.lock_outline_rounded,
          inverted: true,
          onPressed: () => context.push(Routes.bookingDetail(booking.id)),
        ),
      if (booking.actions.canCheckIn)
        PillButton(
          label: 'Check in',
          icon: Icons.login_rounded,
          inverted: true,
          isLoading: _checkingIn,
          onPressed: _checkIn,
        ),
      if (booking.isParked)
        PillButton(
          label: 'View session',
          icon: Icons.timer_outlined,
          inverted: true,
          onPressed: () => context.push(Routes.active),
        ),
      if (booking.parking.position != null &&
          (booking.status == BookingStatus.confirmed || booking.isParked))
        PillButton(
          label: 'Directions',
          icon: Icons.near_me_rounded,
          onPressed: () =>
              openDirectionsTo(context, booking.parking.position!, booking.parking.name),
        ),
      if (booking.actions.isCancellable && !booking.actions.canPay)
        PillButton(
          label: 'Cancel',
          onPressed: () => showCancelBookingSheet(context, ref, booking),
        ),
    ];

    return Pressable(
      onTap: () => context.push(Routes.bookingDetail(booking.id)),
      depth: PressDepth.subtle,
      borderRadius: AppRadius.card,
      child: AppSurface(
        level: SurfaceLevel.outlined,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // One sentence for the summary. Composing the label on the whole card
            // hid the pills below from screen readers — "Complete payment" and
            // "Check in" could not be reached at all.
            Semantics(
              label:
                  '${booking.parking.name}, ${bookingWhenLabel(booking)}, ${booking.statusLabel}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParqxPhoto(
                    url: booking.parking.coverPhotoUrl,
                    seed: booking.parking.name,
                    width: 56,
                    height: 56,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                booking.parking.name,
                                style: context.text.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            BookingStatusBadge(booking: booking),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(bookingWhenLabel(booking), style: context.text.bodyMedium),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (booking.slot != null) 'Spot ${booking.slot!.code}',
                            if (booking.vehicle.displayPlate != null) booking.vehicle.displayPlate!,
                          ].join('  ·  '),
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/* ── past row ──────────────────────────────────────────────────────────────── */

class _PastBookingRow extends StatelessWidget {
  const _PastBookingRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final finished = booking.status == BookingStatus.completed;
    final amount = booking.amount.payable;
    return Pressable(
      onTap: () => context.push(Routes.bookingDetail(booking.id)),
      depth: PressDepth.subtle,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset, vertical: AppSpacing.md),
        child: Row(
          children: [
            ParqxPhoto(
              url: booking.parking.coverPhotoUrl,
              seed: booking.parking.name,
              width: 56,
              height: 56,
              dimmed: !finished,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              // The label sits on the summary so "Rebook" stays its own button.
              child: Semantics(
                label:
                    '${booking.parking.name}, ${bookingWhenLabel(booking)}, ${booking.statusLabel}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.parking.name,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(bookingWhenLabel(booking), style: context.text.bodyMedium, maxLines: 1),
                    const SizedBox(height: 2),
                    Text(
                      finished
                          ? amount.display
                          : [
                              booking.statusLabel,
                              if (booking.amount.hasRefund)
                                'Refunded ${booking.amount.refunded.display}',
                            ].join('  ·  '),
                      style: finished
                          ? AppTypography.numeric(size: 14, weight: FontWeight.w600)
                          : context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            if (finished) ...[
              const SizedBox(width: AppSpacing.sm),
              PillButton(
                label: 'Rebook',
                icon: Icons.refresh_rounded,
                onPressed: () => context.push(Routes.parkingDetail(booking.parking.id)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyBucket extends StatelessWidget {
  const _EmptyBucket({required this.bucket});

  final BookingBucket bucket;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (bucket) {
      BookingBucket.upcoming => (
          'No upcoming parking',
          'Book a spot and it shows up here with your entry code and directions.',
          Icons.event_available_outlined,
        ),
      BookingBucket.active => (
          "You're not parked right now",
          'When you check in, your live session — time and cost — appears here.',
          Icons.local_parking_rounded,
        ),
      BookingBucket.completed => (
          'No past parking yet',
          'Finished sessions and their receipts are kept here.',
          Icons.receipt_long_outlined,
        ),
      BookingBucket.cancelled => (
          'Nothing cancelled',
          'Cancelled and expired bookings are kept here for your records.',
          Icons.event_busy_outlined,
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: EmptyStateView(
        title: title,
        message: message,
        icon: icon,
        action: bucket == BookingBucket.upcoming || bucket == BookingBucket.active
            ? PrimaryButton(
                label: 'Find parking',
                expand: false,
                onPressed: () => context.go(Routes.home),
              )
            : null,
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageInset, vertical: AppSpacing.md),
      child: Row(
        children: [
          LoadingSkeleton(width: 56, height: 56, borderRadius: AppRadius.photo),
          SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton.text(width: 160, height: 15),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton.text(width: 120, height: 12),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton.text(width: 60, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
