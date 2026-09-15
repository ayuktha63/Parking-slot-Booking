// ─────────────────────────────────────────────────────────────────────────────
// PARKING SESSION
//
// The ride-in-progress screen for parking. The map on top shows where the car
// is; the panel below says what matters right now:
//
//   arriving  — the entry code, the time, directions, and check-in when allowed
//   parked    — a live timer from the server's check-in instant, time left, the
//               server's running estimate, and the way out
//
// It follows the server: when the operator checks the customer in, the booking
// event refreshes the session and this screen changes state in front of them.
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
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../bookings/presentation/bookings_screen.dart' show bookingWhenLabel;
import '../../bookings/presentation/entry_code_card.dart';
import 'checkout_flow.dart';

class ActiveParkingScreen extends ConsumerWidget {
  const ActiveParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This route is pushed over the tab shell, which is where booking events are
    // normally wired; keep them wired here too so the screen stays live.
    ref.watch(bookingRealtimeSyncProvider);
    final current = ref.watch(currentBookingProvider);

    // The session ended somewhere else — the operator checked the car out, or
    // the customer did on another device. Like a finished ride, show how it
    // ended rather than an empty screen.
    ref.listen(currentBookingProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final ended = before != null && before.isParked && next.hasValue && next.value == null;
      if (ended && context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        context.pushReplacement(Routes.checkoutComplete(before.id));
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: current.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const _SessionSkeleton(),
          error: (error, _) => SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: BackCircleButton(),
                ),
                Expanded(
                  child: ErrorStateView(
                    error: asApiException(error),
                    onRetry: () => ref.invalidate(currentBookingProvider),
                  ),
                ),
              ],
            ),
          ),
          data: (booking) => booking == null ? const _NothingActive() : _Session(booking: booking),
        ),
        bottomNavigationBar: current.valueOrNull == null
            ? null
            : _SessionActions(booking: current.value!),
      ),
    );
  }
}

class _Session extends StatelessWidget {
  const _Session({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final position = booking.parking.position;
    final parked = booking.isParked && booking.checkedInAt != null;
    final mapHeight = MediaQuery.sizeOf(context).height * 0.36;
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: mapHeight + 40,
          child: position != null
              ? StaticPlaceMap(position: position, zoom: 16, lift: 20, showAttribution: false)
              : ParqxPhoto(
                  url: booking.parking.coverPhotoUrl,
                  seed: booking.parking.name,
                  borderRadius: BorderRadius.zero,
                ),
        ),
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: mapHeight),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - mapHeight),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.sheet,
                    boxShadow: AppShadows.sheet,
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageInset,
                    AppSpacing.xl,
                    AppSpacing.pageInset,
                    AppSpacing.xxl,
                  ),
                  child: parked ? _ParkedPanel(booking: booking) : _ArrivingPanel(booking: booking),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: topInset + AppSpacing.sm,
          left: AppSpacing.md,
          child: const BackCircleButton(floating: true),
        ),
        if (position != null)
          Positioned(
            top: topInset + AppSpacing.sm,
            right: AppSpacing.md,
            child: CircleButton(
              icon: Icons.near_me_rounded,
              tooltip: 'Directions',
              size: 44,
              floating: true,
              onPressed: () => openDirectionsTo(context, position, booking.parking.name),
            ),
          ),
        if (position != null)
          Positioned(
            top: mapHeight - 22,
            right: AppSpacing.sm,
            child: const MapAttribution(),
          ),
      ],
    );
  }
}

/* ── parked ────────────────────────────────────────────────────────────────── */

