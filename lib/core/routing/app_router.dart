// ─────────────────────────────────────────────────────────────────────────────
// ROUTER
//
// One declarative graph with a real auth guard.
//
// The old app used imperative `Navigator.push` with inline MaterialPageRoutes and
// no named routes at all — which is why `Navigator.pushNamedAndRemoveUntil(context,
// "/login")` in the profile screen threw: that route had never been registered, so
// there was no working way to log out.
//
// Nothing here prevents deep-linking into a protected screen either; `redirect` is
// the single place that decides what an unauthenticated user may see.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/booking/presentation/booking_confirmation_screen.dart';
import '../../features/booking/presentation/booking_review_screen.dart';
import '../../features/booking/presentation/slot_selection_screen.dart';
import '../../features/bookings/presentation/booking_detail_screen.dart';
import '../../features/active/presentation/active_parking_screen.dart';
import '../../features/active/presentation/checkout_complete_screen.dart';
import '../../features/bookings/presentation/bookings_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/parking/presentation/parking_detail_screen.dart';
import '../../features/parking/presentation/search_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/parking.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/boot_screen.dart';
import '../providers/core_providers.dart';

abstract final class Routes {
  const Routes._();

  static const boot = '/';
  static const phone = '/sign-in';
  static const otp = '/sign-in/code';
  static const profileSetup = '/sign-in/profile';

  static const home = '/home';
  /// Retired as a destination — Home is the map now. Kept so existing links
  /// redirect instead of failing.
  static const explore = '/explore';
  static const bookings = '/bookings';
  static const active = '/active';
  static const profile = '/profile';

  static const search = '/search';
  static String parkingDetail(int id) => '/parking/$id';

  // ── booking flow ──────────────────────────────────────────────────────
  static const slotSelection = '/book/slots';
  static const bookingReview = '/book/review';
  static const bookingConfirmation = '/book/confirmed';
  /// NB: NOT under `/parking/` — that prefix already has a `/parking/:id`
  /// route, and go_router matched `/parking/complete` against it with
  /// id = "complete". `int.tryParse` then returned null and the customer landed
  /// on "That parking link is not valid" immediately after a successful
  /// check-out, with their session already closed.
  static const checkoutComplete = '/checkout/complete';
  static String bookingDetail(int id) => '/bookings/$id';
}

/// Arguments for the slot screen.
///
/// Passed as `extra` rather than encoded in the path: a window and a vehicle type
/// are a transient choice, not an addressable location, and a URL carrying them
/// would be stale the moment it was shared.
class SlotSelectionArgs {
  const SlotSelectionArgs({
    required this.parkingId,
    required this.parkingName,
    required this.vehicleType,
    required this.startAt,
    required this.durationMinutes,
  });

  final int parkingId;
  final String parkingName;
  final VehicleType vehicleType;
  final DateTime startAt;
  final int durationMinutes;
}

