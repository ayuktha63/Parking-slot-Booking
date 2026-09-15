// ─────────────────────────────────────────────────────────────────────────────
// BOOKING / RECEIPT
//
// One booking, whatever state it is in: where it is (a map), what state it is in,
// the entry code while it is still ahead, the live session while parked, and the
// money — which becomes the receipt once it is finished. Actions come from the
// server's `actions` block; nothing is offered that the server would refuse.
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
import '../../../core/theme/typography.dart';
import '../../../core/utils/directions.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/live_duration.dart';
import '../../../shared/widgets/map_canvas.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../active/presentation/checkout_flow.dart';
import 'bookings_screen.dart' show BookingStatusBadge, bookingWhenLabel;
import 'cancel_booking_sheet.dart';
import 'entry_code_card.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingDetailProvider(bookingId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: booking.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const _DetailSkeleton(),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorStateView(
              error: asApiException(error),
              onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
            ),
          ),
          data: (data) => RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () async {
              ref.invalidate(bookingDetailProvider(bookingId));
              await ref.read(bookingDetailProvider(bookingId).future);
            },
            child: _Content(booking: data),
          ),
        ),
        bottomNavigationBar: booking.valueOrNull == null ? null : _ActionBar(booking: booking.value!),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final position = booking.parking.position;
    final finished = booking.status == BookingStatus.completed;
    // Only a paid booking gets through the gate — the operator's check-in
    // refuses anything else — so the code is not offered before then.
    final showCode = booking.status == BookingStatus.confirmed;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (position != null)
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leadingWidth: 64,
            leading: const Padding(
              padding: EdgeInsets.only(left: AppSpacing.md),
              child: Center(child: CollapsingBackButton()),
            ),
            title: _FadingTitle(text: finished ? 'Receipt' : 'Booking'),
            titleSpacing: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: StaticPlaceMap(position: position, zoom: 16, lift: 12),
            ),
          )
        else
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            title: Text(finished ? 'Receipt' : 'Booking'),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              AppSpacing.xl,
              AppSpacing.pageInset,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(booking.parking.name, style: context.text.headlineLarge),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: BookingStatusBadge(booking: booking),
                    ),
                  ],
                ),
                if (booking.parking.addressLabel != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(booking.parking.addressLabel!, style: context.text.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.xl),
                if (booking.isParked && booking.checkedInAt != null) ...[
                  _LiveSession(booking: booking),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (booking.status == BookingStatus.pendingPayment) ...[
                  InlineBanner(
                    title: 'Waiting for payment',
                    message: 'This booking is not confirmed until payment completes. '
                        '${booking.payment.dueAt == null ? 'The spot is only kept for a short time.' : 'Your spot is held until ${DateFormat('h:mm a').format(booking.payment.dueAt!)}.'}',
                    tone: BannerTone.warning,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (showCode) ...[
                  EntryCodeCard(code: booking.code),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _Details(booking: booking)),
        SliverToBoxAdapter(child: _Money(booking: booking)),
        if (booking.parking.instructions != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageInset,
                AppSpacing.lg,
                AppSpacing.pageInset,
                0,
              ),
              child: InlineBanner(
                title: 'Getting in',
                message: booking.parking.instructions!,
                icon: Icons.directions_walk_rounded,
              ),
            ),
          ),
        if (booking.cancellationReason != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageInset,
                AppSpacing.lg,
                AppSpacing.pageInset,
                0,
              ),
              child: InlineBanner(
                title: 'Cancellation reason',
                message: booking.cancellationReason!,
              ),
            ),
          ),
        if (booking.timeline.isNotEmpty)
          SliverToBoxAdapter(child: _Timeline(entries: booking.timeline)),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
    );
  }
}

