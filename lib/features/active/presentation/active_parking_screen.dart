// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE PARKING — a destination, not a card
//
// This was a card at the top of Home. It is now a tab of its own, because it is
// the one screen a customer opens repeatedly while NOT looking for parking:
// they are already parked, they want to know how long they have been there and
// what it is costing, and they will come back to it several times before they
// leave. Making them scroll past a discovery map to reach that was backwards.
//
// ─────────────────────────────────────────────────────────────────────────────
// IT IS A LIVE STATUS SCREEN
//
// The duration ticks every second from the server's `checked_in_at`. Only the
// RENDERING is local — the app never invents an elapsed time, and on resume it
// recomputes from the server timestamp rather than trusting a paused clock.
//
// The estimate beside it is the server's `projected_total`, not a client-side
// rate multiplication. Parking pricing has minimums, rounding and surge in it;
// a plausible-looking number computed in Dart would disagree with the receipt,
// and it would disagree in the customer's favour about half the time.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/booking_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/live_duration.dart';
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../bookings/presentation/bookings_screen.dart' show openDirections;

class ActiveParkingScreen extends ConsumerWidget {
  const ActiveParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentBookingProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: current.when(
          loading: () => const _ActiveSkeleton(),
          error: (error, _) => ErrorStateView(
            error: asApiException(error),
            onRetry: () => ref.invalidate(currentBookingProvider),
          ),
          data: (booking) => booking == null
              ? const _NothingActive()
              : _Active(booking: booking),
        ),
      ),
    );
  }
}

/* ── the session ───────────────────────────────────────────────────────────── */

class _Active extends ConsumerWidget {
  const _Active({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parked = booking.isParked;
    final session = booking.session;
    final overstaying = session?.isOverstaying == true;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
      children: [
        _Header(parked: parked),

        // ── the place ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
          child: ClipRRect(
            borderRadius: AppRadius.cardLarge,
            child: SizedBox(
              height: 190,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ParqxPhoto(
                    url: booking.parking.coverPhotoUrl,
                    seed: booking.parking.name,
                    borderRadius: BorderRadius.zero,
                    showMonogramInitials: false,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.photoScrim),
                  ),
                  // The slot code, over the photograph: it is the single piece
                  // of information the customer needs when they walk back.
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: _SlotBadge(code: booking.slot?.code ?? '—'),
                  ),
                  Positioned(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          booking.parking.name,
                          style: context.text.headlineSmall
                              ?.copyWith(color: AppColors.onMap),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (booking.parking.addressLabel != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.place_rounded,
                                  size: AppSizes.iconXs, color: AppColors.onMapMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  booking.parking.addressLabel!,
                                  style: context.text.bodySmall
                                      ?.copyWith(color: AppColors.onMapMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── the one sentence this screen exists to say ───────────────────
        //
        // "Ongoing session" in the header was too quiet to carry it: a customer
        // opening this tab needs to know in the first glance that they are
        // parked RIGHT NOW, before they read anything else. A pulsing dot and
        // two words do that; a subtitle does not.
        if (parked)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: Row(
              children: [
                const LivePulse(size: 9),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'PARKING ACTIVE',
                  style: AppTypography.overline(color: AppColors.successBright),
                ),
                const Spacer(),
                Text(
                  'Slot ${booking.slot?.code ?? '—'}',
                  style: context.text.labelMedium
                      ?.copyWith(color: AppColors.inkSecondaryDark),
                ),
              ],
            ),
          ),
        if (parked) const SizedBox(height: AppSpacing.md),

        // ── the clock ────────────────────────────────────────────────────
        if (parked && booking.checkedInAt != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: _LivePanel(booking: booking, overstaying: overstaying),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: _UpcomingPanel(booking: booking),
          ),

        const SizedBox(height: AppSpacing.lg),

        // ── the facts ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
          child: _FactsRow(booking: booking),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── the actions ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
          child: Row(
            children: [
              if (booking.parking.hasCoordinates) ...[
                Expanded(
                  child: SecondaryButton(
                    label: 'Get directions',
                    icon: Icons.navigation_rounded,
                    onPressed: () => openDirections(context, booking),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: _PrimaryAction(booking: booking)),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        Center(
          child: TertiaryButton(
            label: 'Booking details',
            onPressed: () => context.push(Routes.bookingDetail(booking.id)),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.parked, this.subtitle});

  final bool parked;

  /// Overrides the derived line. Used by the empty state, which is neither
  /// "ongoing" nor "upcoming" — it is nothing, and saying "Upcoming session"
  /// over an empty screen states something that is not true.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        MediaQuery.paddingOf(context).top + AppSpacing.lg,
        AppSpacing.pageInset,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(gradient: AppGradients.headerGlow),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Active Parking', style: context.text.displaySmall),
                const SizedBox(height: 2),
                Text(
                  subtitle ?? (parked ? 'Ongoing session' : 'Upcoming session'),
                  style: context.text.bodyMedium
                      ?.copyWith(color: AppColors.inkSecondaryDark),
                ),
              ],
            ),
          ),
          if (parked) const LivePulse(size: 9),
        ],
      ),
    );
  }
}

/// The running clock and the server's estimate.
class _LivePanel extends StatelessWidget {
  const _LivePanel({required this.booking, required this.overstaying});