/// Bridges a Riverpod StateNotifier to go_router's `refreshListenable`, so the
/// redirect re-evaluates the moment auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.boot,
    refreshListenable: refresh,
    debugLogDiagnostics: false,

    /// The single authorisation decision for the whole app.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;

      final isBoot = path == Routes.boot;
      final isAuthFlow = path.startsWith('/sign-in');

      // Still restoring a session — hold on the boot screen rather than flashing
      // the sign-in screen at a user who is in fact signed in.
      if (auth.isRestoring) return isBoot ? null : Routes.boot;

      switch (auth.status) {
        case AuthStatus.signedOut:
          // Protected areas bounce to sign-in; the auth flow itself is allowed.
          return isAuthFlow ? null : Routes.phone;

        case AuthStatus.needsProfile:
          // Signed in but incomplete: only the profile step is reachable.
          return path == Routes.profileSetup ? null : Routes.profileSetup;

        case AuthStatus.signedIn:
          // Already signed in — never send someone back through login.
          if (isBoot || isAuthFlow) return Routes.home;
          return null;

        case AuthStatus.restoring:
          return isBoot ? null : Routes.boot;
      }
    },

    routes: [
      GoRoute(path: Routes.boot, builder: (_, __) => const BootScreen()),

      // Home absorbed the map, so `/explore` is no longer a place. It stays
      // addressable rather than 404-ing: it was a tab for the whole of the
      // previous version, and a link to it should land somewhere sensible.
      GoRoute(path: Routes.explore, redirect: (_, __) => Routes.home),

      // ── auth ────────────────────────────────────────────────────────────
      GoRoute(path: Routes.phone, builder: (_, __) => const PhoneScreen()),
      GoRoute(path: Routes.otp, builder: (_, __) => const OtpScreen()),
      GoRoute(path: Routes.profileSetup, builder: (_, __) => const ProfileSetupScreen()),

      // ── authenticated shell: four tabs with persistent state ────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.bookings, builder: (_, __) => const BookingsScreen())],
          ),
          // Active parking is a destination, not a card on Home: it is the one
          // screen a customer reopens repeatedly while they are NOT looking for
          // parking, and reaching it through a discovery map was backwards.
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.active, builder: (_, __) => const ActiveParkingScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen())],
          ),
        ],
      ),

      // ── full-screen routes, pushed over the shell ───────────────────────
      GoRoute(
        path: Routes.search,
        // Search slides up: it is a mode, not a destination.
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SearchScreen(),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/parking/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const _RouteError(message: 'That parking link is not valid.');
          return ParkingDetailScreen(parkingId: id);
        },
      ),

      // ── booking flow ────────────────────────────────────────────────────
      //
      // Pushed over the shell as a stack: Slots → Review → Confirmation. The
      // confirmation replaces the review so Back cannot return to a screen that
      // offers to pay for a booking already paid for.
      GoRoute(
        path: Routes.slotSelection,
        builder: (context, state) {
          final args = state.extra;
          if (args is! SlotSelectionArgs) {
            return const _RouteError(
              message: 'Open a parking area to choose a slot.',
            );
          }
          return SlotSelectionScreen(
            parkingId: args.parkingId,
            parkingName: args.parkingName,
            vehicleType: args.vehicleType,
            startAt: args.startAt,
            durationMinutes: args.durationMinutes,
          );
        },
      ),
      GoRoute(
        path: Routes.bookingReview,
        builder: (_, __) => const BookingReviewScreen(),
      ),
      GoRoute(
        path: Routes.checkoutComplete,
        builder: (context, state) {
          final booking = state.extra;
          if (booking is! Booking) {
            // Reached without a booking — a deep link, or a restart mid-flow.
            return const _RouteError(
              message: 'That parking session could not be opened.',
            );
          }
          return CheckoutCompleteScreen(booking: booking);
        },
      ),
      GoRoute(
        path: Routes.bookingConfirmation,
        builder: (context, state) {
          final booking = state.extra;
          if (booking is! Booking) {
            // Reached without a booking — a deep link, or a restart mid-flow.
            // Send them to the list rather than inventing a confirmation.
            return const _RouteError(message: 'That booking could not be opened.');
          }
          return BookingConfirmationScreen(booking: booking);
        },
      ),
      GoRoute(
        path: '/bookings/:bookingId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['bookingId'] ?? '');
          if (id == null) return const _RouteError(message: 'That booking link is not valid.');
          return BookingDetailScreen(bookingId: id);
        },
      ),
    ],

    errorBuilder: (context, state) =>
        _RouteError(message: 'We could not open that page.', path: state.uri.toString()),
  );
});

class _RouteError extends StatelessWidget {
  const _RouteError({required this.message, this.path});

  final String message;
  final String? path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off_outlined,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(message,
                  style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              if (path != null) ...[
                const SizedBox(height: 8),
                Text(path!,
                    style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
