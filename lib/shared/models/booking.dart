// ─────────────────────────────────────────────────────────────────────────────
// BOOKING MODELS
//
// Mirrors /api/v1/bookings, /api/v1/holds and /api/v1/payments.
//
// Every value here is parsed from the server. There is no constructor that
// fabricates a booking code, an amount, a payment state or a slot — which is the
// point: the old success screen generated its own reference with
// `1000 + Random().nextInt(9000)`, so the number the customer wrote down changed
// every time the widget rebuilt and matched nothing in the database.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'money.dart';
import 'parking.dart' show VehicleType, formatPlate;

/// The booking lifecycle, exactly as the server defines it.
///
/// Parsing an unrecognised value yields [unknown] rather than throwing or guessing:
/// a client that is one release behind should degrade to "we can't act on this"
/// rather than mislabel a state.
enum BookingStatus {
  pendingPayment,
  confirmed,
  checkedIn,
  completed,
  cancelled,
  expired,
  noShow,
  unknown;

  static BookingStatus parse(String? raw) {
    switch (raw) {
      case 'PENDING_PAYMENT':
        return BookingStatus.pendingPayment;
      case 'CONFIRMED':
        return BookingStatus.confirmed;
      case 'CHECKED_IN':
        return BookingStatus.checkedIn;
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'CANCELLED':
        return BookingStatus.cancelled;
      case 'EXPIRED':
        return BookingStatus.expired;
      case 'NO_SHOW':
        return BookingStatus.noShow;
      default:
        return BookingStatus.unknown;
    }
  }

  bool get isLive =>
      this == BookingStatus.pendingPayment ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.checkedIn;

  bool get isParked => this == BookingStatus.checkedIn;
  bool get isTerminal => !isLive && this != BookingStatus.unknown;
}

/// The four tabs on the Bookings screen. The server owns which statuses map to
/// which bucket; this enum only names them for the request.
enum BookingBucket {
  upcoming,
  active,
  completed,
  cancelled;

  String get wire => name;

  String get label {
    switch (this) {
      case BookingBucket.upcoming:
        return 'Upcoming';
      case BookingBucket.active:
        return 'Active';
      case BookingBucket.completed:
        return 'Completed';
      case BookingBucket.cancelled:
        return 'Cancelled';
    }
  }
}

/* ── pieces ────────────────────────────────────────────────────────────────── */

@immutable
class BookingParking {
  const BookingParking({
    required this.id,
    required this.name,
    this.addressLine,
    this.locality,
    this.city,
    this.landmark,
    this.contactPhone,
    this.instructions,
    this.position,
    this.coverPhotoUrl,
  });

  factory BookingParking.fromJson(Map<String, dynamic> json) {
    final loc = (json['location'] as Map?)?.cast<String, dynamic>();
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();

    return BookingParking(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Parking',
      addressLine: json['address_line'] as String?,
      locality: json['locality'] as String?,
      city: json['city'] as String?,
      landmark: json['landmark'] as String?,
      contactPhone: json['contact_phone'] as String?,
        coverPhotoUrl: json['cover_photo_url'] as String?,
      instructions: json['instructions'] as String?,
      position: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    );
  }

  final int id;
  final String name;
  final String? addressLine;
  final String? locality;
  final String? city;
  final String? landmark;
  final String? contactPhone;

  /// The lot's cover photograph. Null when the operator has not uploaded one —
  /// the UI draws a generated monogram rather than a stock image of somewhere
  /// else.
  final String? coverPhotoUrl;

  /// Arrival instructions from the operator, e.g. "Use the B-block ramp".
  final String? instructions;
  final LatLng? position;

  /// Joins only the parts that exist. The old app rendered the literal ", " when
  /// both halves were missing from a response that never contained them.
  /// Locality and city — what identifies the AREA.
  ///
  /// `addressLabel` leads with the street line, which is the part that gets
  /// truncated away on a narrow card and the part a customer is least likely
  /// to recognise. This is the half worth showing when space is short.
  String? get shortLocation {
    final parts = [locality, city].where((p) => p != null && p.trim().isNotEmpty);
    if (parts.isEmpty) return addressLabel;
    return parts.join(', ');
  }