class _FadingTitle extends StatelessWidget {
  const _FadingTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final delta = (settings?.maxExtent ?? 0) - (settings?.minExtent ?? 0);
    final t = delta <= 0
        ? 1.0
        : (1 - ((settings!.currentExtent - settings.minExtent) / delta)).clamp(0.0, 1.0);
    return Opacity(
      opacity: ((t - 0.7) / 0.3).clamp(0.0, 1.0),
      child: Text(text, style: context.text.titleLarge),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, AppSpacing.xl, AppSpacing.pageInset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hairline(),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

/* ── live session ──────────────────────────────────────────────────────────── */

class _LiveSession extends StatelessWidget {
  const _LiveSession({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final session = booking.session;
    final overstaying = session?.isOverstaying == true;
    return AppSurface(
      level: SurfaceLevel.raised,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LivePulse(color: overstaying ? AppColors.warningBright : AppColors.positiveBright),
              const SizedBox(width: AppSpacing.xs),
              Text(
                overstaying ? 'Over your booked time' : 'Parked now',
                style: context.text.titleSmall?.copyWith(
                  color: overstaying ? AppColors.warning : AppColors.positive,
                ),
              ),
              const Spacer(),
              if (booking.slot != null)
                Text('Spot ${booking.slot!.code}', style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LiveDuration(
            since: booking.checkedInAt!,
            alwaysHours: true,
            style: AppTypography.timer(size: 44),
          ),
          if (session != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.chip,
              child: LinearProgressIndicator(
                value: session.progress,
                minHeight: 6,
                color: overstaying ? AppColors.warningBright : AppColors.ink,
                backgroundColor: AppColors.fill,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              overstaying
                  ? 'Booked for ${_minutes(session.reservedMinutes)} — overstay charges apply'
                  : '${_minutes(session.remainingMinutes)} left of ${_minutes(session.reservedMinutes)}',
              style: context.text.bodyMedium,
            ),
            if (session.projectedTotal != null) ...[
              const SizedBox(height: AppSpacing.md),
              const Hairline(),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(label: 'If you leave now', value: session.projectedTotal!.display, emphasise: true),
            ],
          ],
          const SizedBox(height: AppSpacing.sm),
          PillButton(
            label: 'Open live session',
            icon: Icons.open_in_full_rounded,
            onPressed: () => context.push(Routes.active),
          ),
        ],
      ),
    );
  }

  static String _minutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '${h}h ${m}m';
  }
}

/* ── details ───────────────────────────────────────────────────────────────── */

class _Details extends StatelessWidget {
  const _Details({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Details'),
        ListRow(
          icon: Icons.schedule_rounded,
          title: bookingWhenLabel(booking),
          subtitle: 'Booked for ${booking.window.durationLabel}',
        ),
        if (booking.slot != null)
          ListRow(
            icon: Icons.local_parking_rounded,
            title: 'Spot ${booking.slot!.code}',
            subtitle: booking.slot!.rowLabel == null ? null : 'Row ${booking.slot!.rowLabel}',
          ),
        if (booking.vehicle.displayPlate != null)
          ListRow(
            icon: booking.vehicle.type.wire == 'bike'
                ? Icons.two_wheeler_rounded
                : Icons.directions_car_filled_rounded,
            title: booking.vehicle.displayPlate!,
            subtitle: booking.vehicle.label ?? booking.vehicle.type.label,
          ),
        if (booking.checkedInAt != null)
          ListRow(
            icon: Icons.login_rounded,
            title: 'Checked in ${time.format(booking.checkedInAt!)}',
            subtitle: DateFormat('EEE d MMM').format(booking.checkedInAt!),
          ),
        if (booking.checkedOutAt != null)
          ListRow(
            icon: Icons.logout_rounded,
            title: 'Checked out ${time.format(booking.checkedOutAt!)}',
            subtitle: booking.checkedInAt == null
                ? null
                : 'Parked ${_span(booking.checkedOutAt!.difference(booking.checkedInAt!))}',
          ),
        ListRow(icon: Icons.tag_rounded, title: booking.code, subtitle: 'Booking code'),
      ],
    );
  }

