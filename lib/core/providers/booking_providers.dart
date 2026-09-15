// ─────────────────────────────────────────────────────────────────────────────
// BOOKING PROVIDERS
//
// State for the whole reservation journey: window → slot → hold → booking →
// payment → confirmation.
//
// Two things drive the design:
//
//   1. THE SERVER IS THE CLOCK. The hold countdown ticks locally for smoothness,
//      but every decision about whether the hold is still alive is made against the
//      server's `expires_at`. A device that was asleep for two minutes wakes up to
//      an expired hold, not to two extra minutes.
//
//   2. THE SERVER IS THE TRUTH. No provider here computes a price, a booking code,
//      an availability count or a payment state. Each is read from a response.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/booking/data/booking_repository.dart';
import '../../features/booking/data/checkout_service.dart';
import '../../shared/models/availability.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/parking.dart';
import '../network/api_exception.dart';
import '../realtime/realtime_service.dart';
import 'core_providers.dart';
import 'discovery_providers.dart';

/* ── infrastructure ────────────────────────────────────────────────────────── */

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(apiClientProvider));
});

final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  final service = CheckoutService();
  ref.onDispose(service.dispose);
  return service;
});

/// The app's single socket.
///
/// Connected once the user is signed in and reconnected when that changes, because
/// the private rooms the server grants depend on the token in the handshake.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref.watch(apiClientProvider).freshAccessToken);

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.status == next.status) return;
    if (next.status == AuthStatus.signedIn) {
      service.reauthenticate();
    } else if (next.status == AuthStatus.signedOut) {
      service.disconnect();
    }
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  return service;
});

/// Live slot updates for one lot, folded into the layout the screen is showing.
///
/// Returns the same layout object when an event is for a slot that is not on
/// screen, so an unrelated update does not rebuild the grid.
final liveSlotLayoutProvider = StreamProvider.autoDispose
    .family<SlotLayout, BookingDraft>((ref, draft) async* {
  final initial = await ref.watch(slotLayoutProvider(draft).future);
  var current = initial;
  yield current;

  final realtime = ref.watch(realtimeServiceProvider);
  await realtime.connect();
  final room = realtime.subscribeToParking(
    parkingAreaId: draft.parkingAreaId,
    vehicleType: draft.vehicleType.wire,
  );
  ref.onDispose(() => realtime.unsubscribeFromParking(room));

  await for (final event in realtime.slotUpdates) {
    if (event.parkingAreaId != draft.parkingAreaId) continue;
    if (event.vehicleType != draft.vehicleType.wire) continue;
    if (current.findById(event.slotId) == null) continue;

    current = current.withSlotUpdate(
      slotId: event.slotId,
      status: SlotStatus.parse(event.status),
      heldByYou: event.heldByYou,
      holdExpiresAt: event.expiresAt,
    );
    yield current;
  }
});

/* ── the booking draft ─────────────────────────────────────────────────────── */

/// What the customer has chosen so far.
///
/// Held separately from the hold itself because the window and vehicle are chosen
/// *before* a slot is picked, and changing the window has to re-query availability
/// and invalidate any slot already selected.
@immutable
class BookingDraft {
  const BookingDraft({
    required this.parkingAreaId,
    required this.vehicleType,
    required this.startAt,
    required this.durationMinutes,
    this.selectedSlotId,
    this.vehicleId,
    this.numberPlate,
  });

  final int parkingAreaId;
  final VehicleType vehicleType;
  final DateTime startAt;
  final int durationMinutes;

  /// Null until the customer taps a slot.
  final int? selectedSlotId;

  final int? vehicleId;
  final String? numberPlate;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  bool get hasSlot => selectedSlotId != null;
  bool get hasVehicle => vehicleId != null || (numberPlate?.trim().isNotEmpty ?? false);

  /// Everything needed to take a hold.
  bool get canHold => hasSlot;

  /// Everything needed to turn a hold into a booking.
  bool get canBook => hasSlot && hasVehicle;

  BookingDraft copyWith({
    VehicleType? vehicleType,
    DateTime? startAt,
    int? durationMinutes,
    int? selectedSlotId,
    bool clearSlot = false,
    int? vehicleId,
    bool clearVehicleId = false,
    String? numberPlate,
    bool clearNumberPlate = false,
  }) =>
      BookingDraft(
        parkingAreaId: parkingAreaId,
        vehicleType: vehicleType ?? this.vehicleType,
        startAt: startAt ?? this.startAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        selectedSlotId: clearSlot ? null : (selectedSlotId ?? this.selectedSlotId),
        vehicleId: clearVehicleId ? null : (vehicleId ?? this.vehicleId),
        numberPlate: clearNumberPlate ? null : (numberPlate ?? this.numberPlate),
      );

