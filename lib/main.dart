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

  // Edge-to-edge: the map runs under the status bar. Everything in the app is
  // light, so system icons are dark throughout.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlay);

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

      // Light, monochrome, mobility-class: white surfaces, black actions and a
      // quiet light map. The customer app pins itself to this one look; the
      // operator app keeps its own dark console language.
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,

      routerConfig: router,
      builder: (context, child) {
        // Clamp text scaling. Layouts are verified overflow-free to 130% on a
        // 360px screen by test/render_harness_test.dart, which also renders the
        // card at 200% to prove the reflow path works.
        final mediaQuery = MediaQuery.of(context);
        // One system-bar style for the whole app, so a screen that sets none
        // cannot inherit a black navigation bar from wherever the user was last.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlay,
          child: MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
