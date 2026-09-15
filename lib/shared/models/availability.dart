// ─────────────────────────────────────────────────────────────────────────────
// SLOT LAYOUT MODELS
//
// Mirrors GET /api/v1/parking/:id/availability.
//
// The server supplies `row_label` and `position`, so the client renders a real
// layout. The old app invented lanes with `slot_number <= 6 ? 'A' : 'B'`, which put
// 6 slots in lane A and 34 in lane B for a 40-slot lot and bore no relation to the
// physical place.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import 'parking.dart' show VehicleType;
import 'ids.dart';

enum SlotStatus {
  available,
  held,
  booked,
  closed;

  static SlotStatus parse(String? raw) {
    switch (raw) {
      case 'available':
        return SlotStatus.available;
      case 'held':
        return SlotStatus.held;
      case 'booked':
        return SlotStatus.booked;
      default:
        return SlotStatus.closed;
    }
  }

  String get label {
    switch (this) {
      case SlotStatus.available:
        return 'Available';
      case SlotStatus.held:
        return 'Held';
      case SlotStatus.booked:
        return 'Booked';
      case SlotStatus.closed:
        return 'Unavailable';
    }
  }
}

enum SlotClass {
  standard,
  accessible,
  ev,
  compact,
  valet;

  static SlotClass parse(String? raw) {
    switch (raw) {
      case 'accessible':
        return SlotClass.accessible;
      case 'ev':
        return SlotClass.ev;
      case 'compact':
        return SlotClass.compact;
      case 'valet':
        return SlotClass.valet;
      default:
        return SlotClass.standard;
    }
  }

  bool get isSpecial => this != SlotClass.standard;

  String? get label {
    switch (this) {
      case SlotClass.accessible:
        return 'Accessible';
      case SlotClass.ev:
        return 'EV charging';
      case SlotClass.compact:
        return 'Compact';
      case SlotClass.valet:
        return 'Valet';
      case SlotClass.standard:
        return null;
    }
  }
}

@immutable
class ParkingSlot {
  const ParkingSlot({
    required this.id,
    required this.code,
    required this.slotNumber,
    required this.position,
    required this.status,
    this.slotClass = SlotClass.standard,
    this.heldByYou = false,
    this.holdExpiresAt,
    this.closedReason,
  });

  factory ParkingSlot.fromJson(Map<String, dynamic> json) => ParkingSlot(
        id: parseId(json['id'], 'slot.id'),
        code: json['code'] as String? ?? '',
        slotNumber: (json['slot_number'] as num?)?.toInt() ?? 0,
        position: (json['position'] as num?)?.toInt() ?? 0,
        status: SlotStatus.parse(json['status'] as String?),
        slotClass: SlotClass.parse(json['slot_class'] as String?),
        heldByYou: json['held_by_you'] == true,
        holdExpiresAt: DateTime.tryParse(json['hold_expires_at'] as String? ?? ''),
        closedReason: json['closed_reason'] as String?,
      );

  final int id;

  /// Public label, e.g. "A12". What the user is told to look for on the ground.
  final String code;
  final int slotNumber;
  final int position;
  final SlotStatus status;
  final SlotClass slotClass;

  /// True when the caller is the one holding it — the difference between "someone
  /// took it" and "this is yours for the next two minutes".
  final bool heldByYou;
  final DateTime? holdExpiresAt;
  final String? closedReason;

  /// A slot the user may tap: free, or already held by them.
  bool get isSelectable => status == SlotStatus.available || heldByYou;

  ParkingSlot copyWith({SlotStatus? status, bool? heldByYou, DateTime? holdExpiresAt}) =>
      ParkingSlot(
        id: id,
        code: code,
        slotNumber: slotNumber,
        position: position,
        status: status ?? this.status,
        slotClass: slotClass,
        heldByYou: heldByYou ?? this.heldByYou,
        holdExpiresAt: holdExpiresAt ?? this.holdExpiresAt,
        closedReason: closedReason,
      );
}

@immutable
class SlotRow {
  const SlotRow({required this.label, required this.slots});