  /// The key availability is cached under. Rounded to the minute so a rebuild does
  /// not refetch because a few hundred milliseconds passed.
  String get availabilityKey =>
      '$parkingAreaId|${vehicleType.wire}|'
      '${startAt.toUtc().toIso8601String().substring(0, 16)}|$durationMinutes';
}

class BookingDraftController extends StateNotifier<BookingDraft> {
  BookingDraftController(super.initial);

  /// Changing the window invalidates the chosen slot: the layout is about to be
  /// refetched and that slot may no longer be free. Silently keeping it selected
  /// would show a selection the server might refuse.
  void setWindow({DateTime? startAt, int? durationMinutes}) {
    if (startAt == null && durationMinutes == null) return;
    state = state.copyWith(
      startAt: startAt,
      durationMinutes: durationMinutes,
      clearSlot: true,
    );
  }

  void setVehicleType(VehicleType type) {
    if (type == state.vehicleType) return;
    // A different vehicle type is a different set of slots entirely.
    state = state.copyWith(vehicleType: type, clearSlot: true);
  }

  void selectSlot(int? slotId) {
    state = slotId == null ? state.copyWith(clearSlot: true) : state.copyWith(selectedSlotId: slotId);
  }

  void setVehicle({int? vehicleId, String? numberPlate}) {
    state = state.copyWith(
      vehicleId: vehicleId,
      clearVehicleId: vehicleId == null,
      numberPlate: numberPlate,
      clearNumberPlate: numberPlate == null,
    );
  }
}

/// Created per parking area. `autoDispose` so backing out of a lot discards the
/// draft rather than carrying a stale window into the next one.
final bookingDraftProvider = StateNotifierProvider.autoDispose
    .family<BookingDraftController, BookingDraft, BookingDraftSeed>((ref, seed) {
  // Kept alive briefly so navigating Slot → Review → back does not reset the draft.
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 20), link.close);
  ref.onDispose(timer.cancel);

  return BookingDraftController(
    BookingDraft(
      parkingAreaId: seed.parkingAreaId,
      vehicleType: seed.vehicleType,
      startAt: seed.startAt,
      durationMinutes: seed.durationMinutes,
    ),
  );
});

/// Family key. A record would do, but a class with value equality documents the
/// fields and keeps the provider from being re-created on an equivalent seed.
@immutable
class BookingDraftSeed {
  const BookingDraftSeed({
    required this.parkingAreaId,
    required this.vehicleType,
    required this.startAt,
    required this.durationMinutes,
  });

  final int parkingAreaId;
  final VehicleType vehicleType;
  final DateTime startAt;
  final int durationMinutes;

  @override
  bool operator ==(Object other) =>
      other is BookingDraftSeed &&
      other.parkingAreaId == parkingAreaId &&
      other.vehicleType == vehicleType &&
      other.durationMinutes == durationMinutes &&
      // To the minute: two seeds a few hundred ms apart are the same intent.
      other.startAt.difference(startAt).inMinutes == 0;

  @override
  int get hashCode => Object.hash(parkingAreaId, vehicleType, durationMinutes);
}

/* ── availability ──────────────────────────────────────────────────────────── */

/// Slot layout for a draft's window.
///
/// Keyed on the draft rather than on the parking id, so changing the time refetches
/// instead of showing a layout computed for a different window — which is exactly
/// how the old app could offer a slot that was already booked.
final slotLayoutProvider =
    FutureProvider.autoDispose.family<SlotLayout, BookingDraft>((ref, draft) async {
  final repository = ref.watch(bookingRepositoryProvider);

  return repository.availability(
    parkingAreaId: draft.parkingAreaId,
    vehicleType: draft.vehicleType,
    startAt: draft.startAt,
    durationMinutes: draft.durationMinutes,
  );
});

/* ── the hold ──────────────────────────────────────────────────────────────── */

/// What the UI needs to render the countdown and decide what is possible.
@immutable
class HoldState {
  const HoldState({
    this.hold,
    this.isWorking = false,
    this.error,
    this.secondsRemaining = 0,
    this.expiredJustNow = false,
  });

