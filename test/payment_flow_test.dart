// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT FLOW — the app's side of the contract and its decisions
//
// The fixtures were produced by the backend's own code (a real booking and a real
// payment order, with only the gateway's HTTP API standing in), so a renamed field
// on either side fails here instead of on the first real payment.
//
// A development environment has no gateway credentials, so none of this can be
// seen by clicking through the app: order creation stops at an honest 503.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_booking/core/providers/booking_providers.dart';
import 'package:parking_booking/core/realtime/realtime_service.dart';
import 'package:parking_booking/features/booking/data/booking_repository.dart';
import 'package:parking_booking/features/booking/data/checkout_service.dart';
import 'package:parking_booking/shared/models/booking.dart';
import 'package:parking_booking/shared/models/ids.dart';

Map<String, dynamic> fixture(String name) =>
    ((jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map)['data'] as Map)
        .cast<String, dynamic>();

/// The pending booking, re-shaped the way the server reports it later.
Booking bookingWith({required String status, bool paid = false}) {
  final json = jsonDecode(jsonEncode(fixture('booking_pending'))) as Map<String, dynamic>;
  json['status'] = status;
  json['payment'] = {
    'status': paid ? 'PAID' : null,
    'is_paid': paid,
    'reference': paid ? 'pay_fixture' : null,
    'verified_at': null,
    'due_at': status == 'PENDING_PAYMENT' ? json['payment']['due_at'] : null,
  };
  return Booking.fromJson(json);
}

/* ── fakes: only what the controller calls ─────────────────────────────────── */

class _Repository implements BookingRepository {
  _Repository({this.verifyAnswer, this.reconcileAnswer});

  final Booking? verifyAnswer;
  final Booking? reconcileAnswer;
  final List<String> failuresReported = [];

  @override
  Future<PaymentOrder> createPaymentOrder({required int bookingId, required String idempotencyKey}) async =>
      PaymentOrder.fromJson(fixture('payment_order'));