  factory SlotRow.fromJson(Map<String, dynamic> json) => SlotRow(
        label: json['label'] as String? ?? '',
        slots: ((json['slots'] as List?) ?? const [])
            .map((s) => ParkingSlot.fromJson((s as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );

  final String label;
  final List<ParkingSlot> slots;
}

@immutable
class AvailabilitySummary {
  const AvailabilitySummary({
    required this.total,
    required this.available,
    required this.booked,
    required this.held,
    required this.closed,
  });

  factory AvailabilitySummary.fromJson(Map<String, dynamic> json) => AvailabilitySummary(
        total: (json['total'] as num?)?.toInt() ?? 0,
        available: (json['available'] as num?)?.toInt() ?? 0,
        booked: (json['booked'] as num?)?.toInt() ?? 0,
        held: (json['held'] as num?)?.toInt() ?? 0,
        closed: (json['closed'] as num?)?.toInt() ?? 0,
      );

  final int total;
  final int available;
  final int booked;
  final int held;
  final int closed;

  double get occupancyRatio => total == 0 ? 0 : (booked + held) / total;
}

@immutable
class BookingWindow {
  const BookingWindow({
    required this.startsAt,
    required this.endsAt,
    required this.durationMinutes,
    this.isOpen = true,
  });

  factory BookingWindow.fromJson(Map<String, dynamic> json) => BookingWindow(
        startsAt: DateTime.tryParse(json['starts_at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        endsAt: DateTime.tryParse(json['ends_at'] as String? ?? '')?.toLocal() ??
            DateTime.now().add(const Duration(hours: 1)),
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
        // Absent on older responses; assuming open matches the server's own
        // fallback for a lot with no schedule configured.
        isOpen: json['is_open'] != false,
      );

  final DateTime startsAt;
  final DateTime endsAt;
  final int durationMinutes;

  /// False when the parking area is closed for this window. The server refuses a
  /// hold in that case; this lets the picker say so first.
  final bool isOpen;

  /// "2 hours" / "90 min"
  String get durationLabel {
    if (durationMinutes % 60 == 0) {
      final h = durationMinutes ~/ 60;
      return '$h hour${h == 1 ? '' : 's'}';
    }
    return '$durationMinutes min';
  }
}

/// The full response: layout plus summary plus the window it applies to.
@immutable
class SlotLayout {
  const SlotLayout({
    required this.parkingAreaId,
    required this.vehicleType,
    required this.window,
    required this.summary,
    required this.rows,
  });

  factory SlotLayout.fromJson(Map<String, dynamic> json) => SlotLayout(
        parkingAreaId: parseId(json['parking_area_id'], 'layout.parking_area_id'),
        vehicleType: VehicleType.parse(json['vehicle_type'] as String?),
        window: BookingWindow.fromJson(
          (json['window'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        summary: AvailabilitySummary.fromJson(
          (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        rows: ((json['rows'] as List?) ?? const [])
            .map((r) => SlotRow.fromJson((r as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );

  final int parkingAreaId;
  final VehicleType vehicleType;
  final BookingWindow window;
  final AvailabilitySummary summary;
  final List<SlotRow> rows;

  bool get isEmpty => rows.isEmpty;

  /// Counts derived from the spots themselves.
  ///
  /// [summary] is correct at fetch time, but realtime events update individual
  /// spots and never the summary — so after the first hold or booking by someone
  /// else the headline count and the floor plan disagree. Deriving the numbers
  /// from the same spots that are drawn keeps them in step.
  AvailabilitySummary get liveSummary {
    var available = 0, booked = 0, held = 0, closed = 0, total = 0;
    for (final row in rows) {
      for (final slot in row.slots) {
        total++;
        switch (slot.status) {
          case SlotStatus.available:
            available++;
          case SlotStatus.held:
            held++;
          case SlotStatus.booked:
            booked++;
          case SlotStatus.closed:
            closed++;
        }
      }
    }
    return AvailabilitySummary(
      total: total,
      available: available,
      booked: booked,
      held: held,
      closed: closed,
    );
  }

  /// Applies a live socket update without refetching the whole layout.
  SlotLayout withSlotUpdate({
    required int slotId,
    required SlotStatus status,
    bool? heldByYou,
    DateTime? holdExpiresAt,
  }) {
    return SlotLayout(
      parkingAreaId: parkingAreaId,
      vehicleType: vehicleType,
      window: window,
      summary: summary,
      rows: rows
          .map((row) => SlotRow(
                label: row.label,
                slots: row.slots
                    .map((s) => s.id == slotId
                        ? s.copyWith(
                            status: status,
                            heldByYou: heldByYou ?? (status == SlotStatus.held ? s.heldByYou : false),
                            holdExpiresAt: holdExpiresAt,
                          )
                        : s)
                    .toList(growable: false),
              ))
          .toList(growable: false),
    );
  }

  ParkingSlot? findById(int slotId) {
    for (final row in rows) {
      for (final slot in row.slots) {
        if (slot.id == slotId) return slot;
      }
    }
    return null;
  }
}
