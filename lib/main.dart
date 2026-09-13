// ─────────────────────────────────────────────────────────────────────────────
// PARQX — customer app entry point
//
// Thin by design: install the Riverpod scope, build the theme from tokens, hand
// routing to go_router. Everything else lives in core/ and features/.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge. Home is map-first, and a map that stops short of the status
  // bar behind an opaque strip looks like a widget embedded in an app rather
  // than the surface of the app itself. Individual screens declare their own
  // icon brightness with AnnotatedRegion — light over the dark map, dark over
  // the light sheets — so this sets only the transparent, drawn-behind case.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: ParqxApp()));
}

class ParqxApp extends ConsumerWidget {
  const ParqxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PARQX',
      debugShowCheckedModeBanner: false,

      // ── The identity decision ────────────────────────────────────────────
      //
      // Premium light chrome over a deliberately DARK, desaturated map.
      //
      // This is a committed hybrid, not an unfinished dark mode. A parking app's
      // job is to make availability findable at a glance; on a stock OSM
      // basemap — beige roads, green parks, pink motorways — a price marker is
      // one more coloured object in a busy field. On the near-black basemap
      // PARQX renders (see AppMapStyle) the markers are the only saturated
      // things on screen.
      //
      // Following the system into a half-checked dark theme is how the previous
      // app ended up with a dark ThemeData wrapping a light UI, so the customer
      // app pins itself to light and owns the contrast deliberately. The
      // operator app is the dark one, and that difference is the point: the two
      // products should never be mistaken for each other.
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,

      routerConfig: router,
      builder: (context, child) {
        // Clamp text scaling. Layouts are verified overflow-free to 130% on a
        // 360px screen by test/render_harness_test.dart, which also renders the
        // card at 200% to prove the reflow path works.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
