// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM AND PAY
//
// The held spot, the time, the vehicle and the exact price — then Pay.
//
// Pay does two real things in order: it creates the booking (consuming the
// hold), then asks the payment controller to take the money. Both answers come
// from the server; this screen never declares success on its own.
//
// Two traps this screen is built around:
//   · A successful booking CONSUMES the hold, so the live hold becomes null the
//     moment the booking exists. The screen keeps rendering from a snapshot —
//     otherwise it would announce an expired hold over a real booking.
//   · If payment then fails, the booking still exists. The pay bar says so, and
//     offers to try again or to open the booking, instead of implying the spot
//     was lost.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/discovery_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/models/money.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../auth/presentation/profile_setup_screen.dart' show UpperCaseTextFormatter;
import '../data/booking_repository.dart';
import 'hold_countdown_bar.dart';

class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({super.key});

  @override
  ConsumerState<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen> {
  /// One key per attempt: a double tap cannot create two bookings.
  final String _idempotencyKey = newIdempotencyKey();

  final TextEditingController _plateController = TextEditingController();
  int? _selectedVehicleId;
  bool _useNewPlate = false;

  bool _isSubmitting = false;
  String? _plateError;

  /// Set once the booking exists; retries pay for this booking.
  Booking? _booking;

  /// The hold as it was when the booking consumed it. See the header.
  SlotHold? _consumedHold;

  /// Set when this screen hands over to the confirmation, so the payment result
  /// and the server's booking update cannot both navigate.
  bool _leaving = false;

  void _showConfirmed(Booking booking) {
    if (_leaving || !mounted) return;
    _leaving = true;
    context.pushReplacement(Routes.bookingConfirmation(booking.id), extra: booking);
  }

  @override
  void initState() {
    super.initState();
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

    // Payment confirmed by the server: replace this screen, so Back cannot
    // return to paying for a booking that is already paid.
    ref.listen(paymentControllerProvider, (previous, next) {
      final booking = next.booking;
      if (next.stage == PaymentStage.confirmed && booking != null) _showConfirmed(booking);
    });

    // The server can confirm a booking this screen last saw fail — a payment
    // that completed after the app stopped waiting, reported by webhook. Its
    // word wins: without this the screen kept offering "Try again" on a booking
    // that was already paid.
    final saved = _booking;
    if (saved != null) {
      ref.listen(bookingDetailProvider(saved.id), (previous, next) {
        final fresh = next.valueOrNull;
        if (fresh != null && fresh.status == BookingStatus.confirmed) _showConfirmed(fresh);
      });
    }

    // The hold lapsed before a booking existed: nothing is left to review.
    ref.listen(holdControllerProvider, (previous, next) {
      if (next.expiredJustNow && mounted && _booking == null) _onHoldExpired();
    });

    final hold = holdState.hold ?? _consumedHold;

    if (hold == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyStateView(
          title: 'Your hold ran out',
          message: 'The spot was released so someone else could book it. '
              'Pick a spot again — it may still be free.',
          icon: Icons.timer_off_outlined,
          action: PrimaryButton(
            label: 'Pick a spot',
            expand: false,
            onPressed: () => context.pop(),
          ),
        ),
      );
    }

    final failed = payment.stage == PaymentStage.failed;
    final place = ref.watch(parkingDetailProvider(hold.parkingAreaId)).valueOrNull;
    final photo = place?.summary.coverPhotoUrl ??
        (place != null && place.photos.isNotEmpty ? place.photos.first.url : null);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Confirm and pay'),
        actions: [
          // Only while a HOLD keeps the spot. Once the booking exists the booking
          // keeps it, and a ticking timer would suggest the opposite.
          if (_booking == null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.pageInset),
              child: Center(child: HoldCountdownPill(state: holdState)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          if (holdState.isExpiring && _booking == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageInset,
                AppSpacing.sm,
                AppSpacing.pageInset,
                AppSpacing.sm,
              ),
              child: InlineBanner(
                message: 'Your spot is released in ${holdState.countdownLabel}. Pay now to keep it.',
                tone: BannerTone.warning,
                actionLabel: hold.canExtend ? 'Hold it longer' : null,
                onAction: hold.canExtend
                    ? () => ref.read(holdControllerProvider.notifier).extend()
                    : null,
              ),
            ),
          _PlaceHeader(hold: hold, photoUrl: photo),
          const Hairline(indent: AppSpacing.pageInset, endIndent: AppSpacing.pageInset),
          const _SectionTitle('Your parking'),
          _WhenRows(hold: hold),
          const Hairline(indent: AppSpacing.pageInset, endIndent: AppSpacing.pageInset),
          const _SectionTitle('Vehicle'),
          if (_booking != null)
            // The booking exists, so its vehicle is settled; showing the chooser
            // (now also listing the plate just saved to the account) would read
            // as two vehicles.
            ListRow(
              icon: _booking!.vehicle.type.wire == 'bike'
                  ? Icons.two_wheeler_rounded
                  : Icons.directions_car_filled_rounded,
              title: _booking!.vehicle.displayPlate ?? _booking!.vehicle.type.label,
              subtitle: 'On this booking',
              trailing: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkTertiary),
            )
          else
          _VehicleChooser(
            vehicles: vehicles
                .where((v) => v.vehicleType.wire == hold.slot.vehicleType.wire)
                .toList(growable: false),
            selectedVehicleId: _selectedVehicleId,
            useNewPlate: _useNewPlate,
            plateController: _plateController,
            plateError: _plateError,
            locked: _booking != null,
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
          const Hairline(indent: AppSpacing.pageInset, endIndent: AppSpacing.pageInset),
          const _SectionTitle('Price'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: hold.quote != null
                ? _PriceBreakdown(quote: hold.quote!)
                : const InlineBanner(message: 'The exact amount is confirmed when payment starts.'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            child: Text(
              'Staying past your booked time is charged at this place\'s overstay rate. '
              'If you cancel, the refund depends on how close to arrival you cancel — '
              'you see the exact amount before confirming.',
              style: context.text.bodySmall,
            ),
          ),
          if (failed && _booking == null) ...[
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
              child: InlineBanner(
                message: payment.message ??
                    payment.error?.message ??
                    'The payment did not complete. You can try again.',
                tone: BannerTone.danger,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _PayBar(
        failed: failed,
        failureMessage: payment.message ?? payment.error?.message,
        bookingExists: _booking != null,
        onViewBooking: _booking == null
            ? null
            : () => openBookingAfterFlow(context, _booking!.id),
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
        return 'Confirming with your bank…';
      case PaymentStage.idle:
      case PaymentStage.confirmed:
      case PaymentStage.failed:
        return null;
    }
  }

  /* ── submit ────────────────────────────────────────────────────────────── */

  Future<void> _submit() async {
    // Once the booking exists the hold is gone by design; a retry must not
    // require a live hold.
    final hold = ref.read(holdControllerProvider).hold ?? _consumedHold;
    if (hold == null) {
      _onHoldExpired();
      return;
    }

    final plate = _plateController.text.trim().toUpperCase().replaceAll(' ', '');
    if (_booking == null && _useNewPlate && plate.length < 4) {
      setState(() => _plateError = 'Enter your vehicle number');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _plateError = null;
    });

    // Step 1: the booking — unless a previous attempt already created it.
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

        // Snapshot first: consuming nulls the controller's hold, and this screen
        // still needs its spot, window and quote.
        _consumedHold = hold;
        ref.read(holdControllerProvider.notifier).consumed();

        // A typed plate was saved as a vehicle; refresh the account's list.
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

    // Step 2: pay. The controller reports only what the server concluded.
    await ref.read(paymentControllerProvider.notifier).pay(booking: booking);
  }

  void _showError(ApiException e) {
    final lostSpot = e.code == 'SLOT_UNAVAILABLE' ||
        e.code == 'SLOT_HELD_BY_ANOTHER' ||
        e.code == 'TIME_OVERLAP' ||
        e.code == 'HOLD_EXPIRED';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(e.message),
        duration: const Duration(seconds: 4),
        action: lostSpot
            ? SnackBarAction(label: 'Pick another', onPressed: () => context.pop())
            : null,
      ));
  }

  void _onHoldExpired() {
    showToast(context, 'Your hold ran out and the spot was released.');
    if (context.canPop()) context.pop();
  }
}

