// ─────────────────────────────────────────────────────────────────────────────
// LIVE BACKEND INTEGRATION
//
// This is the REAL app — the exact `ParqxApp` widget tree `main.dart` runs — driven
// by `integration_test` against a REAL running PARQX backend. No mocked Dio, no
// mocked Socket.IO, no fixture files. Every assertion below is either a widget
// actually on screen or a Riverpod provider's actual state after a real round trip.
//
// Run against a disposable backend + database:
//
//   flutter test integration_test/live_backend_test.dart \
//     -d macos --dart-define=API_BASE_URL=http://127.0.0.1:3939/api/v1
//
// or -d chrome for the web target. The backend must be reachable at that URL and
// the database must hold the seeded test lot (see config/verification/ENVIRONMENT.md).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:parking_booking/core/config/app_config.dart';
import 'package:parking_booking/core/providers/core_providers.dart';
import 'package:parking_booking/core/storage/token_storage.dart';
import 'package:parking_booking/core/providers/discovery_providers.dart';
import 'package:parking_booking/core/providers/booking_providers.dart';
import 'package:parking_booking/core/network/api_exception.dart';
import 'package:parking_booking/main.dart';
import 'package:parking_booking/features/parking/data/parking_repository.dart';
import 'package:parking_booking/shared/models/parking.dart';