  const HoldState.idle() : this();

  final SlotHold? hold;
  final bool isWorking;
  final ApiException? error;

  /// Recomputed on every tick from the server's `expires_at`.
  final int secondsRemaining;

  /// Set for one state emission when the hold lapses, so the screen can react once
  /// rather than on every subsequent rebuild.
  final bool expiredJustNow;

  bool get hasHold => hold != null && secondsRemaining > 0;
  bool get isExpiring => hasHold && secondsRemaining <= 30;

  /// "1:58"
  String get countdownLabel {
    final m = secondsRemaining ~/ 60;
    final s = secondsRemaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  HoldState copyWith({
    SlotHold? hold,
    bool clearHold = false,
    bool? isWorking,
    ApiException? error,
    bool clearError = false,
    int? secondsRemaining,
    bool? expiredJustNow,
  }) =>
      HoldState(
        hold: clearHold ? null : (hold ?? this.hold),
        isWorking: isWorking ?? this.isWorking,
        error: clearError ? null : (error ?? this.error),
        secondsRemaining: clearHold ? 0 : (secondsRemaining ?? this.secondsRemaining),
        expiredJustNow: expiredJustNow ?? false,
      );
}

/// Owns the live hold and its countdown.
///
/// The timer exists only to redraw the number. Expiry is decided by comparing
/// against the server's instant, which is why backgrounding the app cannot buy more
/// time: on resume the next tick computes the true remainder, which may be zero.
class HoldController extends StateNotifier<HoldState> {
  HoldController(this._repository) : super(const HoldState.idle()) {
    _restore();
  }

  final BookingRepository _repository;
  Timer? _ticker;

  /// Restores a hold taken before the app was killed, so the customer returns to a
  /// running countdown rather than to a screen that forgot.
  Future<void> _restore() async {
    try {
      final hold = await _repository.currentHold();
      if (!mounted) return;
      if (hold != null && !hold.isExpired()) {
        _adopt(hold);
      }
    } on ApiException {
      // No hold to restore is the common case and not worth surfacing.
    }
  }

  Future<bool> take({
    required int parkingAreaId,
    required int slotId,
    required DateTime startAt,
    required int durationMinutes,
  }) async {
    state = state.copyWith(isWorking: true, clearError: true);
    try {
      final hold = await _repository.createHold(
        parkingAreaId: parkingAreaId,
        slotId: slotId,
        startAt: startAt,
        durationMinutes: durationMinutes,
      );
      if (!mounted) return false;
      _adopt(hold);
      state = state.copyWith(isWorking: false);
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isWorking: false, error: e);
      return false;
    }
  }

