// ─────────────────────────────────────────────────────────────────────────────
// REVIEW & PAY
//
// The last screen before money moves, and therefore the one that has to be exactly
// truthful.
//
// Every figure shown is a line from the server's quote — the same quote stored on
// the hold, which is the same one the payment order is created from. There is no
// arithmetic in this file. The old app displayed a hardcoded "₹30/hr", charged
// Razorpay 100 paise, and rendered "$5.00" on the success screen; three different
// numbers for one transaction, none of them related.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import 'journey_progress.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/models/money.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';
import '../data/booking_repository.dart';
import 'hold_countdown_bar.dart';

class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({super.key});

  @override
  ConsumerState<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen> {
  /// Generated once for this attempt and reused across retries, so a booking
  /// created on a request whose response was lost is returned rather than
  /// duplicated.
  final String _idempotencyKey = newIdempotencyKey();

  final TextEditingController _plateController = TextEditingController();

  int? _selectedVehicleId;
  bool _useNewPlate = false;
  bool _isSubmitting = false;
  String? _plateError;

  /// The booking, once created. Held so a failed payment can be retried against
  /// the same booking instead of starting over.
  Booking? _booking;

  /// The hold as it was at the moment the booking consumed it.
  ///
  /// Not stale data being passed off as live: once a booking exists these
  /// values are FIXED — the slot, window and quote were settled by the server
  /// when it created the booking, and no longer depend on a countdown.
  SlotHold? _consumedHold;

  @override
  void initState() {
    super.initState();
    // Preselect the customer's default vehicle for this type — the plate does not
    // need retyping on every booking, which was one of the old flow's worst steps.
    final hold = ref.read(holdControllerProvider).hold;
    final vehicles = ref.read(userVehiclesProvider);
    final match = _defaultFor(vehicles, hold?.slot.vehicleType.wire);
    _selectedVehicleId = match?.id;
    _useNewPlate = match == null;
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  static Vehicle? _defaultFor(List<Vehicle> vehicles, String? wire) {
    if (wire == null) return null;
    for (final v in vehicles) {
      if (v.vehicleType.wire == wire && v.isDefault) return v;
    }
    for (final v in vehicles) {
      if (v.vehicleType.wire == wire) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final holdState = ref.watch(holdControllerProvider);
    final payment = ref.watch(paymentControllerProvider);
    final vehicles = ref.watch(userVehiclesProvider);

    // Payment confirmed: leave for the confirmation screen. `go` rather than
    // `push`, so Back cannot return to a review of an already-paid booking.
    ref.listen(paymentControllerProvider, (previous, next) {
      if (next.stage == PaymentStage.confirmed && next.booking != null && mounted) {
        context.pushReplacement(Routes.bookingConfirmation, extra: next.booking);
      }
    });

    // The hold lapsed. The slot is gone; there is nothing to review.
    ref.listen(holdControllerProvider, (previous, next) {
      if (next.expiredJustNow && mounted && _booking == null) {
        _onHoldExpired();
      }
    });

    // ── the consumed-hold trap ────────────────────────────────────────
    //
    // A SUCCESSFUL booking consumes the hold, so `holdState.hold` becomes null
    // the instant `POST /bookings` returns 201 — correctly, because there is no
    // longer a live hold: it became a booking.
    //
    // This screen used to read that null and render "Your hold expired. Pick a
    // slot again." while the booking existed and the payment was in flight.
    // Following that advice would have created a SECOND booking for the same
    // customer. The listener below already guarded on `_booking == null`; this
    // branch did not.
    //
    // After consumption the screen keeps rendering from the snapshot, because
    // the thing on screen is no longer a hold — it is the booking being paid
    // for, and its details have not changed.
    final hold = holdState.hold ?? _consumedHold;

    if (hold == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: _HoldGoneView(onPickAgain: () => context.pop()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review your booking'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(9),
          child: JourneyProgress(
            step: payment.isBusy ? BookingStep.pay : BookingStep.review,
          ),
        ),
        actions: [
          // Only while a hold is what is keeping the slot. After the booking
          // exists the slot is held by the BOOKING, and a ticking countdown
          // beside it would say the opposite — that the customer is about to
          // lose something they have already secured.
          if (_booking == null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(child: HoldCountdownPill(state: holdState)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageInset,
          AppSpacing.lg,
          AppSpacing.pageInset,
          AppSpacing.xxxl,
        ),
        children: [
          if (holdState.isExpiring && _booking == null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: InlineBanner(
                message: 'Your slot is released in ${holdState.countdownLabel}. '
                    'Complete payment to keep it.',
                tone: BannerTone.warning,
                actionLabel: hold.canExtend ? 'Hold longer' : null,
                onAction: hold.canExtend
                    ? () => ref.read(holdControllerProvider.notifier).extend()
                    : null,
              ),
            ),

          _ParkingBlock(hold: hold),
          const SizedBox(height: AppSpacing.xl),

          _ReservationBlock(hold: hold),
          const SizedBox(height: AppSpacing.xl),

          _VehicleBlock(
            vehicles: vehicles
                .where((v) => v.vehicleType.wire == hold.slot.vehicleType.wire)
                .toList(growable: false),
            selectedVehicleId: _selectedVehicleId,
            useNewPlate: _useNewPlate,
            plateController: _plateController,
            plateError: _plateError,
            onSelectVehicle: (id) => setState(() {
              _selectedVehicleId = id;
              _useNewPlate = false;
              _plateError = null;
            }),
            onUseNewPlate: () => setState(() {
              _useNewPlate = true;
              _selectedVehicleId = null;
            }),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (hold.quote != null)
            _PriceBlock(quote: hold.quote!)
          else
            // The hold carries no snapshot (it was extended, which reissues without
            // one). Rather than showing a price we have not been given, say where
            // the number will come from.
            const InlineBanner(
              message: 'The exact amount is confirmed when payment starts.',
              tone: BannerTone.info,
            ),

          const SizedBox(height: AppSpacing.lg),
          const _PolicyNote(),

          if (payment.stage == PaymentStage.failed) ...[
            const SizedBox(height: AppSpacing.lg),
            InlineBanner(
              message: payment.message ??
                  payment.error?.message ??
                  'The payment did not complete. You can try again.',
              tone: BannerTone.danger,
            ),
          ],
        ],
      ),
      bottomNavigationBar: _PayBar(
        failed: payment.stage == PaymentStage.failed,
        bookingExists: _booking != null,
        onViewBooking: _booking == null
            ? null
            : () => context.pushReplacement(Routes.bookingDetail(_booking!.id)),
        total: hold.quote?.total,
        isBusy: _isSubmitting || payment.isBusy,
        stageLabel: _stageLabel(payment.stage),
        onPay: _submit,
      ),
    );
  }

  String? _stageLabel(PaymentStage stage) {
    switch (stage) {
      case PaymentStage.creatingOrder:
        return 'Preparing payment…';
      case PaymentStage.atGateway:
        return 'Complete the payment';
      case PaymentStage.verifying:
        // Deliberately not "Payment successful" — it has not been verified yet.
        return 'Confirming with your bank…';
      case PaymentStage.idle:
      case PaymentStage.confirmed:
      case PaymentStage.failed:
        return null;
    }
  }

  /* ── submit ──────────────────────────────────────────────────────────── */

  Future<void> _submit() async {
    // Once the booking exists the hold is gone by design — it was consumed
    // creating it. A retry after a failed payment must therefore NOT require a
    // live hold, or the second tap of "Try again" reports a hold expiry that
    // did not happen and strands a real, payable booking.
    final hold = ref.read(holdControllerProvider).hold ?? _consumedHold;
    if (hold == null) {
      _onHoldExpired();
      return;
    }

    final plate = _plateController.text.trim().toUpperCase().replaceAll(' ', '');
    if (_useNewPlate && plate.length < 4) {
      setState(() => _plateError = 'Enter your vehicle number');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _plateError = null;
    });

    // Step 1: create the booking, if this is the first attempt. A retry after a
    // failed payment reuses the booking that already exists.
    var booking = _booking;

    if (booking == null) {
      try {
        booking = await ref.read(bookingRepositoryProvider).createBooking(
              holdId: hold.id,
              vehicleId: _useNewPlate ? null : _selectedVehicleId,
              numberPlate: _useNewPlate ? plate : null,
              idempotencyKey: _idempotencyKey,
            );
        if (!mounted) return;
        setState(() => _booking = booking);

        // The hold is now a booking; the countdown must stop without releasing
        // the slot, which the booking holds instead.
        //
        // Snapshot first: `consumed()` nulls the controller's hold, and this
        // screen still needs its slot, window and quote to render the thing the
        // customer is paying for.
        _consumedHold = hold;
        ref.read(holdControllerProvider.notifier).consumed();

        // The customer may have added a vehicle by typing a plate.
        if (_useNewPlate) {
          unawaited(ref.read(authControllerProvider.notifier).refreshProfile());
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showError(e);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Step 2: pay. The controller owns order → gateway → verify and reports only
    // what the server concluded.
    await ref.read(paymentControllerProvider.notifier).pay(booking: booking);
  }

  void _showError(ApiException e) {
    // A lost slot is not a generic failure — it needs a different offer.
    final lostSlot = e.code == 'SLOT_UNAVAILABLE' ||
        e.code == 'SLOT_HELD_BY_ANOTHER' ||
        e.code == 'TIME_OVERLAP' ||
        e.code == 'HOLD_EXPIRED';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(e.message),
        duration: const Duration(seconds: 4),
        action: lostSlot
            ? SnackBarAction(label: 'Pick another', onPressed: () => context.pop())
            : null,
      ));
  }

  void _onHoldExpired() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Your hold expired and the slot was released.'),
      ));
    if (context.canPop()) context.pop();
  }
}

/* ── blocks ────────────────────────────────────────────────────────────────── */

class _ParkingBlock extends StatelessWidget {
  const _ParkingBlock({required this.hold});

  final SlotHold hold;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_parking_rounded,
                size: AppSizes.iconMd, color: AppColors.brandStrong),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hold.parkingName ?? 'Parking',
                  style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Slot ${hold.slot.code}',
                  style: context.text.bodyMedium?.copyWith(color: AppColors.brandStrong),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationBlock extends StatelessWidget {
  const _ReservationBlock({required this.hold});

  final SlotHold hold;

  @override
  Widget build(BuildContext context) {
    final start = hold.entryTime;
    final end = start.add(Duration(minutes: hold.durationMinutes));
    final sameDay = start.day == end.day && start.month == end.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Your reservation', padding: EdgeInsets.zero),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              DetailRow(
                label: 'Arriving',
                value: DateFormat('EEE d MMM, h:mm a').format(start),
                icon: Icons.login_rounded,
              ),
              DetailRow(
                label: 'Leaving',
                value: sameDay
                    ? DateFormat('h:mm a').format(end)
                    : DateFormat('EEE d MMM, h:mm a').format(end),
                icon: Icons.logout_rounded,
              ),
              DetailRow(
                label: 'Duration',
                value: _durationLabel(hold.durationMinutes),
                icon: Icons.schedule_rounded,
              ),
              DetailRow(
                label: 'Slot',
                value: hold.slot.code,
                icon: Icons.grid_view_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _durationLabel(int minutes) {
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return '$h hour${h == 1 ? '' : 's'}';
    }
    if (minutes < 60) return '$minutes minutes';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class _VehicleBlock extends StatelessWidget {
  const _VehicleBlock({
    required this.vehicles,
    required this.selectedVehicleId,
    required this.useNewPlate,
    required this.plateController,
    required this.plateError,
    required this.onSelectVehicle,
    required this.onUseNewPlate,
  });

  final List<Vehicle> vehicles;
  final int? selectedVehicleId;
  final bool useNewPlate;
  final TextEditingController plateController;
  final String? plateError;
  final ValueChanged<int> onSelectVehicle;
  final VoidCallback onUseNewPlate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Vehicle', padding: EdgeInsets.zero),
        const SizedBox(height: AppSpacing.md),

        for (final vehicle in vehicles)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _VehicleOption(
              title: vehicle.numberPlate,
              subtitle: vehicle.label ?? (vehicle.isDefault ? 'Default' : null),
              icon: vehicle.vehicleType.wire == 'bike'
                  ? Icons.two_wheeler_rounded
                  : Icons.directions_car_rounded,
              selected: !useNewPlate && selectedVehicleId == vehicle.id,
              onTap: () => onSelectVehicle(vehicle.id),
            ),
          ),

        _VehicleOption(
          title: vehicles.isEmpty ? 'Enter your vehicle number' : 'Use a different vehicle',
          subtitle: vehicles.isEmpty ? null : 'It will be saved for next time',
          icon: Icons.add_rounded,
          selected: useNewPlate,
          onTap: onUseNewPlate,
        ),

        if (useNewPlate) ...[
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Vehicle number',
            controller: plateController,
            hint: 'KA01AB1234',
            errorText: plateError,
            textCapitalization: TextCapitalization.characters,
            prefixIcon: Icons.badge_outlined,
            maxLength: 16,
          ),
        ],
      ],
    );
  }
}

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.field,
        child: AnimatedContainer(
          duration: AppMotion.instant,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandSoft : context.colors.surface,
            border: Border.all(
              color: selected ? AppColors.brand : context.colors.outline,
              width: selected ? 2 : 1,
            ),
            borderRadius: AppRadius.field,
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: AppSizes.iconMd,
                  color: selected ? AppColors.brandStrong : context.colors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: context.text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.brandStrong : context.colors.onSurface,
                        )),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: context.text.bodySmall
                              ?.copyWith(color: context.colors.onSurfaceVariant)),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    size: AppSizes.iconMd, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
  }
}

