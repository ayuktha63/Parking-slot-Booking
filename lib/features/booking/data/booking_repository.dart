// ─────────────────────────────────────────────────────────────────────────────
// BOOKING REPOSITORY
//
// The only place that knows the shape of /api/v1/holds, /bookings and /payments.
//
// Note the absence of any method that takes an amount. The server computes what is
// owed and creates the payment order for that figure; this client is told the total
// so it can display it, and is never in a position to propose one.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../../shared/models/availability.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/models/parking.dart';

class BookingRepository {
  BookingRepository(this._api);

  final ApiClient _api;

  /* ── holds ───────────────────────────────────────────────────────────── */

  /// Takes a hold on a slot. Throws on conflict — the caller shows the reason
  /// rather than silently selecting a different slot.
  Future<SlotHold> createHold({
    required int parkingAreaId,
    required int slotId,
    required DateTime startAt,
    required int durationMinutes,
  }) {
    return _api.post<SlotHold>(
      '/holds',
      body: {
        'parking_area_id': parkingAreaId,
        'slot_id': slotId,
        'start_at': startAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
      },
      parse: (data) => SlotHold.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// The caller's live hold, if any. Restores the countdown after a cold start.
  Future<SlotHold?> currentHold() {
    return _api.get<SlotHold?>(
      '/holds/current',
      parse: (data) =>
          data == null ? null : SlotHold.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<SlotHold> extendHold(int holdId) {
    return _api.post<SlotHold>(
      '/holds/$holdId/extend',
      parse: (data) => SlotHold.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<void> releaseHold(int holdId) async {
    await _api.delete<dynamic>('/holds/$holdId');
  }

  /* ── availability ────────────────────────────────────────────────────── */

  /// Slot layout for a window. The same endpoint discovery uses — one availability
  /// definition, so the map, the card and the slot picker cannot disagree.
  Future<SlotLayout> availability({
    required int parkingAreaId,
    required VehicleType vehicleType,
    required DateTime startAt,
    required int durationMinutes,
  }) {
    return _api.get<SlotLayout>(
      '/parking/$parkingAreaId/availability',
      query: {
        'vehicle_type': vehicleType.wire,
        'start_at': startAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
      },
      parse: (data) => SlotLayout.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /* ── bookings ────────────────────────────────────────────────────────── */

  /// Converts a hold into a booking awaiting payment.
  ///
  /// [idempotencyKey] makes a retry after a dropped response return the original
  /// booking rather than creating a second one. Generated once by the caller and
  /// reused across retries — which is the only way it can work.
  Future<Booking> createBooking({
    required int holdId,
    int? vehicleId,
    String? numberPlate,
    String? notes,
    required String idempotencyKey,
  }) {
    return _api.post<Booking>(
      '/bookings',
      body: {
        'hold_id': holdId,
        if (vehicleId != null) 'vehicle_id': vehicleId,
        if (vehicleId == null && numberPlate != null) 'number_plate': numberPlate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'idempotency_key': idempotencyKey,
      },
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<List<Booking>> listBookings({
    required BookingBucket bucket,
    int limit = 20,
    int offset = 0,
  }) {
    return _api.get<List<Booking>>(
      '/bookings',
      query: {'bucket': bucket.wire, 'limit': limit, 'offset': offset},
      parse: (data) => ((data as List?) ?? const [])
          .map((j) => Booking.fromJson((j as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  Future<BookingCounts> counts() {
    return _api.get<BookingCounts>(
      '/bookings/counts',
      parse: (data) => BookingCounts.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// The active-parking session, or null. A null here is a normal answer, not an
  /// error: most of the time nobody is parked.
  Future<Booking?> currentBooking() {
    return _api.get<Booking?>(
      '/bookings/current',
      parse: (data) =>
          data == null ? null : Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<Booking> booking(int bookingId) {
    return _api.get<Booking>(
      '/bookings/$bookingId',
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<CancellationPreview> cancellationPreview(int bookingId) {
    return _api.get<CancellationPreview>(
      '/bookings/$bookingId/cancellation-preview',
      parse: (data) => CancellationPreview.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<Booking> cancelBooking(int bookingId, {String? reason}) {
    return _api.post<Booking>(
      '/bookings/$bookingId/cancel',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<Booking> checkIn(int bookingId) {
    return _api.post<Booking>(
      '/bookings/$bookingId/check-in',
      body: const <String, dynamic>{},
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<Booking> checkOut(int bookingId) {
    return _api.post<Booking>(
      '/bookings/$bookingId/check-out',
      body: const <String, dynamic>{},
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /* ── payments ────────────────────────────────────────────────────────── */

  /// Asks the server to create a payment order. The amount comes from the booking
  /// the server already stored; nothing about it is negotiable here.
  Future<PaymentOrder> createPaymentOrder({
    required int bookingId,
    required String idempotencyKey,
  }) {
    return _api.post<PaymentOrder>(
      '/payments/order',
      body: {'booking_id': bookingId, 'idempotency_key': idempotencyKey},
      parse: (data) => PaymentOrder.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// Hands the Checkout result to the server to verify.
  ///
  /// A 200 here means the signature verified server-side and the booking is
  /// CONFIRMED. The client's own opinion of whether the payment succeeded plays no
  /// part: it reports what it was given and is told the outcome.
  Future<Booking> verifyPayment({
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) {
    return _api.post<Booking>(
      '/payments/verify',
      body: {
        'booking_id': bookingId,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// Reports a dismissed or declined checkout. The booking stays payable.
  Future<Booking> reportPaymentFailure({
    required int bookingId,
    String? orderId,
    String? reason,
  }) {
    return _api.post<Booking>(
      '/payments/failed',
      body: {
        'booking_id': bookingId,
        if (orderId != null) 'razorpay_order_id': orderId,
        if (reason != null) 'reason': reason,
      },
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// Asks the server to check with the provider directly.
  ///
  /// For the case the app was killed during checkout: neither the callback nor a
  /// webhook may have landed, and guessing is not an option.
  Future<Booking> reconcilePayment(int bookingId) {
    return _api.post<Booking>(
      '/payments/$bookingId/reconcile',
      parse: (data) => Booking.fromJson((data as Map).cast<String, dynamic>()),
    );
  }
}

/// Generates an idempotency key.
///
/// Not a UUID library: a 128-bit random value from `Random.secure()` rendered as
/// hex satisfies the server's `[A-Za-z0-9_-]{8,64}` and adds no dependency. It must
/// be generated once per logical attempt and reused across retries — a key that
/// changes on every retry provides no idempotency at all.
String newIdempotencyKey() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