  String? get addressLabel {
    final parts = [addressLine, locality, city].where((p) => p != null && p.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  bool get hasCoordinates => position != null;
}

@immutable
class BookingSlot {
  const BookingSlot({
    required this.id,
    required this.code,
    this.rowLabel,
    this.position,
    this.slotNumber,
    this.slotClass = 'standard',
  });

  factory BookingSlot.fromJson(Map<String, dynamic> json) => BookingSlot(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code'] as String? ?? '',
        rowLabel: json['row_label'] as String?,
        position: (json['position'] as num?)?.toInt(),
        slotNumber: (json['slot_number'] as num?)?.toInt(),
        slotClass: json['slot_class'] as String? ?? 'standard',
      );

  final int id;

  /// What the driver looks for painted on the ground, e.g. "A12".
  final String code;
  final String? rowLabel;
  final int? position;
  final int? slotNumber;
  final String slotClass;
}

@immutable
class BookingVehicle {
  const BookingVehicle({required this.type, this.numberPlate, this.label});

  factory BookingVehicle.fromJson(Map<String, dynamic> json) => BookingVehicle(
        type: VehicleType.parse(json['type'] as String?),
        numberPlate: json['number_plate'] as String?,
        label: json['label'] as String?,
      );

  final VehicleType type;
  final String? numberPlate;
  final String? label;

  /// The plate as drivers read it ("KA 01 AB 1234"), or null when none was given.
  String? get displayPlate {
    final plate = numberPlate?.trim();
    return plate == null || plate.isEmpty ? null : formatPlate(plate);
  }
}

@immutable
class BookingWindowInfo {
  const BookingWindowInfo({
    this.entryTime,
    this.expectedExitTime,
    required this.durationMinutes,
    this.minutesUntilEntry,
  });

  factory BookingWindowInfo.fromJson(Map<String, dynamic> json) => BookingWindowInfo(
        entryTime: DateTime.tryParse(json['entry_time'] as String? ?? '')?.toLocal(),
        expectedExitTime:
            DateTime.tryParse(json['expected_exit_time'] as String? ?? '')?.toLocal(),
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
        minutesUntilEntry: (json['minutes_until_entry'] as num?)?.toInt(),
      );

  final DateTime? entryTime;
  final DateTime? expectedExitTime;
  final int durationMinutes;

  /// Server-computed, so two devices in different timezones agree.
  final int? minutesUntilEntry;

  String get durationLabel {
    if (durationMinutes <= 0) return '—';
    if (durationMinutes % 60 == 0) {
      final h = durationMinutes ~/ 60;
      return '$h hour${h == 1 ? '' : 's'}';
    }
    if (durationMinutes < 60) return '$durationMinutes min';
    return '${durationMinutes ~/ 60}h ${durationMinutes % 60}m';
  }
}

/// Money on a booking. `finalAmount` is null until check-out — the UI shows the
/// "Final amount" row only once there genuinely is one.
@immutable
class BookingAmount {
  const BookingAmount({
    required this.reserved,
    this.finalAmount,
    required this.refunded,
    required this.currency,
    this.hourly,
  });

  factory BookingAmount.fromJson(Map<String, dynamic> json) => BookingAmount(
        reserved: Money.fromJson(json['reserved_paise']),
        hourly: json['hourly_paise'] == null
            ? null
            : Money.fromJson(json['hourly_paise']),
        finalAmount:
            json['final_paise'] == null ? null : Money.fromJson(json['final_paise']),
        refunded: Money.fromJson(json['refunded_paise']),
        currency: json['currency'] as String? ?? 'INR',
      );

  final Money reserved;

  /// The rate this booking was priced at, from the server's own snapshot.
  ///
  /// Null for older bookings whose snapshot predates the field. Never derived
  /// by dividing the total by the hours — that is wrong the moment there is a
  /// platform fee, a surge multiplier or a part-hour, and it would disagree
  /// with the receipt.
  final Money? hourly;

  final Money? finalAmount;
  final Money refunded;
  final String currency;

  /// What the customer actually owes or paid: the settled amount once it exists.
  Money get payable => finalAmount ?? reserved;
  bool get hasRefund => refunded.paise > 0;
}

@immutable
class BookingPayment {
  const BookingPayment({
    this.status,
    required this.isPaid,
    this.reference,
    this.verifiedAt,
  });

  factory BookingPayment.fromJson(Map<String, dynamic> json) => BookingPayment(
        status: json['status'] as String?,
        isPaid: json['is_paid'] == true,
        reference: json['reference'] as String?,
        verifiedAt: DateTime.tryParse(json['verified_at'] as String? ?? '')?.toLocal(),
      );

  final String? status;
  final bool isPaid;

  /// The provider's own reference. Shown on the receipt for the customer's records
  /// — real, or absent. Never generated here.
  final String? reference;
  final DateTime? verifiedAt;
}

/// What the server says this customer may do with this booking right now.
///
/// Deliberately not derived client-side: the operator app has to agree with these
/// rules, and a rule written twice in two Dart codebases will diverge.
@immutable
class BookingActions {
  const BookingActions({
    required this.isCancellable,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.canPay,
    required this.canReview,
  });

  factory BookingActions.fromJson(Map<String, dynamic> json) => BookingActions(
        isCancellable: json['is_cancellable'] == true,
        canCheckIn: json['can_check_in'] == true,
        canCheckOut: json['can_check_out'] == true,
        canPay: json['can_pay'] == true,
        canReview: json['can_review'] == true,
      );

  static const none = BookingActions(
    isCancellable: false,
    canCheckIn: false,
    canCheckOut: false,
    canPay: false,
    canReview: false,
  );

  final bool isCancellable;
  final bool canCheckIn;
  final bool canCheckOut;
  final bool canPay;
  final bool canReview;
}

/// One entry in the booking's visible history.
@immutable
class BookingTimelineEntry {
  const BookingTimelineEntry({required this.type, required this.label, required this.at});

  factory BookingTimelineEntry.fromJson(Map<String, dynamic> json) => BookingTimelineEntry(
        type: json['type'] as String? ?? '',
        label: json['label'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );

  final String type;
  final String label;
  final DateTime at;
}

/// Live state of a stay in progress, computed server-side.
@immutable
class ParkingSession {
  const ParkingSession({
    required this.elapsedMinutes,
    required this.reservedMinutes,
    required this.remainingMinutes,
    required this.isOverstaying,
    this.projectedTotal,
    this.overstayAmount,
  });

  factory ParkingSession.fromJson(Map<String, dynamic> json) => ParkingSession(
        elapsedMinutes: (json['elapsed_minutes'] as num?)?.toInt() ?? 0,
        reservedMinutes: (json['reserved_minutes'] as num?)?.toInt() ?? 0,
        remainingMinutes: (json['remaining_minutes'] as num?)?.toInt() ?? 0,
        isOverstaying: json['is_overstaying'] == true,
        projectedTotal: json['projected_total_paise'] == null
            ? null
            : Money.fromJson(json['projected_total_paise']),
        overstayAmount: json['overstay_paise'] == null || json['overstay_paise'] == 0
            ? null
            : Money.fromJson(json['overstay_paise']),
      );

  final int elapsedMinutes;
  final int reservedMinutes;
  final int remainingMinutes;
  final bool isOverstaying;

  /// What this stay costs if it ends now — from the same server function that
  /// settles the bill at check-out. Null when the server did not supply one.
  final Money? projectedTotal;

  /// Non-null only once past the booked window.
  final Money? overstayAmount;

  double get progress =>
      reservedMinutes <= 0 ? 0 : (elapsedMinutes / reservedMinutes).clamp(0.0, 1.0);
}

/* ── the booking ───────────────────────────────────────────────────────────── */

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.status,
    required this.statusLabel,
    required this.parking,
    this.slot,
    required this.vehicle,
    required this.window,
    required this.amount,
    required this.payment,
    required this.actions,
    this.session,
    this.timeline = const [],
    this.refunds = const [],
    this.checkedInAt,
    this.checkedOutAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> sub(String key) =>
        (json[key] as Map?)?.cast<String, dynamic>() ?? const {};

    return Booking(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      status: BookingStatus.parse(json['status'] as String?),
      statusLabel: json['status_label'] as String? ?? '',
      parking: BookingParking.fromJson(sub('parking')),
      slot: json['slot'] == null
          ? null
          : BookingSlot.fromJson((json['slot'] as Map).cast<String, dynamic>()),
      vehicle: BookingVehicle.fromJson(sub('vehicle')),
      window: BookingWindowInfo.fromJson(sub('window')),
      amount: BookingAmount.fromJson(sub('amount')),
      payment: BookingPayment.fromJson(sub('payment')),
      actions: json['actions'] == null
          ? BookingActions.none
          : BookingActions.fromJson((json['actions'] as Map).cast<String, dynamic>()),
      session: json['session'] == null
          ? null
          : ParkingSession.fromJson((json['session'] as Map).cast<String, dynamic>()),
      timeline: ((json['timeline'] as List?) ?? const [])
          .map((e) => BookingTimelineEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      refunds: ((json['refunds'] as List?) ?? const [])
          .map((e) => BookingRefund.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      checkedInAt: DateTime.tryParse(json['checked_in_at'] as String? ?? '')?.toLocal(),
      checkedOutAt: DateTime.tryParse(json['checked_out_at'] as String? ?? '')?.toLocal(),
      completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '')?.toLocal(),
      cancelledAt: DateTime.tryParse(json['cancelled_at'] as String? ?? '')?.toLocal(),
      cancelledBy: json['cancelled_by'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  final int id;

  /// The access credential. Server-generated, stable, and what the operator types
  /// in to find this booking at the barrier.
  final String code;
  final BookingStatus status;
  final String statusLabel;

  final BookingParking parking;
  final BookingSlot? slot;
  final BookingVehicle vehicle;
  final BookingWindowInfo window;
  final BookingAmount amount;
  final BookingPayment payment;
  final BookingActions actions;

  /// Present only while parked.
  final ParkingSession? session;

  final List<BookingTimelineEntry> timeline;
  final List<BookingRefund> refunds;

  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime createdAt;

  bool get isLive => status.isLive;
  bool get isParked => status.isParked;
}

@immutable
class BookingRefund {
  const BookingRefund({
    required this.id,
    required this.amount,
    required this.status,
    this.processedAt,
  });

  factory BookingRefund.fromJson(Map<String, dynamic> json) => BookingRefund(
        id: (json['id'] as num?)?.toInt() ?? 0,
        amount: Money.fromJson(json['amount_paise']),
        status: json['status'] as String? ?? 'PENDING',
        processedAt: DateTime.tryParse(json['processed_at'] as String? ?? '')?.toLocal(),
      );

  final int id;
  final Money amount;
  final String status;
  final DateTime? processedAt;

  bool get isComplete => status == 'COMPLETED';
}

/* ── holds ─────────────────────────────────────────────────────────────────── */

/// A live hold on a slot.
///
/// The countdown is driven from [expiresAt], a server instant — never from a
/// locally-started timer. A device with a wrong clock, or one that was backgrounded
/// for a minute, must not believe it has longer than it does. [serverTime] is the
/// server's own clock at the moment of the response, so the client can correct for
/// device drift rather than trusting `DateTime.now()` outright.
@immutable
class SlotHold {
  const SlotHold({
    required this.id,
    required this.parkingAreaId,
    this.parkingName,
    required this.slot,
    required this.entryTime,
    required this.durationMinutes,
    required this.expiresAt,
    required this.serverTime,
    required this.extensionCount,
    required this.maxExtensions,
    required this.receivedAt,
    this.quote,
  });

  factory SlotHold.fromJson(Map<String, dynamic> json) {
    final slotJson = (json['slot'] as Map?)?.cast<String, dynamic>() ?? const {};
    final window = (json['window'] as Map?)?.cast<String, dynamic>() ?? const {};

    return SlotHold(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parkingAreaId: (json['parking_area_id'] as num?)?.toInt() ?? 0,
      parkingName: json['parking_name'] as String?,
      slot: HeldSlot.fromJson(slotJson),
      entryTime:
          DateTime.tryParse(window['entry_time'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      durationMinutes: (window['duration_minutes'] as num?)?.toInt() ?? 60,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      serverTime: DateTime.tryParse(json['server_time'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      extensionCount: (json['extension_count'] as num?)?.toInt() ?? 0,
      maxExtensions: (json['max_extensions'] as num?)?.toInt() ?? 0,
      // Captured at parse time, per hold, so skew is measured from the moment THIS
      // response arrived.
      receivedAt: DateTime.now().toUtc(),
      quote: json['quote'] == null
          ? null
          : PriceQuoteLite.fromJson((json['quote'] as Map).cast<String, dynamic>()),
    );
  }

  final int id;
  final int parkingAreaId;
  final String? parkingName;
  final HeldSlot slot;
  final DateTime entryTime;
  final int durationMinutes;

  /// UTC. The single source of truth for the countdown.
  final DateTime expiresAt;

  /// The server's clock when this hold was returned.
  final DateTime serverTime;

  final int extensionCount;
  final int maxExtensions;

  /// This device's clock when the response was parsed. Paired with [serverTime] it
  /// gives the offset between the two clocks at a known instant.
  final DateTime receivedAt;

  final PriceQuoteLite? quote;

  bool get canExtend => extensionCount < maxExtensions;

  /// Seconds left, measured on the SERVER's clock.
  ///
  /// `serverTime` and `receivedAt` are two readings of the same instant, one from
  /// each clock. Their difference is the offset; adding the device's elapsed time
  /// to `serverTime` gives what the server's clock reads now. A phone whose clock
  /// is an hour fast therefore does not get an hour less hold — nor an hour more.
  int secondsRemaining({DateTime? now}) {
    final deviceNow = (now ?? DateTime.now()).toUtc();
    final elapsedSinceResponse = deviceNow.difference(receivedAt);
    final serverNow = serverTime.add(elapsedSinceResponse);
    return expiresAt.difference(serverNow).inSeconds.clamp(0, 86400);
  }

  bool isExpired({DateTime? now}) => secondsRemaining(now: now) <= 0;
}

@immutable
class HeldSlot {
  const HeldSlot({
    required this.id,
    required this.code,
    this.rowLabel,
    this.position,
    this.slotNumber,
    this.slotClass = 'standard',
    required this.vehicleType,
  });

  factory HeldSlot.fromJson(Map<String, dynamic> json) => HeldSlot(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code'] as String? ?? '',
        rowLabel: json['row_label'] as String?,
        position: (json['position'] as num?)?.toInt(),
        slotNumber: (json['slot_number'] as num?)?.toInt(),
        slotClass: json['slot_class'] as String? ?? 'standard',
        vehicleType: VehicleType.parse(json['vehicle_type'] as String?),
      );

  final int id;
  final String code;
  final String? rowLabel;
  final int? position;
  final int? slotNumber;
  final String slotClass;
  final VehicleType vehicleType;
}

/// The quote carried alongside a hold. A narrower view of the pricing payload than
/// [PriceQuote] in parking.dart, holding only what the Review screen renders.
@immutable
class PriceQuoteLite {
  const PriceQuoteLite({
    required this.hourly,
    required this.subtotal,
    required this.platformFee,
    required this.total,
    required this.billedHours,
    required this.isSurge,
    required this.multiplier,
  });

  factory PriceQuoteLite.fromJson(Map<String, dynamic> json) => PriceQuoteLite(
        hourly: Money.fromJson(json['hourly_price_paise']),
        subtotal: Money.fromJson(json['subtotal_paise']),
        platformFee: Money.fromJson(json['platform_fee_paise']),
        total: Money.fromJson(json['total_paise']),
        billedHours: (json['billed_hours'] as num?)?.toInt() ?? 1,
        isSurge: json['is_surge'] == true,
        multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      );

  final Money hourly;
  final Money subtotal;
  final Money platformFee;
  final Money total;
  final int billedHours;
  final bool isSurge;
  final double multiplier;

  bool get hasPlatformFee => platformFee.paise > 0;
}

/* ── payments ──────────────────────────────────────────────────────────────── */

/// Everything needed to open Razorpay Checkout.
///
/// Note what the client is NOT given: any ability to influence the amount. It is
/// told what it will be charged; the order was created server-side for that exact
/// figure, and the server verifies the signature afterwards regardless.
@immutable
class PaymentOrder {
  const PaymentOrder({
    required this.paymentId,
    required this.bookingId,
    this.bookingCode,
    required this.providerOrderId,
    this.keyId,
    required this.amount,
    required this.currency,
    required this.description,
    this.prefillName,
    this.prefillContact,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final prefill = (json['prefill'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PaymentOrder(
      paymentId: (json['payment_id'] as num?)?.toInt() ?? 0,
      bookingId: (json['booking_id'] as num?)?.toInt() ?? 0,
      bookingCode: json['booking_code'] as String?,
      providerOrderId: json['provider_order_id'] as String? ?? '',
      keyId: json['key_id'] as String?,
      amount: Money.fromJson(json['amount_paise']),
      currency: json['currency'] as String? ?? 'INR',
      description: json['description'] as String? ?? 'PARQX parking',
      prefillName: prefill['name'] as String?,
      prefillContact: prefill['contact'] as String?,
    );
  }

  final int paymentId;
  final int bookingId;
  final String? bookingCode;
  final String providerOrderId;

  /// Public by design — it identifies the merchant, not the account. Null when the
  /// deployment has no gateway configured, in which case checkout cannot open and
  /// the UI says so rather than failing silently.
  final String? keyId;

  final Money amount;
  final String currency;
  final String description;
  final String? prefillName;
  final String? prefillContact;

  bool get isUsable => keyId != null && keyId!.isNotEmpty && providerOrderId.isNotEmpty;
}

/// What the customer gets back if they cancel now. Fetched before the confirm
/// dialog so the dialog states a real number.
@immutable
class CancellationPreview {
  const CancellationPreview({
    required this.isCancellable,
    required this.wasPaid,
    required this.refundPercent,
    required this.refund,
    required this.retained,
    required this.minutesUntilEntry,
    required this.policy,
  });

  factory CancellationPreview.fromJson(Map<String, dynamic> json) => CancellationPreview(
        isCancellable: json['is_cancellable'] == true,
        wasPaid: json['was_paid'] == true,
        refundPercent: (json['refund_percent'] as num?)?.toInt() ?? 0,
        refund: Money.fromJson(json['refund_paise']),
        retained: Money.fromJson(json['retained_paise']),
        minutesUntilEntry: (json['minutes_until_entry'] as num?)?.toInt() ?? 0,
        policy: json['policy'] as String? ?? '',
      );

  final bool isCancellable;
  final bool wasPaid;
  final int refundPercent;
  final Money refund;
  final Money retained;
  final int minutesUntilEntry;

  /// The rule in words, from the server, so the app never paraphrases a policy.
  final String policy;
}

/// Counts behind the four tab badges.
@immutable
class BookingCounts {
  const BookingCounts({
    required this.upcoming,
    required this.active,
    required this.completed,
    required this.cancelled,
  });

  factory BookingCounts.fromJson(Map<String, dynamic> json) => BookingCounts(
        upcoming: (json['upcoming'] as num?)?.toInt() ?? 0,
        active: (json['active'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      );

  static const empty = BookingCounts(upcoming: 0, active: 0, completed: 0, cancelled: 0);

  final int upcoming;
  final int active;
  final int completed;
  final int cancelled;

  int forBucket(BookingBucket bucket) {
    switch (bucket) {
      case BookingBucket.upcoming:
        return upcoming;
      case BookingBucket.active:
        return active;
      case BookingBucket.completed:
        return completed;
      case BookingBucket.cancelled:
        return cancelled;
    }
  }
}
