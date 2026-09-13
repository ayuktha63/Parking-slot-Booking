// ─────────────────────────────────────────────────────────────────────────────
// BOOKING DETAIL — and ACTIVE PARKING
//
// One screen that changes character with the booking's state, because they are the
// same object at different moments: a reservation before arrival, a live session
// while parked, a receipt afterwards.
//
// While parked it is the most important screen in the app, so the elapsed time and
// the slot are the largest things on it. Those figures come from the server, which
// recomputes them per request — a locally-started stopwatch would drift and would
// disagree with the operator's screen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import 'bookings_screen.dart' show BookingStatusChip, openDirections;
import 'cancel_booking_sheet.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(bookingDetailProvider(bookingId)),
          ),
        ],
      ),
      body: booking.when(
        loading: () => const _DetailSkeleton(),
        error: (error, _) => ErrorStateView(
          error: asApiException(error),
          onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bookingDetailProvider(bookingId));
            await ref.read(bookingDetailProvider(bookingId).future);
          },
          child: _Content(booking: data),
        ),
      ),
      bottomNavigationBar: booking.valueOrNull == null
          ? null
          : _ActionBar(booking: booking.value!),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        AppSpacing.lg,
        AppSpacing.pageInset,
        AppSpacing.xxxl,
      ),
      children: [
        // While parked, the live session dominates. Otherwise the header does.
        if (booking.isParked && booking.session != null)
          _LiveSessionCard(booking: booking, session: booking.session!)
        else
          _Header(booking: booking),

        const SizedBox(height: AppSpacing.xl),

        if (booking.status == BookingStatus.pendingPayment) ...[
          const InlineBanner(
            message: 'This booking is not confirmed until payment completes. '
                'The slot is held only for a short time.',
            tone: BannerTone.warning,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        if (booking.status == BookingStatus.confirmed ||
            booking.status == BookingStatus.pendingPayment) ...[
          _AccessCodeCard(code: booking.code),
          const SizedBox(height: AppSpacing.lg),
        ],

        _WhereAndWhen(booking: booking),
        const SizedBox(height: AppSpacing.lg),

        _MoneyCard(booking: booking),

        if (booking.refunds.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _RefundsCard(refunds: booking.refunds),
        ],

        if (booking.parking.instructions != null) ...[
          const SizedBox(height: AppSpacing.lg),
          InlineBanner(
            message: booking.parking.instructions!,
            icon: Icons.tips_and_updates_outlined,
            tone: BannerTone.info,
          ),
        ],

        if (booking.cancellationReason != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: DetailRow(
              label: 'Cancellation reason',
              value: booking.cancellationReason!,
              icon: Icons.info_outline_rounded,
            ),
          ),
        ],

        if (booking.timeline.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _Timeline(entries: booking.timeline),
        ],
      ],
    );
  }
}

/* ── live session ──────────────────────────────────────────────────────────── */

/// The dominant state while parked.
///
/// `projected charge` is deliberately absent unless the server sends one. Showing
/// a running total the client calculated would be exactly the defect the operator
/// app had, where `amount = seconds parked` billed an hour as ₹3,600.
class _LiveSessionCard extends StatelessWidget {
  const _LiveSessionCard({required this.booking, required this.session});

  final Booking booking;
  final ParkingSession session;