class _ParkedPanel extends StatelessWidget {
  const _ParkedPanel({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final session = booking.session;
    final overstaying = session?.isOverstaying == true;
    final estimate = session?.projectedTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LivePulse(color: overstaying ? AppColors.warningBright : AppColors.positiveBright),
            const SizedBox(width: AppSpacing.xs),
            Text(
              overstaying ? 'Over your booked time' : 'Parked',
              style: context.text.titleSmall?.copyWith(
                color: overstaying ? AppColors.warning : AppColors.positive,
              ),
            ),
            const Spacer(),
            if (booking.slot != null) StatusBadge(label: 'Spot ${booking.slot!.code}', tone: BadgeTone.dark),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(booking.parking.name, style: context.text.headlineMedium),
        if (booking.parking.shortLocation != null)
          Text(booking.parking.shortLocation!, style: context.text.bodyMedium),
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: LiveDuration(
            since: booking.checkedInAt!,
            alwaysHours: true,
            style: AppTypography.timer(size: 60, color: overstaying ? AppColors.warning : AppColors.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Text(
            'Since ${DateFormat('h:mm a').format(booking.checkedInAt!)}',
            style: context.text.bodyMedium,
          ),
        ),
        if (session != null) ...[
          const SizedBox(height: AppSpacing.xl),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  overstaying
                      ? 'Past your ${_minutes(session.reservedMinutes)} booking'
                      : '${_minutes(session.remainingMinutes)} left',
                  style: context.text.bodyMedium?.copyWith(
                    color: overstaying ? AppColors.warning : AppColors.inkSecondary,
                  ),
                ),
              ),
              if (booking.window.expectedExitTime != null)
                Text(
                  'Booked until ${DateFormat('h:mm a').format(booking.window.expectedExitTime!)}',
                  style: context.text.bodyMedium,
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppSurface(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Fact(
                    value: estimate?.display ?? booking.amount.reserved.display,
                    label: estimate != null ? 'If you leave now' : 'Booked amount',
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.lineStrong),
                Expanded(
                  child: _Fact(
                    value: booking.amount.hourly == null ? booking.window.durationLabel : booking.amount.hourly!.display,
                    label: booking.amount.hourly == null ? 'Booked for' : 'per hour',
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.lineStrong),
                Expanded(
                  child: _Fact(
                    value: booking.vehicle.displayPlate ?? booking.vehicle.type.label,
                    label: 'Vehicle',
                    code: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (session?.overstayAmount != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner(
            message: 'Includes ${session!.overstayAmount!.display} for the time past your booking. '
                'The final amount is set when you check out.',
            tone: BannerTone.warning,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            PillButton(
              label: 'Booking details',
              icon: Icons.receipt_long_outlined,
              onPressed: () => context.push(Routes.bookingDetail(booking.id)),
            ),
          ],
        ),
      ],
    );
  }

  static String _minutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '${h}h ${m}m';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.value, required this.label, this.code = false});

  final String value;
  final String label;
  final bool code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: code
                  ? AppTypography.code(size: 15)
                  : AppTypography.numeric(size: 19, weight: FontWeight.w700),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/* ── arriving ──────────────────────────────────────────────────────────────── */

class _ArrivingPanel extends StatelessWidget {
  const _ArrivingPanel({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final entry = booking.window.entryTime;
    final minutesToEntry = entry?.difference(DateTime.now()).inMinutes;
    final headline = switch (minutesToEntry) {
      null => 'Upcoming',
      <= 0 => 'Your spot is ready',
      < 60 => 'Arrive in $minutesToEntry min',
      _ => 'Arrive at ${DateFormat('h:mm a').format(entry!)}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 18, color: AppColors.ink),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(headline, style: context.text.titleSmall),
            const Spacer(),
            if (booking.slot != null) StatusBadge(label: 'Spot ${booking.slot!.code}', tone: BadgeTone.dark),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(booking.parking.name, style: context.text.headlineMedium),
        if (booking.parking.addressLabel != null)
          Text(booking.parking.addressLabel!, style: context.text.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        EntryCodeCard(code: booking.code),
        const SizedBox(height: AppSpacing.sm),
        ListRow(
          icon: Icons.event_outlined,
          title: bookingWhenLabel(booking),
          subtitle: booking.window.durationLabel,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
        if (booking.vehicle.displayPlate != null)
          ListRow(
            icon: booking.vehicle.type.wire == 'bike'
                ? Icons.two_wheeler_rounded
                : Icons.directions_car_filled_rounded,
            title: booking.vehicle.displayPlate!,
            subtitle: booking.vehicle.type.label,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
        if (booking.parking.instructions != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(
            title: 'Getting in',
            message: booking.parking.instructions!,
            icon: Icons.directions_walk_rounded,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          'Give this code to the attendant when you arrive. '
          'Your session starts the moment you are checked in.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        PillButton(
          label: 'Booking details',
          icon: Icons.receipt_long_outlined,
          onPressed: () => context.push(Routes.bookingDetail(booking.id)),
        ),
      ],
    );
  }
}

/* ── actions ───────────────────────────────────────────────────────────────── */

class _SessionActions extends ConsumerStatefulWidget {
  const _SessionActions({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_SessionActions> createState() => _SessionActionsState();
}

class _SessionActionsState extends ConsumerState<_SessionActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final Widget? action;
    if (booking.isParked) {
      action = PrimaryButton(
        label: 'End parking',
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
      );
    } else if (booking.actions.canCheckIn) {
      action = PrimaryButton(
        label: 'Check in',
        icon: Icons.login_rounded,
        isLoading: _busy,
        onPressed: _checkIn,
      );
    } else if (booking.status == BookingStatus.pendingPayment) {
      action = PrimaryButton(
        label: 'Complete payment',
        icon: Icons.lock_outline_rounded,
        onPressed: () => context.push(Routes.bookingDetail(booking.id)),
      );
    } else if (booking.parking.position != null) {
      action = PrimaryButton(
        label: 'Get directions',
        icon: Icons.near_me_rounded,
        onPressed: () => openDirectionsTo(context, booking.parking.position!, booking.parking.name),
      );
    } else {
      action = null;
    }
    if (action == null) return const SizedBox.shrink();
    return BottomActionBar(child: action);
  }

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(bookingActionsProvider).checkIn(widget.booking.id);
      if (mounted) showToast(context, 'Checked in. Your session has started.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/* ── nothing ───────────────────────────────────────────────────────────────── */

class _NothingActive extends StatelessWidget {
  const _NothingActive();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.all(AppSpacing.md), child: BackCircleButton()),
          Expanded(
            child: EmptyStateView(
              icon: Icons.local_parking_rounded,
              title: 'No parking in progress',
              message: 'When you check in, your live session — time and cost — shows here. '
                  'Finished sessions are in Activity.',
              action: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  PrimaryButton(
                    label: 'Find parking',
                    expand: false,
                    onPressed: () => context.go(Routes.home),
                  ),
                  SecondaryButton(
                    label: 'Activity',
                    expand: false,
                    onPressed: () => context.go(Routes.bookings),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSkeleton extends StatelessWidget {
  const _SessionSkeleton();

  @override
  Widget build(BuildContext context) {
    final mapHeight = MediaQuery.sizeOf(context).height * 0.36;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        LoadingSkeleton(height: mapHeight, borderRadius: BorderRadius.zero),
        const Padding(
          padding: EdgeInsets.all(AppSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LoadingSkeleton.text(width: 90),
              SizedBox(height: AppSpacing.md),
              LoadingSkeleton.text(width: 220, height: 24),
              SizedBox(height: AppSpacing.xxl),
              Center(child: LoadingSkeleton.text(width: 240, height: 56)),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(height: 84, borderRadius: AppRadius.card),
            ],
          ),
        ),
      ],
    );
  }
}