/* ── sections ──────────────────────────────────────────────────────────────── */

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        AppSpacing.xl,
        AppSpacing.pageInset,
        AppSpacing.xs,
      ),
      child: Text(title, style: context.text.headlineSmall),
    );
  }
}

class _PlaceHeader extends StatelessWidget {
  const _PlaceHeader({required this.hold, required this.photoUrl});

  final SlotHold hold;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        AppSpacing.md,
        AppSpacing.pageInset,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          ParqxPhoto(url: photoUrl, seed: hold.parkingName ?? 'Parking', width: 64, height: 64),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hold.parkingName ?? 'Parking',
                  style: context.text.headlineSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${hold.slot.vehicleType.label} · Spot ${hold.slot.code}',
                  style: context.text.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhenRows extends StatelessWidget {
  const _WhenRows({required this.hold});

  final SlotHold hold;

  @override
  Widget build(BuildContext context) {
    final start = hold.entryTime;
    final end = start.add(Duration(minutes: hold.durationMinutes));
    final now = DateTime.now();
    final isToday = start.year == now.year && start.month == now.month && start.day == now.day;
    final sameDay = start.day == end.day && start.month == end.month;
    final day = isToday ? 'Today' : DateFormat('EEE d MMM').format(start);
    final range = sameDay
        ? '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}'
        : '${DateFormat('h:mm a').format(start)} – ${DateFormat('EEE h:mm a').format(end)}';
    final row = hold.slot.rowLabel ??
        (RegExp(r'^[A-Za-z]').hasMatch(hold.slot.code) ? hold.slot.code[0].toUpperCase() : null);

    return Column(
      children: [
        ListRow(
          icon: Icons.schedule_rounded,
          title: '$day, $range',
          subtitle: _duration(hold.durationMinutes),
        ),
        ListRow(
          icon: Icons.local_parking_rounded,
          title: 'Spot ${hold.slot.code}',
          subtitle: [if (row != null) 'Row $row', _classLabel(hold.slot.slotClass)].join(' · '),
        ),
      ],
    );
  }

  static String _classLabel(String slotClass) => switch (slotClass) {
        'ev' => 'EV charging',
        'accessible' => 'Accessible',
        'compact' => 'Compact',
        'valet' => 'Valet',
        _ => 'Standard spot',
      };

  static String _duration(int minutes) {
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return '$h hour${h == 1 ? '' : 's'}';
    }
    if (minutes < 60) return '$minutes minutes';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}

class _VehicleChooser extends StatelessWidget {
  const _VehicleChooser({
    required this.vehicles,
    required this.selectedVehicleId,
    required this.useNewPlate,
    required this.plateController,
    required this.plateError,
    required this.locked,
    required this.onSelectVehicle,
    required this.onUseNewPlate,
  });