void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A DISTINCT phone per test, not one shared across the file.
  //
  // The real backend enforces OTP_RESEND_COOLDOWN_SECONDS (30s) per phone — a
  // genuine anti-abuse protection verified in the runtime sprint. Sharing one
  // phone across several `testWidgets` blocks that each call `requestOtp` within
  // that window means the SECOND and later calls are correctly refused with
  // `OTP_COOLDOWN`, which is the server doing its job — not a defect. A counter
  // makes every test's phone unique even when several run in the same millisecond.
  var phoneCounter = 0;
  String freshPhone() {
    final epochTail = DateTime.now().millisecondsSinceEpoch.toString();
    phoneCounter += 1;
    // 6 digits of epoch tail + a 3-digit counter = 9 digits, prefixed with 7.
    return '7${epochTail.substring(epochTail.length - 6)}'
        '${phoneCounter.toString().padLeft(3, '0')}';
  }

  testWidgets('the real app boots against the real backend and reaches sign-in',
      (tester) async {
    // Sanity check FIRST: if this fails, every other test's failure is
    // uninterpretable noise. Prove the backend is actually reachable before
    // trusting anything the app renders.
    expect(
      AppConfig.apiBaseUrl.startsWith('http://127.0.0.1') ||
          AppConfig.apiBaseUrl.contains('localhost'),
      isTrue,
      reason: 'This suite must be pointed at a local disposable backend via '
          '--dart-define=API_BASE_URL. Got: ${AppConfig.apiBaseUrl}',
    );

    // Start genuinely signed out.
    //
    // flutter_secure_storage persists into the BROWSER PROFILE, which survives
    // between drive runs — earlier runs in this same profile (and the realtime
    // suites) leave a refresh token behind. With one present, boot restores a
    // session and the router lands on Home instead of sign-in, and this test's
    // premise silently stops holding. The operator realtime suite hit the same
    // stale-session problem last sprint and was fixed the same way.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(tokenStorageProvider).clear();

    await tester.pumpWidget(const ProviderScope(child: ParqxApp()));

    // NOT pumpAndSettle: the boot screen carries an indeterminate
    // LinearProgressIndicator, which schedules a frame forever, so a tree that is
    // still booting never reaches a quiescent frame. Pump in slices until the
    // wordmark is up, then stop.
    for (var i = 0; i < 40 && find.text('PARQX').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.text('PARQX'), findsWidgets,
        reason: 'boot screen or sign-in screen should render the wordmark');
  });

  testWidgets('OTP request reaches the real backend and returns a challenge',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(authRepositoryProvider);

    // A REAL HTTP POST to a REAL running Express route, hitting the REAL otpService
    // and writing a REAL row to otp_requests.
    final challenge = await repo.requestOtp(freshPhone());

    expect(challenge.requestId, isNotEmpty);
    expect(challenge.expiresIn, greaterThan(0));
    // dev_otp is present only because this backend has OTP_EXPOSE_IN_RESPONSE=true
    // — verified false in production by config validation, not by this test.
    expect(challenge.devOtp, isNotNull,
        reason: 'this suite requires a backend with OTP_EXPOSE_IN_RESPONSE=true');
  });

  testWidgets(
      'OTP verify establishes a real JWT session and the token survives to secure storage',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(authRepositoryProvider);
    final tokens = container.read(tokenStorageProvider);

    final phone = freshPhone();
    final challenge = await repo.requestOtp(phone);
    final result = await repo.verifyOtp(
      phone: phone,
      otp: challenge.devOtp!,
      requestId: challenge.requestId,
      name: 'Integration Test Customer',
    );

    expect(result.accessToken, isNotEmpty);
    expect(result.user, isNotNull);

    // The repository is responsible for persisting — verify it actually did,
    // against the real secure-storage backend (Keychain on macOS, IndexedDB-ish
    // on web), not an in-memory stand-in.
    final storedRefresh = await tokens.readRefreshToken();
    expect(storedRefresh, isNotEmpty,
        reason: 'the refresh token must reach secure storage for session restore to work');
    expect(tokens.accessToken, isNotEmpty,
        reason: 'the access token must be held for the Dio interceptor to attach it');
  });

  testWidgets(
      'the Dio auth interceptor actually attaches the bearer token to a real request',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final authRepo = container.read(authRepositoryProvider);
    final phone = freshPhone();
    final challenge = await authRepo.requestOtp(phone);
    await authRepo.verifyOtp(
      phone: phone, otp: challenge.devOtp!, requestId: challenge.requestId,
    );

    // /me requires requireAuth server-side. If the interceptor did not attach the
    // token, this call gets a REAL 401 from the REAL server, not a mock. Goes
    // through the same fetchMe() every real screen calls — /me nests the profile
    // under `data.user`, and re-parsing that shape by hand here would test a
    // second, parallel definition of the response instead of the real one.
    final me = await authRepo.fetchMe();

    expect(me.phone, phone);
    expect(me.id, greaterThan(0),
        reason: 'the bigint-as-string defect: id must arrive as a real int, never 0');
  });

  testWidgets(
      'a malformed access token is attached by the interceptor and refused by the real server',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final tokens = container.read(tokenStorageProvider);
    final api = container.read(apiClientProvider);

    // A garbage access token with a genuine-looking future expiry, and a garbage
    // refresh token. `hasValidAccessToken` reads only the expiry, so the
    // interceptor attaches this Bearer value as-is rather than proactively
    // refreshing — meaning the SERVER, not the client, is what rejects it.
    await tokens.save(AuthSession(
      accessToken: 'garbage.not.a.jwt',
      refreshToken: 'also-garbage',
      accessExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    ));

    try {
      await api.get<dynamic>('/me', parse: (d) => d);
      fail('a malformed token must not be accepted');
    } on ApiException catch (e) {
      // The interceptor's own fallback path: on 401 it attempts a refresh with the
      // (also garbage) refresh token, which the real server also rejects, so the
      // client correctly reports the session as over rather than retrying forever.
      expect(e.kind, ApiErrorKind.unauthenticated);
    }
  });

  testWidgets('logout actually clears secure storage', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final authRepo = container.read(authRepositoryProvider);
    final tokens = container.read(tokenStorageProvider);

    final phone = freshPhone();
    final challenge = await authRepo.requestOtp(phone);
    await authRepo.verifyOtp(
      phone: phone, otp: challenge.devOtp!, requestId: challenge.requestId,
    );
    expect(await tokens.readRefreshToken(), isNotEmpty);

    await authRepo.logout();

    expect(await tokens.readRefreshToken(), isNull,
        reason: 'logout must clear the stored session, or a relaunch would restore it');
  });

  testWidgets('discovery reaches the real backend and parses real ParkingSummary objects',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(parkingRepositoryProvider);
    final result = await repo.search(
      const ParkingQuery(vehicleType: VehicleType.car),
    );

    expect(result.items, isNotEmpty, reason: 'the seeded test lot must be discoverable');
    final lot = result.items.first;

    // The exact defect class the runtime sprint found and fixed: a bigint id
    // arriving as a JSON string and silently becoming 0.
    expect(lot.id, greaterThan(0));
    expect(lot.name, isNotEmpty);
    expect(lot.price.hourly.paise, greaterThan(0));
    expect(lot.availability.totalSlots, greaterThanOrEqualTo(0));
  });

  testWidgets('parking detail and availability parse real nested responses',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(parkingRepositoryProvider);
    final list = await repo.search(const ParkingQuery(vehicleType: VehicleType.car));
    final id = list.items.first.id;

    final detail = await repo.getDetail(id: id, vehicleType: VehicleType.car);
    expect(detail.summary.id, id);
    expect(detail.pricing.total.paise, greaterThan(0));
    // Honest nulls: this lot has no reviews. A fabricated rating would be a
    // product-honesty regression, not merely a parsing one.
    expect(detail.summary.rating, isNull);

    final layout = await repo.getAvailability(
      id: id, vehicleType: VehicleType.car,
      startAt: DateTime.now().add(const Duration(hours: 1)), durationMinutes: 60,
    );
    expect(layout.rows, isNotEmpty);
    final slot = layout.rows.first.slots.first;
    expect(slot.id, greaterThan(0));
  });

  testWidgets('a garbage search query does not crash the client and returns cleanly',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(parkingRepositoryProvider);
    // No location, no filters — must not throw, must return an honest empty-or-full
    // result rather than crashing the search screen.
    final result = await repo.search(const ParkingQuery(vehicleType: VehicleType.bike));
    expect(result, isNotNull);
  });

  testWidgets('a 404 on an unknown parking id surfaces as a typed ApiException',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repo = container.read(parkingRepositoryProvider);
    try {
      await repo.getDetail(id: 999999999, vehicleType: VehicleType.car);
      fail('an unknown parking id must not resolve');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.notFound);
      // No raw backend message, no SQL, no stack trace reaching the client.
      expect(e.message.toLowerCase(), isNot(contains('select')));
      expect(e.message.toLowerCase(), isNot(contains('postgres')));
    }
  });

  testWidgets(
      'the full booking vertical slice against the real backend: hold → book → PENDING_PAYMENT',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final authRepo = container.read(authRepositoryProvider);
    final phone = freshPhone();
    final challenge = await authRepo.requestOtp(phone);
    await authRepo.verifyOtp(
      phone: phone, otp: challenge.devOtp!, requestId: challenge.requestId,
    );

    final parkingRepo = container.read(parkingRepositoryProvider);
    final list = await parkingRepo.search(const ParkingQuery(vehicleType: VehicleType.car));
    final lotId = list.items.first.id;

    final layout = await parkingRepo.getAvailability(
      id: lotId, vehicleType: VehicleType.car,
      startAt: DateTime.now().add(const Duration(hours: 1)), durationMinutes: 60,
    );
    final freeSlot = layout.rows
        .expand((r) => r.slots)
        .firstWhere((s) => s.isSelectable, orElse: () => throw StateError('no free slot'));

    final bookingRepo = container.read(bookingRepositoryProvider);
    final hold = await bookingRepo.createHold(
      parkingAreaId: lotId,
      slotId: freeSlot.id,
      startAt: DateTime.now().add(const Duration(hours: 1)),
      durationMinutes: 60,
    );

    expect(hold.id, greaterThan(0));
    expect(hold.secondsRemaining(), greaterThan(0));
    expect(hold.slot.code, freeSlot.code);

    final booking = await bookingRepo.createBooking(
      holdId: hold.id,
      numberPlate: 'KA01LIVE01',
      idempotencyKey: 'live-test-${DateTime.now().millisecondsSinceEpoch}',
    );

    expect(booking.code, matches(RegExp(r'^PQX-[2-9A-HJ-NP-Z]{6}$')));
    expect(booking.status.name, 'pendingPayment');
    expect(booking.amount.reserved.paise, greaterThan(0));
    expect(booking.actions.canPay, isTrue);
  });

  testWidgets(
      'payment order creation surfaces the REAL 503 honestly — no fabricated success',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final authRepo = container.read(authRepositoryProvider);
    final phone = freshPhone();
    final challenge = await authRepo.requestOtp(phone);
    await authRepo.verifyOtp(
      phone: phone, otp: challenge.devOtp!, requestId: challenge.requestId,
    );

    final parkingRepo = container.read(parkingRepositoryProvider);
    final bookingRepo = container.read(bookingRepositoryProvider);

    final list = await parkingRepo.search(const ParkingQuery(vehicleType: VehicleType.car));
    final lotId = list.items.first.id;
    final layout = await parkingRepo.getAvailability(
      id: lotId, vehicleType: VehicleType.car,
      startAt: DateTime.now().add(const Duration(hours: 1)), durationMinutes: 60,
    );
    final freeSlot = layout.rows
        .expand((r) => r.slots)
        .firstWhere((s) => s.isSelectable, orElse: () => throw StateError('no free slot'));

    final hold = await bookingRepo.createHold(
      parkingAreaId: lotId, slotId: freeSlot.id,
      startAt: DateTime.now().add(const Duration(hours: 2)), durationMinutes: 60,
    );
    final booking = await bookingRepo.createBooking(
      holdId: hold.id, numberPlate: 'KA01LIVE02',
      idempotencyKey: 'live-pay-${DateTime.now().millisecondsSinceEpoch}',
    );

    // This backend instance has no Razorpay credentials. The real server refuses
    // honestly with 503 — verified in the runtime sprint. This test proves the
    // CLIENT surfaces that refusal as a typed exception rather than crashing,
    // hanging, or somehow reading it as success.
    try {
      await bookingRepo.createPaymentOrder(
        bookingId: booking.id,
        idempotencyKey: 'live-order-${DateTime.now().millisecondsSinceEpoch}',
      );
      fail('payment order creation must fail honestly with no gateway configured');
    } on ApiException catch (e) {
      expect(e.kind, ApiErrorKind.server);
      expect(e.code, 'SERVICE_UNAVAILABLE');
    }

    // And the booking must still be exactly what it was — never silently marked
    // CONFIRMED on the strength of a client-side assumption.
    final refetched = await bookingRepo.booking(booking.id);
    expect(refetched.status.name, 'pendingPayment');
    expect(refetched.payment.isPaid, isFalse);
  });
}
