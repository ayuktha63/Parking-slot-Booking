// ─────────────────────────────────────────────────────────────────────────────
// APP CONFIGURATION
//
// ONE place that knows where the API is.
//
// The previous code declared `apiHost` in twelve separate screens, and they
// disagreed. Three were outright broken:
//
//   profile_screen.dart:41   if (kIsWeb) apiHost = "127.0.0.1";
//   settings_screen.dart:42  if (kIsWeb) apiHost = '127.0.0.1';
//        → on ANY web build, including production, these two screens called
//          https://127.0.0.1/... and could never work.
//
//   home_screen.dart:58-61   apiHost = '127.0.0.1';   // no port
//        → then called as https://$apiHost/... — wrong scheme, missing port.
//
// Configured at build time so a release binary cannot be pointed anywhere unexpected:
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
//   flutter build apk --dart-define=API_BASE_URL=https://api.parqx.app
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

enum AppFlavor { development, staging, production }

abstract final class AppConfig {
  const AppConfig._();

  /// Build-time override. Empty means "use the flavour default".
  static const String _baseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const String _flavorName =
      String.fromEnvironment('APP_FLAVOR', defaultValue: '');

  static AppFlavor get flavor {
    switch (_flavorName) {
      case 'production':
        return AppFlavor.production;
      case 'staging':
        return AppFlavor.staging;
      case 'development':
        return AppFlavor.development;
      default:
        // No explicit flavour: release builds are production, everything else is dev.
        return kReleaseMode ? AppFlavor.production : AppFlavor.development;
    }
  }

  static bool get isProduction => flavor == AppFlavor.production;
  static bool get isDevelopment => flavor == AppFlavor.development;

  /// Base URL, including the `/api/v1` prefix.
  static String get apiBaseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _normalise(_baseUrlOverride);
    }
    switch (flavor) {
      case AppFlavor.production:
        return 'https://backend-parking-bk8y.onrender.com/api/v1';
      case AppFlavor.staging:
        return 'https://backend-parking-bk8y.onrender.com/api/v1';
      case AppFlavor.development:
        return '${_devHost()}/api/v1';
    }
  }

  /// Socket origin — the same host, without the API path.
  static String get socketUrl {
    final base = apiBaseUrl;
    final idx = base.indexOf('/api/');
    return idx == -1 ? base : base.substring(0, idx);
  }

  /// Host for local development, per platform.
  ///
  /// Android emulators reach the host machine at 10.0.2.2, not localhost — a detail
  /// the previous per-screen fallbacks never accounted for, so local development on
  /// Android silently hit the production backend.
  static String _devHost() {
    if (kIsWeb) return 'http://127.0.0.1:3000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000';
    return 'http://127.0.0.1:3000';
  }

  static String _normalise(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u.contains('/api/') ? u : '$u/api/v1';
  }

  // ── Network behaviour ──────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  /// Retries for idempotent requests only. Never applied to POST.
  static const int maxRetries = 2;

  // ── Product constants ──────────────────────────────────────────────────
  /// Fallback only. The live value comes from `GET /meta` so the server stays
  /// authoritative; a client-side constant that drifts is how the old hold timer
  /// would have lied to users.
  static const Duration defaultHoldDuration = Duration(seconds: 120);

  /// Below this many free slots, a lot reads as "limited" rather than "available".
  static const double limitedAvailabilityRatio = 0.2;

  /// Search radius for "near me", in metres.
  static const int defaultSearchRadiusMetres = 5000;
  static const int maxSearchRadiusMetres = 50000;

  /// Average city speed used for ETA, in km/h.
  ///
  /// Straight-line distance over a constant speed is an estimate, and the UI labels
  /// it as one. The old code used the same 30 km/h but presented the result as a
  /// definite travel time.
  static const double etaAverageSpeedKmh = 24;

  /// Fallback map centre when location is unavailable: Trivandrum by default.
  ///
  /// Unlike the previous silent fallback, the UI tells the user that location is
  /// off and offers to enable it, rather than showing distances from a city they
  /// may not be in as though they were real.
  ///
  /// Overridable at build time, following the same pattern as API_BASE_URL. This
  /// exists because the thing being configured is genuinely environmental: an
  /// Android emulator frequently cannot obtain a GPS fix at all (every provider
  /// reports `last location=null`, and `adb emu geo fix` does not always latch),
  /// so without an override a developer's map opens on a city their local
  /// database has no inventory in and every screen renders its empty state.
  ///
  ///   flutter run --dart-define=FALLBACK_LAT=12.9716 --dart-define=FALLBACK_LNG=77.5946
  ///
  /// It changes only where the map LOOKS when position is unknown. It never
  /// becomes the user's position: `hasPosition` stays false, no distances are
  /// computed from it, and the location notice still says location is off.
  /// Passed as MICRODEGREES because `fromEnvironment` has no `double` form —
  /// Dart provides only String, int and bool. 12.9716 is 12971600.
  static const double fallbackLat =
      int.fromEnvironment('FALLBACK_LAT_MICRO', defaultValue: 8524100) / 1e6;
  static const double fallbackLng =
      int.fromEnvironment('FALLBACK_LNG_MICRO', defaultValue: 76936600) / 1e6;

  /// Basemap tiles. Defaults to standard OpenStreetMap tiles — no API key —
  /// rendered through a light grey filter (see AppMapStyle.silver).
  ///
  /// Production should point at a licensed provider with a light style:
  /// `--dart-define=MAP_TILE_URL=...` together with `MAP_ATTRIBUTION`. A custom
  /// URL is shown unfiltered, as its provider styled it.
  static const String mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const bool mapUsesDefaultTiles = !bool.hasEnvironment('MAP_TILE_URL');

  /// Subdomains for `{s}` in [mapTileUrl]. Ignored by templates without `{s}`.
  static const List<String> mapTileSubdomains = ['a', 'b', 'c', 'd'];

  static const String mapAttribution = String.fromEnvironment(
    'MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors',
  );

  /// Required by the OSM tile usage policy; must identify the app.
  static const String mapUserAgentPackageName = 'app.parqx.customer';

  /// Shown in Profile → About.
  ///
  /// Injected at build time rather than hardcoded, so a shipped binary reports
  /// the version it actually is:
  ///   flutter build apk --dart-define=APP_VERSION=1.4.0
  static const String versionLabel =
      String.fromEnvironment('APP_VERSION', defaultValue: 'development build');

  static const double mapMinZoom = 3;
  static const double mapMaxZoom = 18;
  static const double mapDefaultZoom = 14.5;

  /// Camera movement beyond this fraction of the viewport offers "Search this area".
  static const double searchThisAreaThreshold = 0.3;

  /// Debug summary for the diagnostics screen. Never includes a secret — the app
  /// holds no secrets: the payment key id is public and arrives from `/meta`.
  static Map<String, String> describe() => {
        'flavor': flavor.name,
        'apiBaseUrl': apiBaseUrl,
        'socketUrl': socketUrl,
        'buildMode': kReleaseMode
            ? 'release'
            : kProfileMode
                ? 'profile'
                : 'debug',
      };
}
