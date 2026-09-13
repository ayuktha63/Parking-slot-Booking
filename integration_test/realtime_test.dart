// ─────────────────────────────────────────────────────────────────────────────
// LIVE REALTIME — CUSTOMER SOCKET CLIENT
//
// Connects the REAL `RealtimeService` — the exact class `AppShell` uses — to the
// REAL backend, and proves it receives and correctly PARSES real Socket.IO events
// pushed in response to a real operator check-in.
//
// This test creates the hold and booking through the real client repositories,
// then prints the booking code and waits, listening on its real socket. An
// external orchestrator (this app has no Razorpay credentials — see the payment
// boundary test in live_backend_test.dart) reads that code, settles the payment
// via the same signed-webhook path the backend's own contract tests use, and
// performs the check-in as the operator. That settlement step needs database
// access no real client has; everything downstream of it — the socket
// subscription, the event parsing, the stream delivery — is the real app's own
// code, which is what this test exists to prove.
//
// Run with orchestrate_realtime_test.sh, which starts this, waits for the
// booking code, drives the backend side, and waits for this process to exit.
// ─────────────────────────────────────────────────────────────────────────────


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:parking_booking/core/providers/booking_providers.dart';
import 'package:parking_booking/core/providers/core_providers.dart';
import 'package:parking_booking/core/realtime/realtime_service.dart';
import 'package:parking_booking/core/providers/discovery_providers.dart';
import 'package:parking_booking/features/parking/data/parking_repository.dart';
import 'package:parking_booking/shared/models/parking.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'the real customer socket client receives and parses real slot:update and '
      'booking:update events pushed by a real operator check-in',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final authRepo = container.read(authRepositoryProvider);
    final epochTail = DateTime.now().millisecondsSinceEpoch.toString();
    final phone = '7${epochTail.substring(epochTail.length - 9)}';
    final challenge = await authRepo.requestOtp(phone);
    await authRepo.verifyOtp(
      phone: phone, otp: challenge.devOtp!, requestId: challenge.requestId,
    );

    final parkingRepo = container.read(parkingRepositoryProvider);
    final list = await parkingRepo.search(const ParkingQuery(vehicleType: VehicleType.car));
    final lotId = list.items.first.id;
    final layout = await parkingRepo.getAvailability(
      id: lotId, vehicleType: VehicleType.car,
      startAt: DateTime.now().add(const Duration(minutes: 1)), durationMinutes: 60,
    );
    final freeSlot = layout.rows
        .expand((r) => r.slots)
        .firstWhere((s) => s.isSelectable, orElse: () => throw StateError('no free slot'));

    final bookingRepo = container.read(bookingRepositoryProvider);
    final hold = await bookingRepo.createHold(
      parkingAreaId: lotId, slotId: freeSlot.id,
      startAt: DateTime.now().add(const Duration(minutes: 1)), durationMinutes: 60,
    );
    final booking = await bookingRepo.createBooking(
      holdId: hold.id, numberPlate: 'KA01RTC001',
      idempotencyKey: 'realtime-cust-${DateTime.now().millisecondsSinceEpoch}',
    );

    // Connect the REAL socket client and subscribe exactly as `liveSlotLayoutProvider`
    // does when the customer has the slot picker open.
    final realtime = container.read(realtimeServiceProvider);
    await realtime.connect();
    realtime.subscribeToParking(parkingAreaId: lotId, vehicleType: 'car');

    final slotEvents = <SlotUpdateEvent>[];
    final bookingEvents = <BookingUpdateEvent>[];
    final slotSub = realtime.slotUpdates.listen(slotEvents.add);
    final bookingSub = realtime.bookingUpdates.listen(bookingEvents.add);
    addTearDown(slotSub.cancel);
    addTearDown(bookingSub.cancel);

    // Let the socket finish its handshake and room join — a real network round
    // trip — before signalling readiness.
    await Future<void>.delayed(const Duration(seconds: 2));

    // The orchestrator watches stdout for this exact line.
    // ignore: avoid_print
    print('REALTIME_TEST_READY booking_code=${booking.code} slot_id=${freeSlot.id}');

    // Bounded wait for the SPECIFIC events this check-in produces.
    //
    // The socket is subscribed to the whole `parking:1:car` room, and this
    // backend has been reused across a long test session — the hold-expiry
    // sweeper runs every few seconds and emits slot:update for whatever ELSE
    // expires in that window. An earlier version of this wait exited as soon as
    // *any* slot event and *any* booking event had arrived, which could be pure
    // sweeper noise for a different slot arriving before the real check-in event
    // — a race in the test, not in the app. Wait for the matching event
    // specifically, not merely for the type to be non-empty.
    bool sawSlotEvent() =>
        slotEvents.any((e) => e.slotId == freeSlot.id && e.status == 'booked');
    bool sawBookingEvent() =>
        bookingEvents.any((e) => e.bookingId == booking.id && e.status == 'CHECKED_IN');

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline) && !(sawSlotEvent() && sawBookingEvent())) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    // Captured ONCE, synchronously, at the moment the wait loop exits. Asserting
    // on a captured value rather than re-invoking sawSlotEvent()/sawBookingEvent()
    // inside expect() removes any possibility of a fresh socket callback landing
    // between "what we observed" and "what we assert on" — the two must describe
    // the exact same instant.
    final slotSnapshot = List<SlotUpdateEvent>.from(slotEvents);
    final bookingSnapshot = List<BookingUpdateEvent>.from(bookingEvents);
    final slotMatched = slotSnapshot.any((e) => e.slotId == freeSlot.id && e.status == 'booked');
    final bookingMatched =
        bookingSnapshot.any((e) => e.bookingId == booking.id && e.status == 'CHECKED_IN');

    // A known Flutter tooling defect (flutter/flutter#94434, #151480) makes the
    // `flutter drive` web-target pass/fail channel for `integration_test`
    // unreliable — it has been observed reporting "All tests passed" alongside a
    // contradictory "Failure Details" block whose own embedded data, on
    // inspection, actually satisfies the condition it claims failed. This print
    // is the authoritative signal an external orchestrator should rely on
    // instead: it is computed from the same synchronous, race-free snapshot as
    // the expect() calls below, with nothing between capture and report that
    // could diverge from what's printed.
    // ignore: avoid_print
    print('REALTIME_TEST_RESULT slot=${slotMatched ? 'PASS' : 'FAIL'} '
        'booking=${bookingMatched ? 'PASS' : 'FAIL'} '
        'slotEvents=${slotSnapshot.map((e) => '${e.slotId}:${e.status}').toList()} '
        'bookingEvents=${bookingSnapshot.map((e) => '${e.bookingId}:${e.status}').toList()}');

    expect(slotMatched, isTrue,
        reason: 'the real customer socket must receive slot:update(booked) for '
            'THIS slot on check-in. Events actually received: '
            '${slotSnapshot.map((e) => '${e.slotId}:${e.status}').toList()}');
    expect(bookingMatched, isTrue,
        reason: 'the real customer socket must receive booking:update(CHECKED_IN) '
            'for THIS booking. Events actually received: '
            '${bookingSnapshot.map((e) => '${e.bookingId}:${e.status}').toList()}');
  }, timeout: const Timeout(Duration(seconds: 45)));
}
