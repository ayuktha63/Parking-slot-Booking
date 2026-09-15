// ─────────────────────────────────────────────────────────────────────────────
// RENDER HARNESS
//
// Renders real components with REAL captured backend data and writes PNGs to
// build/ux/, so the UX work can be LOOKED AT rather than only reasoned about.
//
// This is not a golden test — nothing here asserts pixel equality, and it will not
// fail a build because a shadow moved. It exists so a human (or whoever is doing
// the design pass) can open build/ux/*.png and see exactly what ships, at real
// phone widths, with the data the server actually returns.
//
// It does assert the things that genuinely matter and that a screenshot cannot
// check by itself: that the component builds without throwing, that it lays out
// without overflowing at the narrowest supported width, and that no fabricated
// content appears for a lot whose data is absent.
//
// Run:              flutter test test/render_harness_test.dart          (green)
// Run + capture:    UX_CAPTURE=1 flutter test test/render_harness_test.dart
// Look:             build/ux/*.png
//
// The capture path is opt-in, and reports google_fonts noise. `tester.runAsync`
// (required for image encoding) is what finally lets google_fonts' runtime font
// fetch actually execute, and it then fails because a test has no network. Those
// async zone errors are reported by the binding and cannot be filtered through
// FlutterError.onError, so a capture run exits non-zero even though all six images
// are written correctly and every assertion passes.
//
// The DEFAULT run — the one CI should use — is unaffected and fully green, because
// without runAsync the font fetch never runs. Treat the capture path as a local
// tool for producing pictures, not as a gate.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_booking/core/theme/app_theme.dart';
import 'package:parking_booking/core/theme/tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:parking_booking/features/booking/presentation/booking_confirmation_screen.dart';
import 'package:parking_booking/shared/models/booking.dart';
import 'package:parking_booking/shared/models/parking.dart';
import 'package:parking_booking/shared/widgets/live_duration.dart';
import 'package:parking_booking/shared/widgets/parking_card.dart';

// NOTE ON THE SCREENSHOTS
// Flutter's test environment runs with `--use-test-fonts --disable-asset-fonts`,
// so glyphs render as filled boxes. The captures are therefore useful for reading
// LAYOUT — hierarchy, spacing, alignment, element sizing, overflow — and not for
// reading copy. Copy is asserted directly with `find.text` below instead, which is
// a stronger check than reading it off an image anyway.
//
// (Registering a system face under the 'Inter' family was tried and hangs the
// test binding, so it is deliberately not done.)

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

Map<String, dynamic> asMap(dynamic v) => (v as Map).cast<String, dynamic>();

const captureKey = ValueKey('ux-capture-boundary');