  @override
  Future<Booking> verifyPayment({
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async =>
      verifyAnswer!;

  @override
  Future<Booking> reportPaymentFailure({required int bookingId, String? orderId, String? reason}) async {
    failuresReported.add(reason ?? '');
    return bookingWith(status: 'PENDING_PAYMENT');
  }

  @override
  Future<Booking> reconcilePayment(int bookingId) async => reconcileAnswer!;

  @override
  Future<SlotHold?> currentHold() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Checkout implements CheckoutService {
  _Checkout(this.result);

  final CheckoutResult result;

  @override
  Future<CheckoutResult> open({required PaymentOrder order}) async => result;

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<PaymentState> _runPayment({required _Repository repository, required CheckoutResult checkout}) async {
  final container = ProviderContainer(overrides: [
    bookingRepositoryProvider.overrideWithValue(repository),
    checkoutServiceProvider.overrideWithValue(_Checkout(checkout)),
    realtimeServiceProvider.overrideWithValue(RealtimeService(() async => null)),
  ]);
  addTearDown(container.dispose);
  final keepAlive = container.listen(paymentControllerProvider, (_, __) {});
  addTearDown(keepAlive.close);

  await container
      .read(paymentControllerProvider.notifier)
      .pay(booking: bookingWith(status: 'PENDING_PAYMENT'));
  return container.read(paymentControllerProvider);
}

CheckoutResult signedResult(PaymentOrder order) => CheckoutResult(
      outcome: CheckoutOutcome.returned,
      orderId: order.providerOrderId,
      paymentId: 'pay_fixture',
      signature: 'f' * 64,
    );

void main() {
  group('contract', () {
    test('the payment order the server sends opens Checkout', () {
      final order = PaymentOrder.fromJson(fixture('payment_order'));
      expect(order.bookingId, greaterThan(0));
      expect(order.paymentId, greaterThan(0));
      expect(order.providerOrderId, startsWith('order_'));
      expect(order.keyId, isNotEmpty);
      expect(order.amount.paise, 4500, reason: 'the amount is the server quote');
      expect(order.prefillContact, isNotNull);
      expect(order.isUsable, isTrue);
    });

    test('a pending booking says when it is released', () {
      final booking = Booking.fromJson(fixture('booking_pending'));
      expect(booking.status, BookingStatus.pendingPayment);
      expect(booking.payment.dueAt, isNotNull);
      expect(booking.actions.canPay, isTrue);
    });

    test('bigint ids arrive intact as numbers or strings', () {
      // Beyond 2^53 the backend sends ids as strings rather than rounding them.
      final json = Map<String, dynamic>.from(fixture('payment_order'))
        ..['booking_id'] = '9007199254740993'
        ..['payment_id'] = 9007199254740991;
      final order = PaymentOrder.fromJson(json);
      expect(order.bookingId, 9007199254740993);
      expect(order.paymentId, 9007199254740991);

      final booking = Map<String, dynamic>.from(fixture('booking_pending'))..['id'] = '9007199254740993';
      expect(Booking.fromJson(booking).id, 9007199254740993);
    });

    test('a missing or malformed id is an error, never 0', () {
      expect(
        () => PaymentOrder.fromJson(Map<String, dynamic>.from(fixture('payment_order'))..remove('booking_id')),
        throwsFormatException,
      );
      expect(
        () => Booking.fromJson(Map<String, dynamic>.from(fixture('booking_pending'))..['id'] = 0),
        throwsFormatException,
      );
      expect(() => parseId('12abc', 'x'), throwsFormatException);
      expect(parseOptionalId(null, 'x'), isNull);
    });

    test('only confirmed, parked or finished bookings count as secured', () {
      expect(BookingStatus.confirmed.isSecured, isTrue);
      expect(BookingStatus.checkedIn.isSecured, isTrue);
      expect(BookingStatus.completed.isSecured, isTrue);
      for (final status in [
        BookingStatus.pendingPayment,
        BookingStatus.expired,
        BookingStatus.cancelled,
        BookingStatus.noShow,
        BookingStatus.unknown,
      ]) {
        expect(status.isSecured, isFalse, reason: '$status');
      }
    });
  });

  group('realtime rooms', () {
    test('closing the spot grid puts the lot page back in its room', () {
      // REGRESSION: one subscription slot. The grid's dispose left the lot page in
      // no room, and an operator's change never reached it.
      final realtime = RealtimeService(() async => null);
      final page = realtime.subscribeToParking(parkingAreaId: 1, vehicleType: 'all');
      final grid = realtime.subscribeToParking(parkingAreaId: 1, vehicleType: 'car');
      expect(realtime.activeParkingRoom, (parkingAreaId: 1, vehicleType: 'car'));

      realtime.unsubscribeFromParking(grid);
      expect(realtime.activeParkingRoom, (parkingAreaId: 1, vehicleType: 'all'));

      realtime.unsubscribeFromParking(page);
      expect(realtime.activeParkingRoom, isNull);
    });

    test('screens released out of order keep the newest room', () {
      final realtime = RealtimeService(() async => null);
      final page = realtime.subscribeToParking(parkingAreaId: 1, vehicleType: 'all');
      final grid = realtime.subscribeToParking(parkingAreaId: 1, vehicleType: 'bike');

      realtime.unsubscribeFromParking(page);
      expect(realtime.activeParkingRoom, (parkingAreaId: 1, vehicleType: 'bike'));
      realtime.unsubscribeFromParking(grid);
      realtime.unsubscribeFromParking(grid);
      expect(realtime.activeParkingRoom, isNull);
    });
  });

  group('decisions', () {
    final order = PaymentOrder.fromJson(fixture('payment_order'));

    test('a verified payment on a confirmed booking is a confirmation', () async {
      final state = await _runPayment(
        repository: _Repository(verifyAnswer: bookingWith(status: 'CONFIRMED', paid: true)),
        checkout: signedResult(order),
      );
      expect(state.stage, PaymentStage.confirmed);
      expect(state.booking?.status, BookingStatus.confirmed);
    });

    test('a verified payment on an expired booking is never shown as booked', () async {
      // REGRESSION: any "verified" answer was treated as success, so a payment that
      // landed after the booking expired showed "You're booked".
      final state = await _runPayment(
        repository: _Repository(verifyAnswer: bookingWith(status: 'EXPIRED', paid: true)),
        checkout: signedResult(order),
      );
      expect(state.stage, PaymentStage.failed);
      expect(state.refundDue, isTrue);
    });

    test('a wallet payment that settled on a closed booking is a refund, not a booking', () async {
      // REGRESSION: the polling path accepted "is paid" alone as booked.
      final state = await _runPayment(
        repository: _Repository(reconcileAnswer: bookingWith(status: 'EXPIRED', paid: true)),
        checkout: CheckoutResult(outcome: CheckoutOutcome.returned, orderId: order.providerOrderId),
      );
      expect(state.stage, PaymentStage.failed);
      expect(state.refundDue, isTrue);
    });

    test('closing the checkout sheet says the payment was not completed', () async {
      // REGRESSION: a dismissed sheet returned silently to "Pay", leaving the
      // customer unsure whether the booking existed.
      final repository = _Repository();
      final state = await _runPayment(
        repository: repository,
        checkout: const CheckoutResult.cancelled(),
      );
      expect(state.stage, PaymentStage.failed);
      expect(state.refundDue, isFalse);
      expect(state.booking?.payment.dueAt, isNotNull, reason: 'the banner can say how long the spot is held');
      expect(repository.failuresReported, ['cancelled_by_user']);
    });

    test('a declined payment keeps the booking payable', () async {
      final state = await _runPayment(
        repository: _Repository(),
        checkout: const CheckoutResult(outcome: CheckoutOutcome.failed, message: 'Your bank declined the payment.'),
      );
      expect(state.stage, PaymentStage.failed);
      expect(state.message, 'Your bank declined the payment.');
      expect(state.refundDue, isFalse);
    });
  });
}