  Future<bool> extend() async {
    final current = state.hold;
    if (current == null || !current.canExtend) return false;

    state = state.copyWith(isWorking: true, clearError: true);
    try {
      final hold = await _repository.extendHold(current.id);
      if (!mounted) return false;
      _adopt(hold);
      state = state.copyWith(isWorking: false);
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isWorking: false, error: e);
      return false;
    }
  }

  /// Gives the slot back. Called when the customer leaves the flow deliberately —
  /// not when they merely navigate back, because they may return.
  Future<void> release() async {
    final current = state.hold;
    _stopTicker();
    state = const HoldState.idle();
    if (current == null) return;
    try {
      await _repository.releaseHold(current.id);
    } on ApiException {
      // The hold expires on its own within seconds anyway.
    }
  }

  /// Called once the hold has become a booking: the slot is no longer held, it is
  /// booked, so the countdown must stop without releasing anything.
  void consumed() {
    _stopTicker();
    state = const HoldState.idle();
  }

  /// The server told us, over the socket, that this hold is gone.
  void invalidatedByServer(int holdId) {
    if (state.hold?.id != holdId) return;
    _stopTicker();
    state = const HoldState().copyWith(expiredJustNow: true);
  }

  void _adopt(SlotHold hold) {
    state = HoldState(hold: hold, secondsRemaining: hold.secondsRemaining());
    _startTicker();
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final hold = state.hold;
    if (hold == null) {
      _stopTicker();
      return;
    }

    // Recomputed from the server instant every second — never decremented, because
    // a decrementing counter drifts and cannot notice that the app was asleep.
    final remaining = hold.secondsRemaining();

    if (remaining <= 0) {
      _stopTicker();
      state = const HoldState().copyWith(expiredJustNow: true);
      return;
    }

    if (remaining != state.secondsRemaining) {
      state = state.copyWith(secondsRemaining: remaining);
    }
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

/// One hold at a time, app-wide — which mirrors the server, where taking a second
/// hold releases the first.
final holdControllerProvider = StateNotifierProvider<HoldController, HoldState>((ref) {
  final controller = HoldController(ref.watch(bookingRepositoryProvider));

  // The server's word on expiry. A device whose timer stalled — backgrounded, or
  // throttled by the OS — learns immediately rather than continuing to show a
  // countdown for a slot that has already been released to someone else.
  final subscription = ref
      .watch(realtimeServiceProvider)
      .holdExpiries
      .listen((event) => controller.invalidatedByServer(event.holdId));
  ref.onDispose(subscription.cancel);

  return controller;
});

/* ── payment ───────────────────────────────────────────────────────────────── */

/// Where the payment attempt has got to. Each value maps to a distinct thing the
/// screen says; there is no state that means "probably fine".
enum PaymentStage {
  idle,

  /// Asking the server to create an order.
  creatingOrder,

  /// The gateway sheet is open.
  atGateway,

  /// The gateway returned; the server is checking the signature.
  verifying,

  /// The server confirmed the booking.
  confirmed,

  /// The attempt ended without a confirmed booking. The booking is still payable.
  failed,
}

@immutable
class PaymentState {
  const PaymentState({
    this.stage = PaymentStage.idle,
    this.booking,
    this.error,
    this.message,
    this.refundDue = false,
  });

  final PaymentStage stage;
  final Booking? booking;
  final ApiException? error;

  /// A plain-language note for the failure case. Never a gateway payload.
  final String? message;

  /// Money was received for a booking it could not confirm: the booking closed
  /// first. The server has recorded the refund owed; paying again cannot help.
  final bool refundDue;

  bool get isBusy =>
      stage == PaymentStage.creatingOrder ||
      stage == PaymentStage.atGateway ||
      stage == PaymentStage.verifying;
}

/// Runs order → gateway → verify, and reports only what the server concluded.
class PaymentController extends StateNotifier<PaymentState> {
  PaymentController(this._repository, this._checkout, this._ref)
      : super(const PaymentState());

  final BookingRepository _repository;
  final CheckoutService _checkout;
  final Ref _ref;

  /// Reused across retries of the same booking, so a retried order creation cannot
  /// produce a second order.
  String? _orderKey;

  Future<void> pay({required Booking booking}) async {
    _orderKey ??= newIdempotencyKey();

    state = const PaymentState(stage: PaymentStage.creatingOrder);

    final PaymentOrder order;
    try {
      order = await _repository.createPaymentOrder(
        bookingId: booking.id,
        idempotencyKey: _orderKey!,
      );
    } on ApiException catch (e) {
      state = PaymentState(stage: PaymentStage.failed, error: e);
      return;
    }

    state = const PaymentState(stage: PaymentStage.atGateway);

    final result = await _checkout.open(order: order);

    switch (result.outcome) {
      case CheckoutOutcome.returned:
        await _verify(booking: booking, order: order, result: result);

      case CheckoutOutcome.cancelled:
        // Closing the sheet is not a declined card, but it is not a booking either.
        // Returning silently to "Pay" left people unsure whether they had booked;
        // the booking exists, the spot is held for now, and trying again is one tap.
        await _reportFailure(booking, order, 'cancelled_by_user');
        state = PaymentState(stage: PaymentStage.failed, booking: booking);

      case CheckoutOutcome.failed:
        await _reportFailure(booking, order, result.message ?? 'payment_failed');
        state = PaymentState(stage: PaymentStage.failed, booking: booking, message: result.message);

      case CheckoutOutcome.unavailable:
        state = PaymentState(
          stage: PaymentStage.failed,
          message: result.message ?? 'Payments are not available right now.',
        );
    }
  }

  Future<void> _verify({
    required Booking booking,
    required PaymentOrder order,
    required CheckoutResult result,
  }) async {
    state = const PaymentState(stage: PaymentStage.verifying);

    // An external wallet hands back no signature: the payment completes outside the
    // app and the webhook tells the server. Ask the server what happened rather
    // than assuming either outcome.
    if (!result.hasSignature) {
      await _awaitServerConfirmation(booking);
      return;
    }

    try {
      final answer = await _repository.verifyPayment(
        bookingId: booking.id,
        orderId: result.orderId!,
        paymentId: result.paymentId!,
        signature: result.signature!,
      );
      // A verified payment has not necessarily bought the booking: one that lands
      // after the booking expired is owed back. The booking's status decides.
      if (answer.status.isSecured) {
        _onConfirmed(answer);
      } else if (answer.payment.isPaid) {
        _onRefundDue(answer);
      } else {
        await _awaitServerConfirmation(booking);
      }
    } on ApiException catch (e) {
      // The device thinks it paid and the server disagrees. Rather than choosing a
      // side, ask the provider — that is what reconcile is for.
      await _awaitServerConfirmation(booking, fallbackError: e);
    }
  }

  /// Polls the server for a booking the webhook may confirm.
  ///
  /// Bounded: four attempts over roughly twelve seconds. If it has not confirmed by
  /// then the customer is told it is still being checked — which is true — rather
  /// than being shown a success screen on the strength of a guess.
  Future<void> _awaitServerConfirmation(Booking booking, {ApiException? fallbackError}) async {
    const delays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 5)];

    for (final delay in delays) {
      await Future<void>.delayed(delay);
      if (!mounted) return;

      try {
        final current = await _repository.reconcilePayment(booking.id);
        if (current.status.isSecured) {
          _onConfirmed(current);
          return;
        }
        // Paid, but for a booking that closed first. "Is paid" alone used to be
        // read as booked, and showed a success screen for an expired booking.
        if (current.payment.isPaid) {
          _onRefundDue(current);
          return;
        }
      } on ApiException {
        // Keep trying; a transient failure here is not the answer.
      }
    }

    if (!mounted) return;
    state = PaymentState(
      stage: PaymentStage.failed,
      error: fallbackError,
      message: fallbackError == null
          ? 'We are still confirming your payment. Check Bookings in a moment — '
              'if money was taken, your booking will appear there.'
          : null,
    );
  }

  Future<void> _reportFailure(Booking booking, PaymentOrder order, String reason) async {
    try {
      await _repository.reportPaymentFailure(
        bookingId: booking.id,
        orderId: order.providerOrderId,
        reason: reason,
      );
    } on ApiException {
      // Best effort: the sweeper releases the slot regardless.
    }
  }

  void _onConfirmed(Booking booking) {
    state = PaymentState(stage: PaymentStage.confirmed, booking: booking);
    _orderKey = null;

    // The hold became a booking two steps ago; stop any lingering countdown.
    _ref.read(holdControllerProvider.notifier).consumed();
    _invalidateBookings();
  }

  void _onRefundDue(Booking booking) {
    state = PaymentState(stage: PaymentStage.failed, booking: booking, refundDue: true);
    _orderKey = null;
    _invalidateBookings();
  }

  /// Bookings, the tab badges and the Home active-parking card are all now stale.
  void _invalidateBookings() {
    _ref.invalidate(bookingCountsProvider);
    _ref.invalidate(currentBookingProvider);
    for (final bucket in BookingBucket.values) {
      _ref.invalidate(bookingListProvider(bucket));
    }
  }

  void reset() {
    state = const PaymentState();
  }
}