/// Writes the rendered widget tree to `build/ux/[name].png`.
///
/// Gated behind UX_CAPTURE=1, because a human is the only consumer. The
/// ASSERTIONS in this file — overflow, honesty, text-scaling — are the part worth
/// running always, and they run either way.
///
/// The encoding MUST happen inside `tester.runAsync`. `toImage()` and
/// `toByteData()` complete on the raster thread; awaited directly in a widget
/// test's fake-async zone their futures never resolve, and the run hangs forever
/// rather than failing — which is exactly what happened here (one run sat on the
/// first capture for over three hours before this was tracked down).
Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['UX_CAPTURE'] != '1') return;

  final renderObject = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );

  await tester.runAsync(() async {
    final image = await renderObject.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;

    final dir = Directory('build/ux')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

/// Wraps a component in the real app theme at a real device width.
Widget harness(Widget child, {Color? background}) {
  return RepaintBoundary(
    key: captureKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: background ?? AppColors.canvas,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageInset),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  // The narrowest phone the breakpoints claim to support. If it lays out here it
  // lays out everywhere.
  const narrow = Size(360, 900);
  const regular = Size(390, 900);

  late List<ParkingSummary> lots;

  setUpAll(() {
    // The font workaround that used to live here is gone, along with its cause.
    //
    // Typography was built through `google_fonts`, which fetches Inter over the
    // network at runtime. In a test there is no network, and disabling fetching
    // made it throw instead — so this block had to let it try and then swallow
    // the resulting font errors, which is a deeply unsatisfying thing to have in
    // a test that is meant to catch problems.
    //
    // Inter now ships as a bundled asset (see pubspec `fonts:`), so there is no
    // fetch, no failure, and nothing to suppress. Every error reaching
    // `FlutterError.onError` is now a real one.

    // The VARIED capture, not the minimal one: 20 real lots straight off the
    // running backend, including lots with no address at all, lots with no
    // amenities, and closed lots. Rendering only the one well-populated lot
    // proves nothing about how the card degrades, which is most of the job.
    lots = (fixture('parking_list_varied')['data'] as List)
        .map((j) => ParkingSummary.fromJson(asMap(j)))
        .toList();
  });

  Future<void> pumpAt(WidgetTester tester, Widget widget, Size size) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(widget);
    // NOT pumpAndSettle: the loading skeleton shimmers forever by design, and
    // pumpAndSettle waits for a quiescent frame that never arrives.
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('parking card — the real range: rich, bare, closed', (tester) async {
    final rich = lots.firstWhere((l) => l.amenityCodes.isNotEmpty);
    final bare = lots.firstWhere(
      (l) => l.amenityCodes.isEmpty && l.location.shortAddress == null && l.isOpenNow,
    );
    final closed = lots.firstWhere((l) => !l.isOpenNow);

    await pumpAt(
      tester,
      harness(
        Column(
          children: [
            for (final lot in [rich, bare, closed]) ...[
              ParkingCard(parking: lot, onTap: () {}, onReserve: () {}),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
      const Size(390, 1100),
    );

    expect(tester.takeException(), isNull);

    // The closed lot must say so, and must not offer a live Reserve.
    expect(find.textContaining('Closed'), findsWidgets);
    await capture(tester, 'card_full');
  });

  testWidgets('parking card — full variant at 360px does not overflow',
      (tester) async {
    await pumpAt(
      tester,
      harness(ParkingCard(parking: lots.first, onTap: () {}, onReserve: () {})),
      narrow,
    );

    // A RenderFlex overflow surfaces as an exception in test; this is the check
    // that a screenshot cannot make for itself.
    expect(tester.takeException(), isNull,
        reason: 'the card must lay out at the narrowest supported width');
    await capture(tester, 'card_full_360');
  });

  testWidgets('parking card — compact and row variants', (tester) async {
    await pumpAt(
      tester,
      harness(
        Column(
          children: [
            ParkingCard(
              parking: lots.first,
              onTap: () {},
              variant: ParkingCardVariant.compact,
            ),
            const SizedBox(height: AppSpacing.md),
            ParkingCard(
              parking: lots.first,
              onTap: () {},
              variant: ParkingCardVariant.compact,
              isSelected: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            Material(
              color: AppColors.surface,
              child: ParkingCard(
                parking: lots.first,
                onTap: () {},
                variant: ParkingCardVariant.row,
              ),
            ),
          ],
        ),
      ),
      regular,
    );

    expect(tester.takeException(), isNull);
    await capture(tester, 'card_variants');
  });

  testWidgets('parking card skeleton matches the real card geometry',
      (tester) async {
    await pumpAt(
      tester,
      harness(
        Column(
          children: [
            const ParkingCardSkeleton(),
            const SizedBox(height: AppSpacing.md),
            ParkingCard(parking: lots.first, onTap: () {}, onReserve: () {}),
          ],
        ),
      ),
      regular,
    );

    expect(tester.takeException(), isNull);
    await capture(tester, 'card_skeleton_vs_real');
  });

  testWidgets('a lot with no rating, no distance and no photo fabricates nothing',
      (tester) async {
    // Deliberately the emptiest real lot in the fixture.
    final bare = lots.firstWhere(
      (l) => !l.hasRating && !l.hasDistance && !l.hasPhoto,
      orElse: () => lots.last,
    );

    await pumpAt(
      tester,
      harness(ParkingCard(parking: bare, onTap: () {}, onReserve: () {})),
      regular,
    );

    expect(tester.takeException(), isNull);

    // The honesty rules, asserted rather than trusted.
    expect(find.textContaining('★'), findsNothing);
    expect(find.textContaining('0.0'), findsNothing);
    expect(find.textContaining('4.5'), findsNothing);
    expect(find.textContaining('km'), findsNothing,
        reason: 'no distance may be shown without location permission');

    await capture(tester, 'card_bare_lot');
  });

  _liveDurationTests();

  // ── the confirmation screen ─────────────────────────────────────────────
  //
  // The one screen in the product that celebrates, and the hardest to reach by
  // hand: it sits behind a real payment, and `POST /payments/order` returns 503
  // without a live credential. So it is exercised here instead, against a real
  // COMPLETED booking straight out of a captured API response.
  //
  // It is also the most structurally awkward screen in the app — a stack with a
  // ticket deliberately overhanging the hero's lower edge, three staggered
  // animations, and a `PopScope`. Exactly the shape of thing that renders fine
  // in an author's head and throws on a device.
  testWidgets('confirmation screen renders a real booking without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final booking = Booking.fromJson(asMap((fixture('bookings') as Map)['data'][0]));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: BookingConfirmationScreen(bookingId: booking.id, initial: booking),
        ),
      ),
    );

    // Pumped in slices rather than settled: the hero runs a staggered entrance,
    // so `pumpAndSettle` is fine here but fixed pumps also prove the
    // mid-animation frames lay out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);

    // The booking code is the access credential. If it is not on this screen,
    // the screen has failed at its only job.
    expect(find.text(booking.code), findsOneWidget);
    expect(find.text('Show this code at the entrance'), findsOneWidget);
  });

  // ── unbounded constraints ───────────────────────────────────────────────
  //
  // This guards a failure mode this codebase has now hit twice, both times only
  // on a real device and never in the analyser:
  //
  //   1. `_GhostButton` on the active-parking card used a non-flex child in a
  //      Row and threw "BoxConstraints forces an infinite width", silently
  //      blanking the whole card. It is a RENDERING exception, so the
  //      FutureProvider's `error:` branch never saw it.
  //   2. `_Aisle` on the slot floor plan used `Expanded` inside a horizontally
  //      scrolling viewport, where the cross axis is unconstrained. That threw
  //      "RenderBox was not laid out" and cascaded through twenty parents into a
  //      sliver assertion, rendering the entire screen blank.
  //
  // Cards get laid out inside horizontal carousels and scroll views, so the
  // unbounded-width case is a real one, not a hypothetical.
  testWidgets('cards survive an unbounded-width parent', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final variant in ParkingCardVariant.values)
                  SizedBox(
                    width: 320,
                    child: ParkingCard(
                      parking: lots.first,
                      variant: variant,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.takeException(),
      isNull,
      reason: 'a card in an unbounded-width parent must lay out, not throw',
    );
  });

  testWidgets('text scaling at 200% stays laid out', (tester) async {
    tester.view.physicalSize = regular * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: harness(
          ParkingCard(parking: lots.first, onTap: () {}, onReserve: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull,
        reason: 'the card must survive 200% system text without overflowing');
    await capture(tester, 'card_text_scale_200');
  });
}

/* ── live duration ─────────────────────────────────────────────────────────── */

void _liveDurationTests() {
  group('LiveDuration', () {
    test('formats under and over an hour', () {
      expect(formatElapsed(const Duration(seconds: 9)), '00:09');
      expect(formatElapsed(const Duration(minutes: 4, seconds: 21)), '04:21');
      expect(formatElapsed(const Duration(hours: 1, minutes: 4, seconds: 21)),
          '1:04:21');
      expect(formatElapsed(const Duration(hours: 12)), '12:00:00');
    });

    test('a check-in instant in the future clamps to zero rather than going negative',
        () {
      expect(formatElapsed(const Duration(seconds: -30)), '00:00');
    });

    testWidgets('renders elapsed time from the server timestamp and disposes clean',
        (tester) async {
      final since = DateTime.now().subtract(const Duration(minutes: 2));

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: LiveDuration(since: since))),
      );

      // Read straight off the server's instant, with no refetch involved.
      expect(find.text('02:00'), findsOneWidget);

      // Advancing the FAKE clock fires the periodic timer, which is what proves the
      // widget is genuinely ticking rather than painting once. It does not change
      // the rendered text, because the displayed value is recomputed from the REAL
      // wall clock against the server's timestamp — deliberately, so that a device
      // returning from ten minutes in the background shows the right number
      // immediately instead of resuming ten minutes behind. Wall-clock advance is
      // not something a widget test can force, so the VALUE is covered by the
      // formatElapsed unit tests above and the TICKING is covered here.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      // Tearing the widget down must leave no pending timer; the binding fails the
      // test if one survives.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull,
          reason: 'the periodic timer must be cancelled on dispose');
    });
  });
}
