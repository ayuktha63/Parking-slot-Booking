// ─────────────────────────────────────────────────────────────────────────────
// LOCATION SERVICE
//
// Explicit, honest location state.
//
// The old implementation had five different failure paths that all silently
// assigned `LatLng(8.5241, 76.9366)` — Trivandrum — so a user who denied permission,
// or had location switched off, or was anywhere else in the world, saw distances and
// ETAs computed from a city they might never have visited, presented as fact.
//
// Here every outcome is a distinct state the UI must handle. There is no fallback
// coordinate that pretends to be the user's position.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationStatus {
  /// Not asked yet.
  unknown,

  /// Asking the OS.
  requesting,

  /// We have a position.
  available,

  /// The user said no. Recoverable by asking again.
  denied,

  /// The user said never. Only recoverable through system settings.
  deniedForever,

  /// Location services are switched off device-wide.
  serviceDisabled,

  /// Permission granted but no fix obtained (indoors, airplane mode, timeout).
  unavailable,
}

@immutable
class LocationState {
  const LocationState({
    required this.status,
    this.position,
    this.accuracyMetres,
    this.updatedAt,
  });

  const LocationState.unknown() : this(status: LocationStatus.unknown);

  final LocationStatus status;
  final LatLng? position;
  final double? accuracyMetres;
  final DateTime? updatedAt;

  bool get hasPosition => position != null;

  /// True when asking again could plausibly succeed — drives whether the UI offers
  /// "Enable location" or "Open settings".
  bool get isRecoverable =>
      status == LocationStatus.denied ||
      status == LocationStatus.unknown ||
      status == LocationStatus.unavailable;

  bool get needsSystemSettings =>
      status == LocationStatus.deniedForever || status == LocationStatus.serviceDisabled;

  /// Message shown in the location banner. Never implies we know where the user is.
  String get message {
    switch (status) {
      case LocationStatus.unknown:
        return 'Turn on location to see parking near you';
      case LocationStatus.requesting:
        return 'Finding your location…';
      case LocationStatus.available:
        return 'Location on';
      case LocationStatus.denied:
        return 'Location access is off';
      case LocationStatus.deniedForever:
        return 'Location is blocked in settings';
      case LocationStatus.serviceDisabled:
        return 'Location services are turned off';
      case LocationStatus.unavailable:
        return "We couldn't get your location";
    }
  }

  /// The single action that resolves this state.
  String get actionLabel {
    switch (status) {
      case LocationStatus.deniedForever:
      case LocationStatus.serviceDisabled:
        return 'Open settings';
      default:
        return 'Enable location';
    }
  }
}

class LocationService {
  /// Current position, requesting permission if needed.
  ///
  /// Never throws and never invents a coordinate: every failure is a typed state.
  Future<LocationState> resolve({bool requestIfDenied = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationState(status: LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && requestIfDenied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationState(status: LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationState(status: LocationStatus.denied);
      }

      // `medium` is deliberate: parking discovery needs a few hundred metres, not a
      // GPS-grade fix. The old code asked for `best`, which costs battery and adds
      // seconds of wait for no product benefit.
      // geolocator 11.x takes these directly; the `locationSettings:` object form
      // only exists from geolocator 12. Pinned to what pubspec.yaml resolves.
      //
      // The outer `.timeout()` is not redundant with `timeLimit`. `timeLimit` is
      // enforced by the plugin on the platform side, and on Android it does not
      // fire when the location request never starts at all — which is exactly
      // what happens on a device with no fix (`last location=null` for every
      // provider). Observed on an emulator: `getCurrentPosition` simply never
      // completed, so the controller sat in `requesting` indefinitely and the UI
      // had no state to show and no way to retry.
      //
      // Dart's own timeout cannot be defeated by a platform channel that never
      // answers, so `resolve()` is guaranteed to settle. One second longer than
      // `timeLimit` so the plugin's own error wins when it does work.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      ).timeout(const Duration(seconds: 13));

      return LocationState(
        status: LocationStatus.available,
        position: LatLng(position.latitude, position.longitude),
        accuracyMetres: position.accuracy,
        updatedAt: DateTime.now(),
      );
    } on Object {
      // Timeout, no fix, platform error — all genuinely "we don't know".
      return const LocationState(status: LocationStatus.unavailable);
    }
  }

  /// Last known position: instant, possibly stale. Used to render something useful
  /// on first frame while a fresh fix is acquired.
  Future<LocationState> lastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return const LocationState.unknown();
      return LocationState(
        status: LocationStatus.available,
        position: LatLng(position.latitude, position.longitude),
        accuracyMetres: position.accuracy,
        updatedAt: position.timestamp,
      );
    } on Object {
      return const LocationState.unknown();
    }
  }

  Future<bool> openSettings() async {
    try {
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.deniedForever) {
        return Geolocator.openAppSettings();
      }
      return Geolocator.openLocationSettings();
    } on Object {
      return false;
    }
  }

  /// Straight-line distance in metres between two points.
  static double distanceBetween(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }
}