  final List<Vehicle> vehicles;
  final int? selectedVehicleId;
  final bool useNewPlate;
  final TextEditingController plateController;
  final String? plateError;

  /// After the booking exists its vehicle is fixed.
  final bool locked;

  final ValueChanged<int> onSelectVehicle;
  final VoidCallback onUseNewPlate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final vehicle in vehicles)
          _Choice(
            icon: vehicle.vehicleType.wire == 'bike'
                ? Icons.two_wheeler_rounded
                : Icons.directions_car_filled_rounded,
            title: vehicle.displayPlate,
            subtitle: vehicle.label ?? (vehicle.isDefault ? 'Default vehicle' : vehicle.vehicleType.label),
            selected: !useNewPlate && selectedVehicleId == vehicle.id,
            onTap: locked ? null : () => onSelectVehicle(vehicle.id),
          ),
        _Choice(
          icon: Icons.add_rounded,
          title: vehicles.isEmpty ? 'Enter your vehicle number' : 'Use another vehicle',
          subtitle: 'Saved to your account for next time',
          selected: useNewPlate,
          onTap: locked ? null : onUseNewPlate,
        ),
        if (useNewPlate)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              AppSpacing.xs,
              AppSpacing.pageInset,
              AppSpacing.md,
            ),
            child: AppTextField(
              controller: plateController,
              hint: 'e.g. KA 01 AB 1234',
              enabled: !locked,
              errorText: plateError,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 \-]')),
                UpperCaseTextFormatter(),
              ],
              prefixIcon: Icons.badge_outlined,
              maxLength: 16,
              style: AppTypography.code(size: 16, spacing: 1),
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      feedback: PressFeedback.selection,
      depth: PressDepth.subtle,
      borderRadius: BorderRadius.zero,
      semanticLabel: '$title, $subtitle${selected ? ', selected' : ''}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset, vertical: AppSpacing.md),
        child: Row(
          children: [
            IconDisc(icon: icon),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  Text(subtitle, style: context.text.bodyMedium),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.ink : AppColors.inkDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.quote});

  final PriceQuoteLite quote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InfoRow(
          label: '${quote.hourly.display}/hr × ${quote.billedHours} '
              'hour${quote.billedHours == 1 ? '' : 's'}',
          value: quote.subtotal.display,
        ),
        if (quote.isSurge)
          InfoRow(
            label: 'Busy-time pricing ×${quote.multiplier.toStringAsFixed(2)}',
            value: 'Included',
            labelColor: AppColors.warning,
          ),
        if (quote.hasPlatformFee) InfoRow(label: 'Service fee', value: quote.platformFee.display),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Hairline(),
        ),
        InfoRow(label: 'Total', value: quote.total.display, emphasise: true),
      ],
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.total,
    required this.isBusy,
    required this.stageLabel,
    required this.onPay,
    this.failed = false,
    this.failureMessage,
    this.bookingExists = false,
    this.onViewBooking,
  });

  final Money? total;
  final bool isBusy;
  final String? stageLabel;
  final VoidCallback onPay;
  final bool failed;
  final String? failureMessage;
  final bool bookingExists;
  final VoidCallback? onViewBooking;

  @override
  Widget build(BuildContext context) {
    final recovering = failed && bookingExists;
    return BottomActionBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (recovering) ...[
            InlineBanner(
              title: 'Booking saved — payment didn\'t go through',
              message: '${failureMessage ?? 'The payment did not complete.'} '
                  'Your spot stays reserved while the payment window is open.',
              tone: BannerTone.warning,
              icon: Icons.bookmark_added_outlined,
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
                    Text(stageLabel ?? 'Total', style: context.text.bodyMedium),
                    Text(
                      total?.display ?? '—',
                      style: AppTypography.numeric(size: 22, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PrimaryButton(
                label: recovering ? 'Try again' : (total == null ? 'Pay' : 'Pay ${total!.display}'),
                icon: recovering ? Icons.refresh_rounded : Icons.lock_outline_rounded,
                expand: false,
                isLoading: isBusy,
                onPressed: isBusy ? null : onPay,
              ),
            ],
          ),
          if (recovering && onViewBooking != null)
            TertiaryButton(label: 'View booking', onPressed: onViewBooking),
        ],
      ),
    );
  }
}
