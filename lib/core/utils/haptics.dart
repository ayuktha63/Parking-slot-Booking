// ─────────────────────────────────────────────────────────────────────────────
// HAPTICS
//
// Named by MEANING, not by strength — the call site says what happened, and this
// file decides how it should feel. That is what keeps haptics consistent across a
// product instead of every screen picking an impact level by taste.
//
// The product had none at all before this: `HapticFeedback` appeared zero times in
// the app. Parking is a one-handed, often eyes-busy activity — the driver is in a
// car park, frequently in the dark, sometimes holding something. Touch feedback is
// not decoration here; it is a second channel for "that worked".
//
// RULES
//   1. Haptics confirm a COMMITMENT or report a REFUSAL. Never on scroll, never on
//      navigation, never on a state change the user did not cause.
//   2. Every haptic pairs with a visible change. A buzz is never the only signal —
//      it is unavailable to a user whose device has it switched off.
//   3. Web and desktop have no haptics engine; these calls are inert there rather
//      than throwing, so call sites need no platform checks.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class Haptics {
  const Haptics._();

  /// Haptics are a mobile affordance. On web and desktop the platform channel is
  /// either absent or a no-op, and calling it wastes a channel round trip.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Swallows platform-channel failures.
  ///
  /// A missing haptics engine must never surface as an error to someone who was
  /// only trying to pick a parking slot.
  static Future<void> _fire(Future<void> Function() action) async {
    if (!_supported) return;
    try {
      await action();
    } on PlatformException {
      // Device has no vibrator, or the OS refused. Nothing to recover from.
    } on MissingPluginException {
      // Platform has no implementation registered.
    }
  }

  /// A deliberate choice landed — a slot selected, a filter applied, a vehicle
  /// type switched.
  static Future<void> selection() => _fire(HapticFeedback.selectionClick);

  /// A commitment succeeded — a hold taken, a booking confirmed, a check-out
  /// completed. The heaviest thing in this file, and the rarest.
  static Future<void> success() => _fire(HapticFeedback.mediumImpact);

  /// The server said no — a slot taken by someone else, a hold that lapsed, a
  /// payment that could not be started.
  ///
  /// Deliberately distinguishable from [success] by feel alone, because it often
  /// fires while the user is looking at the car park rather than the screen.
  static Future<void> refusal() => _fire(HapticFeedback.heavyImpact);

  /// A light acknowledgement for a reversible tap — deselecting, dismissing.
  static Future<void> light() => _fire(HapticFeedback.lightImpact);
}