/// The price, line by line.
///
/// Only the lines that exist are drawn: a lot with no platform fee shows no
/// platform fee row, rather than "₹0".
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.quote});

  final PriceQuoteLite quote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Price', padding: EdgeInsets.zero),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              DetailRow(
                label: '${quote.hourly.display}/hr × ${quote.billedHours} '
                    'hour${quote.billedHours == 1 ? '' : 's'}',
                value: quote.subtotal.display,
              ),

              if (quote.isSurge)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          size: AppSizes.iconXs, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Higher demand right now (×${quote.multiplier.toStringAsFixed(2)})',
                          style:
                              context.text.bodySmall?.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),

              if (quote.hasPlatformFee)
                DetailRow(label: 'Platform fee', value: quote.platformFee.display),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1, color: context.colors.outline),
              ),

              DetailRow(
                label: 'Total',
                value: quote.total.display,
                emphasise: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyNote extends StatelessWidget {
  const _PolicyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded,
            size: AppSizes.iconSm, color: context.colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Staying longer than booked is charged at the parking area’s overstay rate. '
            'Cancellation refunds depend on how close to your arrival time you cancel — '
            'the exact amount is shown before you confirm.',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// The action bar, which reports the real state of the transaction.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS IS STATE-AWARE
///
/// When `POST /payments/order` fails, TWO things are true at once and the user
/// needs both:
///
///   1. The payment did not start.
///   2. A booking WAS created, and it is saved.
///
/// The failure used to be reported by a banner below the price card — off
/// screen on a 360px phone — while this bar went on showing an unchanged "Pay"
/// button. So the customer tapped Pay, watched nothing happen, and had no way
/// to know a real booking now existed in their account.
///
/// The bar is where the eye is and where the action is, so the state belongs
/// here. Once a booking exists the offer changes from "Pay" to "Try again",
/// and a second route out appears — because a customer who cannot pay right now
/// must still be able to leave without abandoning a booking they do not know
/// they have.
/// ─────────────────────────────────────────────────────────────────────────
class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.total,
    required this.isBusy,
    required this.stageLabel,
    required this.onPay,
    this.failed = false,
    this.bookingExists = false,
    this.onViewBooking,
  });

  final Money? total;
  final bool isBusy;
  final String? stageLabel;
  final VoidCallback onPay;

  /// The last payment attempt did not complete.
  final bool failed;

  /// A booking has been created and is held as pending payment.
  final bool bookingExists;

  final VoidCallback? onViewBooking;

  @override
  Widget build(BuildContext context) {
    final showRecovery = failed && bookingExists;

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
              if (showRecovery) ...[
                // Stated where it cannot be missed: the booking is real.
                Row(
                  children: [
                    const Icon(Icons.bookmark_added_outlined,
                        size: AppSizes.iconSm, color: AppColors.warningBright),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Your booking is saved and waiting for payment. '
                        'The slot is yours until then.',
                        style: context.text.bodySmall
                            ?.copyWith(color: AppColors.warningBright),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stageLabel ?? 'Total',
                          style: context.text.bodySmall
                              ?.copyWith(color: AppColors.inkMutedDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          total?.display ?? 'Confirmed at payment',
                          style: context.text.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(
                    width: 160,
                    child: PrimaryButton(
                      label: showRecovery ? 'Try again' : 'Pay',
                      icon: showRecovery ? Icons.refresh_rounded : Icons.lock_rounded,
                      isLoading: isBusy,
                      onPressed: isBusy ? null : onPay,
                    ),
                  ),
                ],
              ),
              if (showRecovery && onViewBooking != null) ...[
                const SizedBox(height: AppSpacing.xs),
                // The way out that does not abandon the booking.
                TertiaryButton(
                  label: 'View booking instead',
                  onPressed: onViewBooking,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldGoneView extends StatelessWidget {
  const _HoldGoneView({required this.onPickAgain});

  final VoidCallback onPickAgain;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      title: 'Your hold expired',
      message: 'The slot was released so someone else could book it. '
          'Pick a slot again — it may still be free.',
      icon: Icons.timer_off_outlined,
      action: SizedBox(
        width: 220,
        child: PrimaryButton(label: 'Pick a slot', onPressed: onPickAgain),
      ),
    );
  }
}