  static String _span(Duration d) {
    final minutes = d.inMinutes;
    if (minutes < 1) return 'under a minute';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '${h}h ${m}m';
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final amount = booking.amount;
    final finalAmount = amount.finalAmount;
    final overstay = finalAmount != null && finalAmount.paise > amount.reserved.paise
        ? finalAmount - amount.reserved
        : null;
    final finished = booking.status == BookingStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(finished ? 'Receipt' : 'Payment'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
          child: Column(
            children: [
              if (amount.hourly != null) InfoRow(label: 'Rate', value: '${amount.hourly!.display}/hr'),
              InfoRow(label: 'Booked amount', value: amount.reserved.display),
              if (overstay != null)
                InfoRow(label: 'Overstay', value: overstay.display, valueColor: AppColors.warning),
              if (amount.hasRefund)
                InfoRow(
                  label: 'Refunded',
                  value: '− ${amount.refunded.display}',
                  valueColor: AppColors.positive,
                ),
              const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.xs), child: Hairline()),
              InfoRow(
                label: finalAmount != null ? 'Total' : 'Amount',
                value: amount.payable.display,
                emphasise: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    booking.payment.isPaid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                    size: 18,
                    color: booking.payment.isPaid ? AppColors.positive : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      booking.payment.isPaid
                          ? (booking.payment.verifiedAt == null
                              ? 'Paid'
                              : 'Paid ${DateFormat('d MMM, h:mm a').format(booking.payment.verifiedAt!)}')
                          : 'Payment not completed',
                      style: context.text.bodyMedium?.copyWith(
                        color: booking.payment.isPaid ? AppColors.positive : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (booking.payment.reference != null)
                InfoRow(label: 'Payment reference', value: booking.payment.reference!),
              for (final refund in booking.refunds)
                InfoRow(
                  label: refund.isComplete && refund.processedAt != null
                      ? 'Refund sent ${DateFormat('d MMM').format(refund.processedAt!)}'
                      : 'Refund in progress',
                  value: refund.amount.display,
                  valueColor: refund.isComplete ? AppColors.positive : AppColors.warning,
                ),
            ],
          ),
        ),
      ],
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
        const _SectionTitle('History'),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: i == entries.length - 1 ? AppColors.ink : AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.ink, width: 2),
                          ),
                        ),
                        if (i < entries.length - 1)
                          Expanded(child: Container(width: 2, color: AppColors.line)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entries[i].label, style: context.text.bodyLarge),
                          Text(
                            DateFormat('d MMM, h:mm a').format(entries[i].at),
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    // The payment controller is auto-disposed. Read alone, it was torn down while
    // its order request was still in flight, the reply had nowhere to land, and
    // "Complete payment" spun forever. Listening keeps it alive with this bar.
    ref.listen(paymentControllerProvider, (_, __) {});
    final booking = widget.booking;
    final primary = <Widget>[];
    final secondary = <Widget>[];

    if (booking.actions.canPay) {
      primary.add(PrimaryButton(
        label: 'Complete payment · ${booking.amount.reserved.display}',
        icon: Icons.lock_outline_rounded,
        isLoading: _busy,
        onPressed: _resumePayment,
      ));
    }
    if (booking.actions.canCheckIn) {
      primary.add(PrimaryButton(
        label: 'Check in',
        icon: Icons.login_rounded,
        isLoading: _busy,
        onPressed: _checkIn,
      ));
    }
    if (booking.actions.canCheckOut) {
      primary.add(PrimaryButton(
        label: 'Check out',
        icon: Icons.logout_rounded,
        isLoading: _busy,
        onPressed: () => confirmAndCheckOut(
          context,
          ref,
          booking,
          onBusy: (busy) {
            if (mounted) setState(() => _busy = busy);
          },
        ),
      ));
    }
    if (booking.status == BookingStatus.completed) {
      primary.add(PrimaryButton(
        label: 'Book this place again',
        icon: Icons.refresh_rounded,
        onPressed: () => context.push(Routes.parkingDetail(booking.parking.id)),
      ));
    }
    if (booking.parking.position != null &&
        (booking.status == BookingStatus.confirmed || booking.isParked)) {
      secondary.add(PillButton(
        label: 'Directions',
        icon: Icons.near_me_rounded,
        onPressed: () => openDirectionsTo(context, booking.parking.position!, booking.parking.name),
      ));
    }
    if (booking.actions.isCancellable) {
      secondary.add(PillButton(
        label: 'Cancel booking',
        onPressed: () => showCancelBookingSheet(context, ref, booking),
      ));
    }

    if (primary.isEmpty && secondary.isEmpty) return const SizedBox.shrink();

    return BottomActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secondary.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: primary.isEmpty ? 0 : AppSpacing.md),
              child: Row(
                children: [
                  for (var i = 0; i < secondary.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    secondary[i],
                  ],
                ],
              ),
            ),
          for (var i = 0; i < primary.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            primary[i],
          ],
        ],
      ),
    );
  }

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(bookingActionsProvider).checkIn(widget.booking.id);
      if (mounted) showToast(context, 'Checked in. Enjoy your stay.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resumePayment() async {
    setState(() => _busy = true);
    try {
      await ref.read(paymentControllerProvider.notifier).pay(booking: widget.booking);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final payment = ref.read(paymentControllerProvider);
    ref.invalidate(bookingDetailProvider(widget.booking.id));
    if (payment.stage == PaymentStage.confirmed && payment.booking != null) {
      context.pushReplacement(Routes.bookingConfirmation(widget.booking.id), extra: payment.booking);
      return;
    }
    if (payment.stage == PaymentStage.failed) {
      showToast(
        context,
        payment.refundDue
            ? 'This booking closed before your payment arrived. The full amount is owed back to you.'
            : payment.message ?? payment.error?.message ?? "Payment wasn't completed.",
      );
    }
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        LoadingSkeleton(height: 210, borderRadius: BorderRadius.zero),
        Padding(
          padding: EdgeInsets.all(AppSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.sm),
              LoadingSkeleton.text(width: 220, height: 24),
              SizedBox(height: AppSpacing.md),
              LoadingSkeleton.text(width: 160),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(height: 96, borderRadius: AppRadius.card),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(height: 56),
              SizedBox(height: AppSpacing.md),
              LoadingSkeleton(height: 56),
            ],
          ),
        ),
      ],
    );
  }
}
