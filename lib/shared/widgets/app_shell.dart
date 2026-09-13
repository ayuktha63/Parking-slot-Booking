// ─────────────────────────────────────────────────────────────────────────────
// APP SHELL — bottom navigation
//
// Four destinations with preserved state, so switching away from Home and back
// does not reset the map camera or lose the sheet's position.
//
//   Park      find somewhere. The map.
//   Bookings  what you have reserved, and what you have used.
//   Active    the session happening right now.
//   Profile   you, your vehicles, your settings.
//
// Active earns a tab because it is the one screen a customer reopens
// repeatedly while they are not searching for anything. It carries a live dot
// when a session is genuinely running — a factual claim about a socket
// subscription, never decoration.
//
// ─────────────────────────────────────────────────────────────────────────────
// THE BAR TAKES THE COLOUR OF WHAT IS ABOVE IT
//
// PARQX is a dark app with light content surfaces, and the bar sits directly
// beneath whichever of those a screen ends in. Home ends in the white results
// sheet; Bookings, Active and Profile end in the dark ground. A bar that
// ignored that would either float a dark slab on white or a white slab on navy,
// and both read as a component that belongs to a different app.
//
// So the surface is a property of the destination, declared once here.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/booking_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/haptics.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_Destination>[
    _Destination(Icons.map_outlined, Icons.map_rounded, 'Park', onLight: true),
    _Destination(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Bookings'),
    _Destination(Icons.directions_car_outlined, Icons.directions_car_rounded, 'Active'),
    _Destination(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  void _onTap(int index) {
    // Switching destination is navigation, not commitment: light, not a thud.
    Haptics.light();
    // Tapping the active tab pops that branch to its root — the standard idiom,
    // and the only way back from a deep stack without hunting for a back button.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribed at the shell, not per screen, so a booking change reaches the
    // app wherever the customer happens to be.
    //
    // This is what makes the operator's check-in visible immediately: the server
    // emits `booking:update` to the customer's private room, and the Active tab
    // lights up without the customer touching anything.
    ref.watch(bookingRealtimeSyncProvider);

    // And configuration changes, so a lot whose operator just raised the price
    // or closed slots stops being shown at the old numbers.
    ref.watch(parkingConfigSyncProvider);

    final hasLiveSession =
        ref.watch(currentBookingProvider).valueOrNull?.isParked == true;

    final index = navigationShell.currentIndex;
    final onLight = _destinations[index].onLight;

    return Scaffold(
      // Home's map runs under the bar.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _NavBar(
        destinations: _destinations,
        currentIndex: index,
        onLight: onLight,
        liveOn: hasLiveSession ? 2 : null,
        onTap: _onTap,
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.activeIcon, this.label, {this.onLight = false});

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// True when this destination's content ends in a light surface.
  final bool onLight;
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onLight,
    required this.onTap,
    this.liveOn,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final bool onLight;
  final ValueChanged<int> onTap;

  /// Index that should carry a live dot, if any.
  final int? liveOn;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        color: onLight ? AppColors.surface : AppColors.canvas,
        border: Border(
          top: BorderSide(
            color: onLight ? AppColors.border : AppColors.borderDark,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.navBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: currentIndex == i,
                    onLight: onLight,
                    live: liveOn == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onLight,
    required this.live,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool onLight;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Both states meet contrast requirements against their surface.
    final colour = selected
        ? AppColors.brand
        : (onLight ? AppColors.inkMuted : AppColors.inkMutedDark);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.instant,
                  child: Icon(
                    selected ? destination.activeIcon : destination.icon,
                    key: ValueKey(selected),
                    size: AppSizes.iconMd,
                    color: colour,
                  ),
                ),
                // Only when a session is genuinely running.
                if (live)
                  Positioned(
                    top: -1,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.successBright,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: onLight ? AppColors.surface : AppColors.canvas,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: context.text.labelSmall?.copyWith(
                color: colour,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