  final Booking booking;
  final bool overstaying;

  @override
  Widget build(BuildContext context) {
    final estimate = booking.session?.projectedTotal;

    return AppSurface(
      color: AppColors.surfaceDark,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Parking Duration',
                      style: context.text.labelMedium
                          ?.copyWith(color: AppColors.inkMutedDark),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LiveDuration(
                      since: booking.checkedInAt!,
                      alwaysHours: true,
                      style: AppTypography.timer(
                        size: 34,
                        color: overstaying
                            ? AppColors.warningBright
                            : AppColors.inkDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (estimate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Current Estimate',
                      style: context.text.labelMedium
                          ?.copyWith(color: AppColors.inkMutedDark),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      estimate.display,
                      style: AppTypography.numeric(
                        size: 26,
                        weight: FontWeight.w800,
                        color: AppColors.brandMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (overstaying) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: AppSizes.iconXs, color: AppColors.warningBright),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'You are past your booked time. The final amount is '
                    'calculated at check-out.',
                    style: context.text.bodySmall
                        ?.copyWith(color: AppColors.warningBright),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final entry = booking.window.entryTime;
    final unpaid = booking.status == BookingStatus.pendingPayment;

    return AppSurface(
      color: AppColors.surfaceDark,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unpaid ? 'Payment not completed' : 'Arriving',
                  style: context.text.labelMedium?.copyWith(
                    color: unpaid ? AppColors.warningBright : AppColors.inkMutedDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry == null
                      ? booking.window.durationLabel
                      : DateFormat('EEE d MMM, h:mm a').format(entry.toLocal()),
                  style: context.text.headlineSmall,
                ),
              ],
            ),
          ),
          ParqxBadge(
            label: booking.window.durationLabel,
            colour: AppColors.brandMuted,
            onDark: true,
          ),
        ],
      ),
    );
  }
}