  @override
  Widget build(BuildContext context) {
    final overstaying = session.isOverstaying;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: overstaying
              ? [AppColors.warning, AppColors.danger]
              : [AppColors.brand, AppColors.brandStrong],
        ),
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_parking_rounded,
                  size: AppSizes.iconSm, color: AppColors.onBrand),
              const SizedBox(width: AppSpacing.sm),
              Text(
                overstaying ? 'PARKED — OVER TIME' : 'PARKED NOW',
                style: context.text.labelSmall?.copyWith(
                  color: AppColors.onBrand,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            _elapsedLabel(session.elapsedMinutes),
            style: context.text.displaySmall?.copyWith(
              color: AppColors.onBrand,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            overstaying
                ? 'Past your booked ${_elapsedLabel(session.reservedMinutes)} — '
                    'overstay charges apply'
                : '${_elapsedLabel(session.remainingMinutes)} left of '
                    '${_elapsedLabel(session.reservedMinutes)}',
            style: context.text.bodyMedium
                ?.copyWith(color: AppColors.onBrand.withValues(alpha: 0.9)),
          ),

          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: session.progress,
              minHeight: 6,
              backgroundColor: AppColors.onBrand.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(AppColors.onBrand),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _LiveFact(
                  label: 'Slot',
                  value: booking.slot?.code ?? '—',
                ),
              ),
              Expanded(
                child: _LiveFact(
                  label: 'Checked in',
                  value: booking.checkedInAt == null
                      ? '—'
                      : DateFormat('h:mm a').format(booking.checkedInAt!),
                ),
              ),
              Expanded(
                child: _LiveFact(
                  label: session.projectedTotal == null ? 'Vehicle' : 'If you leave now',
                  value: session.projectedTotal?.display ??
                      booking.vehicle.numberPlate ??
                      '—',
                ),
              ),
            ],
          ),

          if (session.overstayAmount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.onBrand.withValues(alpha: 0.18),
                borderRadius: AppRadius.field,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: AppSizes.iconSm, color: AppColors.onBrand),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Includes ${session.overstayAmount!.display} overstay so far',
                      style: context.text.bodySmall?.copyWith(color: AppColors.onBrand),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _elapsedLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _LiveFact extends StatelessWidget {
  const _LiveFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: AppColors.onBrand.withValues(alpha: 0.75),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.text.titleSmall?.copyWith(
            color: AppColors.onBrand,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/* ── blocks ────────────────────────────────────────────────────────────────── */

class _Header extends StatelessWidget {
  const _Header({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                booking.parking.name,
                style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            BookingStatusChip(booking: booking),
          ],
        ),
        if (booking.parking.addressLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            booking.parking.addressLabel!,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _AccessCodeCard extends StatelessWidget {
  const _AccessCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.brandMuted),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BOOKING CODE',
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.brandStrong,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  code,
                  style: context.text.titleLarge?.copyWith(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Show this at the entrance',
                  style: context.text.bodySmall?.copyWith(color: AppColors.brandStrong),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy booking code',
            icon: const Icon(Icons.copy_rounded, color: AppColors.brandStrong),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Booking code copied')));
            },
          ),
        ],
      ),
    );
  }
}

class _WhereAndWhen extends StatelessWidget {
  const _WhereAndWhen({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final entry = booking.window.entryTime;
    final exit = booking.window.expectedExitTime;

    return AppCard(
      child: Column(
        children: [
          if (entry != null)
            DetailRow(
              label: 'Arriving',
              value: DateFormat('EEE d MMM, h:mm a').format(entry),
              icon: Icons.login_rounded,
            ),
          if (exit != null)
            DetailRow(
              label: booking.isParked ? 'Booked until' : 'Leaving',
              value: entry != null && entry.day == exit.day
                  ? DateFormat('h:mm a').format(exit)
                  : DateFormat('EEE d MMM, h:mm a').format(exit),
              icon: Icons.logout_rounded,
            ),
          DetailRow(
            label: 'Duration',
            value: booking.window.durationLabel,
            icon: Icons.schedule_rounded,
          ),
          if (booking.slot != null)
            DetailRow(
              label: 'Slot',
              value: booking.slot!.code,
              icon: Icons.grid_view_rounded,
              emphasise: true,
            ),
          if (booking.vehicle.numberPlate != null)
            DetailRow(
              label: 'Vehicle',
              value: booking.vehicle.numberPlate!,
              icon: booking.vehicle.type.wire == 'bike'
                  ? Icons.two_wheeler_rounded
                  : Icons.directions_car_rounded,
            ),
          if (booking.checkedOutAt != null)
            DetailRow(
              label: 'Checked out',
              value: DateFormat('EEE d MMM, h:mm a').format(booking.checkedOutAt!),
              icon: Icons.exit_to_app_rounded,
            ),
        ],
      ),
    );
  }
}

/// The receipt.
///
/// Shows what was reserved, and — only once check-out has happened — what was
/// finally charged. A difference between the two is stated rather than hidden.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final amount = booking.amount;
    final overstayed =
        amount.finalAmount != null && amount.finalAmount!.paise > amount.reserved.paise;

