// ─────────────────────────────────────────────────────────────────────────────
// ROUTING
//
// Three tabs, like every mobility app: Home (the map), Activity (bookings) and
// Account. A live or imminent parking session is not a tab — it is a bar that
// follows you across all three and opens the full session screen.
//
// Every screen can be rebuilt from its URL alone. go_router serialises the route
// stack whenever it re-evaluates redirects, and an `extra` object that is not
// JSON is silently dropped in that round trip — which is exactly how a customer
// once landed on "Open a parking area to choose a slot" straight after booking.
// So arguments travel in the path and query string, and `extra` is only ever an
// optional head start that a screen can live without.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/active/presentation/active_parking_screen.dart';
import '../../features/active/presentation/checkout_complete_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/booking/presentation/booking_confirmation_screen.dart';
import '../../features/booking/presentation/booking_review_screen.dart';
import '../../features/booking/presentation/slot_selection_screen.dart';
import '../../features/bookings/presentation/booking_detail_screen.dart';
import '../../features/bookings/presentation/bookings_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/parking/presentation/parking_detail_screen.dart';
import '../../features/parking/presentation/search_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/vehicles_screen.dart';
import '../../shared/models/booking.dart';
import '../../shared/models/parking.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/boot_screen.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/states.dart';
import '../providers/core_providers.dart';

abstract final class Routes {
  const Routes._();

  static const boot = '/';

  static const phone = '/sign-in';
  static const otp = '/sign-in/code';
  static const profileSetup = '/sign-in/profile';

  // Tabs.
  static const home = '/home';
  static const bookings = '/bookings';
  static const profile = '/profile';

  /// Old deep links to the map land on Home.
  static const explore = '/explore';

  // Full-screen.
  static const search = '/search';
  static const active = '/active';
  static const vehicles = '/vehicles';
  static const bookingReview = '/book/review';

  static String parkingDetail(int id) => '/parking/$id';
  static String bookingDetail(int id) => '/bookings/$id';
  static String bookingConfirmation(int id) => '/bookings/$id/confirmed';
  static String checkoutComplete(int id) => '/bookings/$id/complete';
}

/// Leaves a booking flow for the booking itself, with Activity underneath.
///
/// Replacing only the current screen would leave the parking page and the spot
/// picker below it, so Back from a booking that already exists would walk into
/// choosing a spot for it again.
void openBookingAfterFlow(BuildContext context, int bookingId) {
  final router = GoRouter.of(context);
  router.go(Routes.bookings);
  router.push(Routes.bookingDetail(bookingId));
}

/// Everything the slot screen needs, carried in its URL.
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

  static const pattern = '/book/:parkingId/slots';

  String get location => Uri(
        path: '/book/$parkingId/slots',
        queryParameters: {
          'name': parkingName,
          'vehicle': vehicleType.wire,
          'start': '${startAt.millisecondsSinceEpoch}',
          'duration': '$durationMinutes',
        },
      ).toString();

  static SlotSelectionArgs? fromState(GoRouterState state) {
    final id = int.tryParse(state.pathParameters['parkingId'] ?? '');
    if (id == null) return null;
    final query = state.uri.queryParameters;
    final now = DateTime.now();
    final startMs = int.tryParse(query['start'] ?? '');
    var start = startMs == null ? now : DateTime.fromMillisecondsSinceEpoch(startMs);
    // A window that began a while ago (a restored page) books from now.
    if (start.isBefore(now.subtract(const Duration(minutes: 10)))) start = now;
    return SlotSelectionArgs(
      parkingId: id,
      parkingName: query['name'] ?? 'Parking',
      vehicleType: VehicleType.parse(query['vehicle']),
      startAt: start,
      durationMinutes: int.tryParse(query['duration'] ?? '') ?? 60,
    );
  }
}

/// Tells the router to re-run redirects — but only when the authentication
/// STATUS changes. Profile and vehicle refreshes change the auth state object
/// too, and re-running redirects for those rebuilt the whole route stack in the
/// middle of a booking.
class _AuthStatusRefresh extends ChangeNotifier {
  _AuthStatusRefresh(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthStatusRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.boot,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      final isBoot = path == Routes.boot;
      final isAuthFlow = path.startsWith('/sign-in');

      switch (auth.status) {
        case AuthStatus.restoring:
          return isBoot ? null : Routes.boot;
        case AuthStatus.signedOut:
          return isAuthFlow ? null : Routes.phone;
        case AuthStatus.needsProfile:
          return path == Routes.profileSetup ? null : Routes.profileSetup;
        case AuthStatus.signedIn:
          if (isBoot || isAuthFlow) return Routes.home;
          return null;
      }
    },
    routes: [
      GoRoute(path: Routes.boot, builder: (_, __) => const BootScreen()),
      GoRoute(path: Routes.explore, redirect: (_, __) => Routes.home),
      GoRoute(path: '/book/slots', redirect: (_, __) => Routes.home),

      GoRoute(path: Routes.phone, builder: (_, __) => const PhoneScreen()),
      GoRoute(path: Routes.otp, builder: (_, __) => const OtpScreen()),
      GoRoute(path: Routes.profileSetup, builder: (_, __) => const ProfileSetupScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.bookings, builder: (_, __) => const BookingsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, __) => const ProfileScreen())],
          ),
        ],
      ),

      GoRoute(
        path: Routes.search,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SearchScreen(),
          transitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      ),
      GoRoute(path: Routes.active, builder: (_, __) => const ActiveParkingScreen()),
      GoRoute(path: Routes.vehicles, builder: (_, __) => const VehiclesScreen()),

      GoRoute(
        path: '/parking/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const _RouteError(message: 'That parking link is not valid.');
          return ParkingDetailScreen(parkingId: id);
        },
      ),

      // ── booking flow ────────────────────────────────────────────────────
      GoRoute(
        path: SlotSelectionArgs.pattern,
        builder: (context, state) {
          final args = SlotSelectionArgs.fromState(state);
          if (args == null) return const _RouteError(message: 'That parking link is not valid.');
          return SlotSelectionScreen(
            parkingId: args.parkingId,
            parkingName: args.parkingName,
            vehicleType: args.vehicleType,
            startAt: args.startAt,
            durationMinutes: args.durationMinutes,
          );
        },
      ),
      GoRoute(path: Routes.bookingReview, builder: (_, __) => const BookingReviewScreen()),

      GoRoute(
        path: '/bookings/:bookingId/confirmed',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['bookingId'] ?? '');
          if (id == null) return const _RouteError(message: 'That booking link is not valid.');
          final extra = state.extra;
          return BookingConfirmationScreen(
            bookingId: id,
            initial: extra is Booking ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/bookings/:bookingId/complete',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['bookingId'] ?? '');
          if (id == null) return const _RouteError(message: 'That booking link is not valid.');
          final extra = state.extra;
          return CheckoutCompleteScreen(
            bookingId: id,
            initial: extra is Booking ? extra : null,
          );
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
    errorBuilder: (context, state) => const _RouteError(message: 'We could not open that page.'),
  );
});

class _RouteError extends StatelessWidget {
  const _RouteError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: EmptyStateView(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        message: message,
        action: PrimaryButton(
          label: 'Go home',
          expand: false,
          onPressed: () => context.go(Routes.home),
        ),
      ),
    );
  }
}
