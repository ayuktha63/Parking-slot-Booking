// ─────────────────────────────────────────────────────────────────────────────
// SERIALISATION CONTRACT
//
// Parses REAL responses captured from a running backend against a real database.
// The fixtures in test/fixtures/ are not hand-written — they were produced by
// curl against the API and copied verbatim.
//
// This suite exists because of a specific defect: `pg` returns bigint as a JSON
// STRING, every id in the schema is bigserial, and every model here parsed ids
// with `(json['id'] as num?)?.toInt() ?? 0`. A String is not a num, so every id
// silently became 0 — every parking card, every booking, every slot. Static
// analysis could not see it. Nothing but parsing a real response can.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_booking/shared/models/availability.dart';
import 'package:parking_booking/shared/models/booking.dart';
import 'package:parking_booking/shared/models/money.dart';
import 'package:parking_booking/shared/models/parking.dart';

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

Map<String, dynamic> asMap(dynamic v) => (v as Map).cast<String, dynamic>();

void main() {
  group('parking list', () {
    test('parses a real /parking response', () {
      final items = (fixture('parking_list')['data'] as List)
          .map((j) => ParkingSummary.fromJson(asMap(j)))
          .toList();

      expect(items, isNotEmpty, reason: 'the fixture must contain a lot');

      for (final p in items) {
        // THE regression. An id of 0 routes every tap to /parking/0.
        expect(p.id, greaterThan(0), reason: 'parking id must survive parsing');
        expect(p.name, isNotEmpty);
        expect(p.price.hourly.paise, greaterThan(0));
        expect(p.availability.totalSlots, greaterThanOrEqualTo(0));
      }
    });

    test('a lot with no reviews reports a null rating, not a fabricated one', () {
      final first = ParkingSummary.fromJson(
        asMap((fixture('parking_list')['data'] as List).first),
      );
      // The seeded lot has no reviews. Anything other than null here would mean
      // the client invented a score.
      expect(first.rating, isNull);
      expect(first.ratingCount, 0);
    });
  });

  group('parking detail', () {
    test('parses a real /parking/:id response', () {
      final detail = ParkingDetail.fromJson(asMap(fixture('parking_detail')['data']));

      expect(detail.summary.id, greaterThan(0));
      expect(detail.summary.name, isNotEmpty);
      expect(detail.pricing.total.paise, greaterThan(0));
      expect(detail.pricing.hourly.paise, greaterThan(0));
      expect(detail.maxDurationMinutes, greaterThan(0));
    });

    test('absent optional data parses as empty, never as placeholder content', () {
      final detail = ParkingDetail.fromJson(asMap(fixture('parking_detail')['data']));
      // The seeded lot has no photos and no opening hours (it is 24/7).
      expect(detail.photos, isEmpty);
      expect(detail.summary.coverPhotoUrl, isNull);
      expect(detail.openingHours, isEmpty);
      // But it does have amenities, so the list is genuinely populated.
      expect(detail.amenities.map((a) => a.code), contains('covered'));
    });
  });

  group('availability', () {
    test('parses a real slot layout with real row labels', () {
      final layout = SlotLayout.fromJson(asMap(fixture('availability')['data']));

      expect(layout.parkingAreaId, greaterThan(0));
      expect(layout.rows, isNotEmpty);

      final slots = layout.rows.expand((r) => r.slots).toList();
      expect(slots.length, layout.summary.total + layout.summary.closed,
          reason: 'every slot in the layout is accounted for in the summary');

      for (final s in slots) {
        expect(s.id, greaterThan(0), reason: 'slot id must survive parsing');
        expect(s.code, isNotEmpty);
      }

      // The rows come from parking_slots.row_label — not invented client-side.
      expect(layout.rows.map((r) => r.label).toSet().length, layout.rows.length);
    });

    test('findById locates a slot by its real id', () {
      final layout = SlotLayout.fromJson(asMap(fixture('availability')['data']));
      final first = layout.rows.first.slots.first;
      expect(layout.findById(first.id)?.code, first.code);
    });

    test('the window reports whether the lot is open', () {
      final layout = SlotLayout.fromJson(asMap(fixture('availability')['data']));
      expect(layout.window.isOpen, isTrue, reason: 'the seeded lot is 24/7');
      expect(layout.window.durationMinutes, greaterThan(0));
    });
  });

  group('bookings', () {
    test('parses a real /bookings response', () {
      final items = (fixture('bookings')['data'] as List)
          .map((j) => Booking.fromJson(asMap(j)))
          .toList();

      expect(items, isNotEmpty, reason: 'the fixture must contain a completed booking');

      for (final b in items) {
        expect(b.id, greaterThan(0), reason: 'booking id must survive parsing');
        // The access credential the operator searches for. A blank one would
        // make the booking unfindable at the barrier.
        expect(b.code, matches(RegExp(r'^PQX-[2-9A-HJ-NP-Z]{6}$')));
        expect(b.status, isNot(BookingStatus.unknown));
        expect(b.amount.reserved.paise, greaterThan(0));
        expect(b.slot?.id, isNotNull);
        expect(b.slot!.id, greaterThan(0));
      }
    });

    test('a completed booking carries a final amount and a settled payment', () {
      final completed = (fixture('bookings')['data'] as List)
          .map((j) => Booking.fromJson(asMap(j)))
          .firstWhere((b) => b.status == BookingStatus.completed);

      expect(completed.amount.finalAmount, isNotNull,
          reason: 'a completed stay has been settled');
      expect(completed.payment.isPaid, isTrue);
      expect(completed.actions.canCheckIn, isFalse);
      expect(completed.actions.isCancellable, isFalse);
    });
  });

  group('money', () {
    test('renders Indian digit grouping and omits meaningless decimals', () {
      expect(const Money(4000).display, '₹40');
      expect(const Money(4050).display, '₹40.50');
      expect(const Money(123456700).display, '₹12,34,567');
      expect(const Money(4000).perHour(), '₹40/hr');
    });

    test('parses whatever the server sends without throwing', () {
      expect(Money.fromJson(4000).paise, 4000);
      expect(Money.fromJson(null).paise, 0);
      expect(Money.fromJson('4000').paise, 4000);
      expect(Money.fromJson(-5).paise, 0, reason: 'money is never negative');
    });
  });
}
