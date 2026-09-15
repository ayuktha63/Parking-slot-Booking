// ─────────────────────────────────────────────────────────────────────────────
// CONTROLS — regressions found by driving the app on a device
//
//  · Every labelled control reached a screen reader as a button it could not
//    press: excluding the subtree for a composed label also dropped the tap.
//  · A control with no competing action nearby (Copy beside "You're booked")
//    merged into the surrounding text, so activating the text pressed it.
//  · A button sized to its label shrank to a spinner-sized square while busy.
//  · Booking screens showed plates raw ("KA01AB1234") beside grouped ones.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_booking/core/theme/app_theme.dart';
import 'package:parking_booking/shared/models/booking.dart';
import 'package:parking_booking/shared/models/parking.dart';
import 'package:parking_booking/shared/widgets/buttons.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('a labelled button can be pressed through accessibility', (tester) async {
    final semantics = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(_host(PrimaryButton(label: 'Pay ₹45', onPressed: () => presses++)));

    final node = tester.getSemantics(find.bySemanticsLabel('Pay ₹45'));
    expect(node, containsSemantics(label: 'Pay ₹45', isButton: true, hasTapAction: true));

    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(presses, 1);
    semantics.dispose();
  });

  testWidgets('a button beside plain text is a node of its own', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("You're booked"),
        PillButton(label: 'Copy', onPressed: () {}),
      ],
    )));

    expect(
      tester.getSemantics(find.byType(PillButton)),
      containsSemantics(label: 'Copy', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.text("You're booked")),
      containsSemantics(label: "You're booked", isButton: false, hasTapAction: false),
    );
    semantics.dispose();
  });

  testWidgets('a button sized to its label keeps its width while busy', (tester) async {
    Future<double> width({required bool busy}) async {
      await tester.pumpWidget(_host(PrimaryButton(
        label: 'Next',
        trailingIcon: Icons.arrow_forward_rounded,
        expand: false,
        isLoading: busy,
        onPressed: () {},
      )));
      return tester.getSize(find.byType(PrimaryButton)).width;
    }

    final idle = await width(busy: false);
    expect(await width(busy: true), idle);
  });

  test('plates read the way they are painted', () {
    expect(formatPlate('KA01AB1234'), 'KA 01 AB 1234');
    expect(formatPlate('ka 05-mx 4321'), 'KA 05 MX 4321');
    expect(formatPlate('DL3CAB1234'), 'DL 3 CAB 1234');
    // Not a standard registration: shown as entered rather than mangled.
    expect(formatPlate('22BH1234AA'), '22BH1234AA');
    expect(formatPlate('TEMP12'), 'TEMP12');

    expect(
      const BookingVehicle(type: VehicleType.car, numberPlate: 'KA01AB1234').displayPlate,
      'KA 01 AB 1234',
    );
    expect(const BookingVehicle(type: VehicleType.car, numberPlate: '  ').displayPlate, isNull);
    expect(const BookingVehicle(type: VehicleType.bike).displayPlate, isNull);
  });
}
