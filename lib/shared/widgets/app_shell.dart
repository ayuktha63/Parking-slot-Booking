// ─────────────────────────────────────────────────────────────────────────────
// APP SHELL
//
// Three tabs and, above them, the session bar: whenever the server says you are
// parked — or about to arrive — a black bar follows you across the app with the
// live timer, the way a ride in progress does. It appears and changes the moment
// the operator checks you in, because the shell listens to booking events.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/booking_providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/haptics.dart';
import '../models/booking.dart';
import 'interaction.dart';
import 'live_duration.dart';
import 'surfaces.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <_Destination>[
    _Destination(Icons.map_outlined, Icons.map_rounded, 'Home'),
    _Destination(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Activity'),
    _Destination(Icons.person_outline_rounded, Icons.person_rounded, 'Account'),
  ];

  void _onTap(int index) {
    Haptics.light();
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep booking and lot state in step with the server while signed in.
    ref.watch(bookingRealtimeSyncProvider);
    ref.watch(parkingConfigSyncProvider);

    final current = ref.watch(currentBookingProvider).valueOrNull;
    final session = current != null && current.isLive ? current : null;

    return Scaffold(
      extendBody: true,
      // The tabs take no typing of their own (text entry happens in sheets and
      // full-screen routes above them), so a keyboard must not resize them.
      resizeToAvoidBottomInset: false,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment.bottomCenter,
            child: session == null
                ? const SizedBox(width: double.infinity)
                : Stack(
                    children: [
                      // The bar floats over scrolling lists; without a fade,
                      // rows showed through the gap between it and the tab bar.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.surface.withValues(alpha: 0),
                                  AppColors.surface,
                                ],
                                stops: const [0, 0.5],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: SessionBar(
                          booking: session,
                          onTap: () => context.push(Routes.active),
                        ),
                      ),
                    ],
                  ),
          ),
          _NavBar(
            destinations: _destinations,
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
          ),
        ],
      ),
    );
  }
}

/// The black "you are parked" bar.
class SessionBar extends StatelessWidget {
  const SessionBar({super.key, required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parked = booking.isParked && booking.checkedInAt != null;
    final spot = booking.slot?.code;
    final entry = booking.window.entryTime;

    final title = parked ? 'Parked at ${booking.parking.name}' : booking.parking.name;

    final Widget subtitle;
    final subtitleStyle = context.text.bodySmall?.copyWith(
      color: AppColors.white.withValues(alpha: 0.72),
    );
    if (parked) {
      subtitle = Row(
        children: [
          LiveDuration(
            since: booking.checkedInAt!,
            alwaysHours: true,
            style: AppTypography.numeric(size: 13, weight: FontWeight.w600, color: AppColors.white),
          ),
          if (spot != null) Text('  ·  Spot $spot', style: subtitleStyle),
        ],
      );
    } else {
      final upcoming = entry != null && entry.isAfter(DateTime.now());
      subtitle = Text(
        upcoming
            ? [if (spot != null) 'Spot $spot', 'Starts ${DateFormat('h:mm a').format(entry)}'].join('  ·  ')
            : (spot != null ? 'Spot $spot is ready for you' : 'Your spot is ready'),
        style: subtitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Pressable(
      onTap: onTap,
      depth: PressDepth.subtle,
      tint: false,
      borderRadius: AppRadius.card,
      semanticLabel: parked
          ? 'Parking session in progress at ${booking.parking.name}. Open session.'
          : 'Upcoming booking at ${booking.parking.name}. Open booking.',
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: AppRadius.card,
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: parked
                  ? const LivePulse(size: 9)
                  : const Icon(Icons.schedule_rounded, size: 20, color: AppColors.white),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(color: AppColors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  subtitle,
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.white),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
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
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? AppColors.ink : AppColors.inkTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      // Restated here: excludeSemantics also removes the detector's tap action.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.activeIcon : destination.icon,
              size: 24,
              color: colour,
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: context.text.labelSmall?.copyWith(
                color: colour,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