final paymentControllerProvider =
    StateNotifierProvider.autoDispose<PaymentController, PaymentState>((ref) {
  return PaymentController(
    ref.watch(bookingRepositoryProvider),
    ref.watch(checkoutServiceProvider),
    ref,
  );
});

/* ── booking lists ─────────────────────────────────────────────────────────── */

final bookingListProvider =
    FutureProvider.autoDispose.family<List<Booking>, BookingBucket>((ref, bucket) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.listBookings(bucket: bucket);
});

final bookingCountsProvider = FutureProvider.autoDispose<BookingCounts>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.counts();
});

final bookingDetailProvider =
    FutureProvider.autoDispose.family<Booking, int>((ref, bookingId) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.booking(bookingId);
});

/// The active-parking session shown on Home.
///
/// Refreshed on a timer while something is in progress, because elapsed time and
/// the projected charge are computed server-side and would otherwise go stale on
/// a screen someone is watching.
final currentBookingProvider = FutureProvider.autoDispose<Booking?>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  final booking = await repository.currentBooking();

  if (booking != null && booking.isParked) {
    final timer = Timer(const Duration(seconds: 60), () => ref.invalidateSelf());
    ref.onDispose(timer.cancel);
  }

  return booking;
});

final cancellationPreviewProvider =
    FutureProvider.autoDispose.family<CancellationPreview, int>((ref, bookingId) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.cancellationPreview(bookingId);
});