    return AppCard(
      child: Column(
        children: [
          DetailRow(label: 'Reserved', value: amount.reserved.display),

          if (amount.finalAmount != null) ...[
            if (overstayed)
              DetailRow(
                label: 'Overstay',
                value: (amount.finalAmount! - amount.reserved).display,
                valueColor: AppColors.warning,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1, color: context.colors.outline),
            ),
            DetailRow(
              label: 'Final amount',
              value: amount.finalAmount!.display,
              emphasise: true,
            ),
          ],

          if (amount.hasRefund)
            DetailRow(
              label: 'Refunded',
              value: amount.refunded.display,
              valueColor: AppColors.success,
            ),

          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                booking.payment.isPaid
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                size: AppSizes.iconSm,
                color: booking.payment.isPaid ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  booking.payment.isPaid ? 'Paid' : 'Payment not completed',
                  style: context.text.bodySmall?.copyWith(
                    color: booking.payment.isPaid ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (booking.payment.reference != null)
                Flexible(
                  child: Text(
                    booking.payment.reference!,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefundsCard extends StatelessWidget {
  const _RefundsCard({required this.refunds});

  final List<BookingRefund> refunds;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Refunds', style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          for (final refund in refunds)
            DetailRow(
              label: refund.isComplete
                  ? 'Refunded ${DateFormat('d MMM').format(refund.processedAt!)}'
                  : 'Refund in progress',
              value: refund.amount.display,
              valueColor: refund.isComplete ? AppColors.success : AppColors.warning,
            ),
          if (refunds.any((r) => !r.isComplete)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Refunds usually reach your account within 5–7 working days.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<BookingTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'History', padding: EdgeInsets.zero),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: i == entries.length - 1
                            ? AppColors.brand
                            : context.colors.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < entries.length - 1)
                      Expanded(child: Container(width: 2, color: context.colors.outline)),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entries[i].label, style: context.text.bodyMedium),
                        Text(
                          DateFormat('d MMM, h:mm a').format(entries[i].at),
                          style: context.text.bodySmall
                              ?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/* ── actions ───────────────────────────────────────────────────────────────── */

class _ActionBar extends ConsumerStatefulWidget {
  const _ActionBar({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends ConsumerState<_ActionBar> {
  bool _isWorking = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    // Primary and secondary are collected separately.
    //
    // They used to share one Row of Expanded children, so a confirmed booking —
    // Check in + Directions + Cancel — squeezed three buttons onto a 411px
    // screen and rendered "Di..." for Directions. A truncated button is not a
    // smaller button, it is an unreadable one.
    //
    // The primary action now takes a full-width row of its own, which also
    // states the hierarchy the brief asks for: one obvious next step, with the
    // alternatives beneath it.
    final primary = <Widget>[];
    final secondary = <Widget>[];

    if (booking.actions.canPay) {
      primary.add(SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          label: 'Complete payment',
          icon: Icons.lock_rounded,
          isLoading: _isWorking,
          onPressed: _resumePayment,
        ),
      ));
    }

    if (booking.actions.canCheckIn) {
      primary.add(SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          label: 'Check in',
          icon: Icons.login_rounded,
          isLoading: _isWorking,
          onPressed: () => _run(() => ref.read(bookingActionsProvider).checkIn(booking.id),
              'Checked in. Enjoy your stay.'),
        ),
      ));
    }

    if (booking.actions.canCheckOut) {
      primary.add(SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          label: 'Check out',
          icon: Icons.logout_rounded,
          isLoading: _isWorking,
          onPressed: _confirmCheckOut,
        ),
      ));
    }

    if (booking.parking.hasCoordinates &&
        (booking.status == BookingStatus.confirmed || booking.isParked)) {
      secondary.add(Expanded(
        child: SecondaryButton(
          label: 'Directions',
          icon: Icons.navigation_rounded,
          onPressed: () => openDirections(context, booking),
        ),
      ));
    }

    if (booking.actions.isCancellable) {
      secondary.add(Expanded(
        child: SecondaryButton(
          label: 'Cancel',
          onPressed: () => showCancelBookingSheet(context, ref, booking),
        ),
      ));
    }

    if (booking.status == BookingStatus.completed) {
      primary.add(SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          label: 'Book again',
          onPressed: () => context.push(Routes.parkingDetail(booking.parking.id)),
        ),
      ));
    }

    if (primary.isEmpty && secondary.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.borderDark)),
        boxShadow: AppShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...primary,
              if (primary.isNotEmpty && secondary.isNotEmpty)
                const SizedBox(height: AppSpacing.md),
              if (secondary.isNotEmpty)
                Row(
                  children: [
                    for (var i = 0; i < secondary.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.md),
                      secondary[i],
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resuming a payment goes through the same controller as the first attempt, so
  /// the order is reused rather than duplicated.
  Future<void> _resumePayment() async {
    setState(() => _isWorking = true);
    await ref.read(paymentControllerProvider.notifier).pay(booking: widget.booking);

    if (!mounted) return;
    setState(() => _isWorking = false);

    final payment = ref.read(paymentControllerProvider);
    ref.invalidate(bookingDetailProvider(widget.booking.id));

    if (payment.stage == PaymentStage.failed && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(payment.message ??
              payment.error?.message ??
              'The payment did not complete.'),
        ));
    }
  }

  Future<void> _confirmCheckOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check out now?'),
        content: const Text(
          'Your slot is released and the final amount is worked out from how long '
          'you actually stayed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Check out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _run(
      () => ref.read(bookingActionsProvider).checkOut(widget.booking.id),
      'Checked out. Thanks for parking with PARQX.',
    );
  }

  Future<void> _run(Future<Booking> Function() action, String successMessage) async {
    setState(() => _isWorking = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageInset),
      children: const [
        LoadingSkeleton(height: 120),
        SizedBox(height: AppSpacing.xl),
        LoadingSkeleton(height: 90),
        SizedBox(height: AppSpacing.lg),
        LoadingSkeleton(height: 200),
        SizedBox(height: AppSpacing.lg),
        LoadingSkeleton(height: 140),
      ],
    );
  }
}