/// Check-in, vehicle and rate — the three things a customer is asked for and
/// the one they need to check.
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final checkedIn = booking.checkedInAt;

    final facts = <(String, String)>[
      if (checkedIn != null)
        ('Check-in', DateFormat('h:mm a').format(checkedIn.toLocal()))
      else
        ('Slot', booking.slot?.code ?? '—'),
      ('Vehicle', booking.vehicle.numberPlate ?? booking.vehicle.type.label),
      // The rate, when the server sent one. It explains the estimate above in a
      // way the amount already paid does not — and it is the server's own
      // snapshot, never a client-side division of total by hours.
      if (booking.amount.hourly != null)
        ('Rate', '${booking.amount.hourly!.display}/hr')
      else
        ('Paid', booking.amount.reserved.display),
    ];

    return AppSurface(
      color: AppColors.surfaceDark,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                color: AppColors.borderDark,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    facts[i].$1,
                    style: context.text.labelSmall
                        ?.copyWith(color: AppColors.inkMutedDark, letterSpacing: 0),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    facts[i].$2,
                    style: AppTypography.numeric(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: AppColors.inkDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The action that matches the booking's actual state.
class _PrimaryAction extends ConsumerStatefulWidget {
  const _PrimaryAction({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_PrimaryAction> createState() => _PrimaryActionState();
}

class _PrimaryActionState extends ConsumerState<_PrimaryAction> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    if (booking.status == BookingStatus.pendingPayment) {
      return PrimaryButton(
        label: 'Complete payment',
        icon: Icons.lock_rounded,
        onPressed: () => context.push(Routes.bookingDetail(booking.id)),
      );
    }

    if (booking.isParked) {
      // NOT `danger`.
      //
      // Check-out was rendered in alarm red, which is the colour this product
      // reserves for things that are wrong — cancelling, deleting, refusing.
      // Ending a parking session you paid for is the successful conclusion of
      // the journey, and colouring it like a mistake makes people hesitate over
      // the one action the screen is for.
      //
      // It is also deliberately not brand violet: violet is "pay", and this is
      // not a payment. Completion green, which nothing else on this screen
      // uses as a fill.
      return PrimaryButton(
        label: 'Check out',
        icon: Icons.logout_rounded,
        tone: ButtonTone.complete,
        isLoading: _busy,
        onPressed: _busy ? null : _confirmCheckOut,
      );
    }

    return SecondaryButton(
      label: 'Show booking code',
      icon: Icons.confirmation_number_outlined,
      onPressed: () => context.push(Routes.bookingDetail(booking.id)),
    );
  }

  /// "Ready to leave?" — the deliberate pause before ending a session.
  ///
  /// It shows how long they have been there and what the server currently
  /// estimates, and it is careful to call that an ESTIMATE: the final amount is
  /// computed by the server at check-out from the actual elapsed time, and
  /// presenting a projection as a settled figure would be a small lie that the
  /// receipt then contradicts.
  Future<void> _confirmCheckOut() async {
    final booking = widget.booking;
    final estimate = booking.session?.projectedTotal;
    final since = booking.checkedInAt;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.sm,
            AppSpacing.pageInset,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // No SheetGrabber here: `bottomSheetTheme.showDragHandle` already
              // draws one, and adding a second put two handles on the sheet.
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ready to leave?',
                style: sheetContext.text.headlineMedium
                    ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (since != null)
                _SheetRow(
                  label: 'Parking duration',
                  child: LiveDuration(
                    since: since,
                    alwaysHours: true,
                    style: AppTypography.numeric(
                      size: 20,
                      weight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),

              if (estimate != null) ...[
                const SizedBox(height: AppSpacing.md),
                _SheetRow(
                  label: 'Estimated amount',
                  child: Text(
                    estimate.display,
                    style: AppTypography.numeric(
                      size: 20,
                      weight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: AppSizes.iconSm, color: AppColors.inkMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'The final amount is worked out when you check out, from '
                      'how long you actually stayed.',
                      style: sheetContext.text.bodySmall
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Check out',
                icon: Icons.logout_rounded,
                tone: ButtonTone.complete,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TertiaryButton(
                  label: 'Keep parking',
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final completed =
          await ref.read(bookingActionsProvider).checkOut(booking.id);
      if (!mounted) return;
      Haptics.success();
      // The journey gets an ending.
      //
      // Checking out used to drop the customer straight onto the booking detail
      // screen, which is a record rather than a conclusion — the same screen
      // they would see looking up a booking from six weeks ago. The session
      // they just finished deserves to be acknowledged before it becomes
      // history.
      context.pushReplacement(Routes.checkoutComplete, extra: completed);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(asApiException(error).message),
          backgroundColor: AppColors.danger,
        ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// A label/value row inside the check-out sheet.
class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: context.text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
        child,
      ],
    );
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.mapOverlayInk.withValues(alpha: 0.72),
        borderRadius: AppRadius.field,
        border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: AppTypography.slotCode(color: AppColors.onMap, size: 20),
          ),
          Text(
            'Your Slot',
            style: context.text.labelSmall?.copyWith(
              color: AppColors.onMapMuted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── nothing active ────────────────────────────────────────────────────────── */

class _NothingActive extends StatelessWidget {
  const _NothingActive();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: _Header(parked: false, subtitle: 'Nothing running right now'),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            icon: Icons.directions_car_outlined,
            title: 'No active parking',
            message: 'When you check in to a parking area, your live session '
                'appears here with the running time and cost.',
            action: PrimaryButton(
              label: 'Find parking',
              icon: Icons.search_rounded,
              expand: false,
              onPressed: () => context.go(Routes.home),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveSkeleton extends StatelessWidget {
  const _ActiveSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        MediaQuery.paddingOf(context).top + AppSpacing.giant,
        AppSpacing.pageInset,
        0,
      ),
      children: const [
        LoadingSkeleton(height: 28, width: 190),
        SizedBox(height: AppSpacing.xl),
        LoadingSkeleton(height: 190, borderRadius: AppRadius.cardLarge),
        SizedBox(height: AppSpacing.lg),
        LoadingSkeleton(height: 104, borderRadius: AppRadius.card),
        SizedBox(height: AppSpacing.lg),
        LoadingSkeleton(height: 74, borderRadius: AppRadius.card),
      ],
    );
  }
}