/* ── booking actions ───────────────────────────────────────────────────────── */

/// Cancel / check-in / check-out, with the invalidation each implies.
///
/// Kept out of the widgets so a screen cannot forget to refresh the lists after
/// changing something — a recurring defect in the old app, where cancelling left
/// the cancelled booking on screen until a manual pull-to-refresh.
class BookingActionsController {
  BookingActionsController(this._repository, this._ref);

  final BookingRepository _repository;
  final Ref _ref;

  Future<Booking> cancel(int bookingId, {String? reason}) async {
    final booking = await _repository.cancelBooking(bookingId, reason: reason);
    _invalidateAll(bookingId);
    return booking;
  }

  Future<Booking> checkIn(int bookingId) async {
    final booking = await _repository.checkIn(bookingId);
    _invalidateAll(bookingId);
    return booking;
  }

  Future<Booking> checkOut(int bookingId) async {
    final booking = await _repository.checkOut(bookingId);
    _invalidateAll(bookingId);
    return booking;
  }

  void _invalidateAll(int bookingId) {
    _ref.invalidate(bookingDetailProvider(bookingId));
    _ref.invalidate(bookingCountsProvider);
    _ref.invalidate(currentBookingProvider);
    _ref.invalidate(cancellationPreviewProvider(bookingId));
    for (final bucket in BookingBucket.values) {
      _ref.invalidate(bookingListProvider(bucket));
    }
  }
}

final bookingActionsProvider = Provider<BookingActionsController>((ref) {
  return BookingActionsController(ref.watch(bookingRepositoryProvider), ref);
});

/// Keeps discovery honest when an operator reconfigures a lot mid-session.
///
/// Price, hours and capacity are all things a customer may be looking at when the
/// operator changes them. Invalidating the detail — rather than patching it from
/// the event — means the next read is the server's current truth, including a lot
/// that has just become closed or full.
/// Keeps the socket in a lot's room while a screen shows that lot, so an
/// operator's change to its hours, amenities, photos or price reaches the page
/// being read (through [parkingConfigSyncProvider]) instead of waiting for the
/// next visit. Watched by the lot page; released when it closes.
final parkingRoomProvider = Provider.autoDispose.family<void, int>((ref, parkingAreaId) {
  final realtime = ref.watch(realtimeServiceProvider);
  unawaited(realtime.connect());
  final room = realtime.subscribeToParking(parkingAreaId: parkingAreaId, vehicleType: 'all');
  ref.onDispose(() => realtime.unsubscribeFromParking(room));
});

final parkingConfigSyncProvider = Provider<void>((ref) {
  final subscription =
      ref.watch(realtimeServiceProvider).configChanges.listen((event) {
    ref.invalidate(parkingDetailProvider(event.parkingAreaId));
    // A price or capacity change moves the numbers on every card, not just the
    // one being viewed.
    if (event.change == 'capacity' || event.change == 'pricing') {
      ref.invalidate(nearbyParkingProvider);
    }
  });
  ref.onDispose(subscription.cancel);
});

/// Keeps the booking screens in step with server-side changes.
///
/// The operator checking someone in, or a webhook confirming a payment, both
/// happen without the app asking. Without this the customer sits looking at a
/// stale screen until they pull to refresh.
final bookingRealtimeSyncProvider = Provider<void>((ref) {
  final realtime = ref.watch(realtimeServiceProvider);

  void refreshLists() {
    ref.invalidate(bookingCountsProvider);
    ref.invalidate(currentBookingProvider);
    for (final bucket in BookingBucket.values) {
      ref.invalidate(bookingListProvider(bucket));
    }
  }

  final updates = realtime.bookingUpdates.listen((event) {
    ref.invalidate(bookingDetailProvider(event.bookingId));
    refreshLists();
  });

  // After a reconnect nothing says what changed during the gap, so everything
  // that shows server state is refetched: every open booking, the lists, and
  // any live floor plan.
  final resyncs = realtime.resyncs.listen((_) {
    ref.invalidate(bookingDetailProvider);
    ref.invalidate(slotLayoutProvider);
    refreshLists();
  });

  ref.onDispose(() {
    updates.cancel();
    resyncs.cancel();
  });
});
