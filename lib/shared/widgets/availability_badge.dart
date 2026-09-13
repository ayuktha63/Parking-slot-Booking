// ─────────────────────────────────────────────────────────────────────────────
// AVAILABILITY BADGE & COLOURS
//
// One colour language for availability, used by cards, map markers, the slot map
// and the operator dashboard.
//
// The old apps used contradictory languages: the customer app drew occupied slots
// as a car icon with no legend at all, while the operator app used
// `stateBooked = errorRed` — so a fully-let lot, the best possible business
// outcome, rendered as a wall of error red.
//
// Here "occupied" is a settled neutral. Red is reserved for things that are wrong.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../models/parking.dart';

/// The single mapping from availability state to colour.
Color availabilityColour(AvailabilityState state) {
  switch (state) {
    case AvailabilityState.available:
      return AppColors.availabilityPlenty;
    case AvailabilityState.limited:
      return AppColors.availabilityLimited;
    case AvailabilityState.full:
      return AppColors.availabilityFull;
    case AvailabilityState.closed:
    case AvailabilityState.unavailable:
      return AppColors.inkMuted;
  }
}

Color availabilityBackground(AvailabilityState state) {
  switch (state) {
    case AvailabilityState.available:
      return AppColors.slotAvailableSoft;
    case AvailabilityState.limited:
      return AppColors.slotHeldSoft;
    case AvailabilityState.full:
      return AppColors.dangerSoft;
    case AvailabilityState.closed:
    case AvailabilityState.unavailable:
      return AppColors.slotOccupiedSoft;
  }
}

enum BadgeSize { small, regular }

/// "12 slots" with a state-coloured dot.
///
/// Shows a count rather than a bare word, because "12 slots available" answers the
/// user's real question and "Available" does not.
class AvailabilityBadge extends StatelessWidget {
  const AvailabilityBadge({
    super.key,
    required this.availability,
    this.size = BadgeSize.regular,
    this.showCount = true,
  });

  final ParkingAvailability availability;
  final BadgeSize size;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final state = availability.state;
    final colour = availabilityColour(state);
    final small = size == BadgeSize.small;

    final label = showCount ? availability.summary : state.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppSpacing.sm : AppSpacing.md,
        vertical: small ? 3 : AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        // Solid surface so it stays legible over a photograph.
        color: context.colors.surface,
        borderRadius: AppRadius.chip,
        border: Border.all(color: colour.withValues(alpha: 0.35)),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: small ? 6 : 7,
            height: small ? 6 : 7,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          SizedBox(width: small ? AppSpacing.xs + 1 : AppSpacing.sm),
          Text(
            label,
            style: (small ? context.text.labelSmall : context.text.labelMedium)?.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal legend for the slot map.
///
/// The operator app had one of these and it was the clearest thing in either app;
/// the customer slot screen had none, so a user could not tell why a slot was
/// untappable.
class SlotLegend extends StatelessWidget {
  const SlotLegend({super.key, this.entries = defaultEntries});

  static const defaultEntries = <(String, Color)>[
    ('Available', AppColors.slotAvailable),
    ('Selected', AppColors.slotSelected),
    ('Held', AppColors.slotHeld),
    ('Booked', AppColors.slotOccupied),
    ('Unavailable', AppColors.slotClosed),
  ];

  final List<(String, Color)> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (label, colour) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.22),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  border: Border.all(color: colour, width: 1.4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: context.text.bodySmall),
            ],
          ),
      ],
    );
  }
}

/// Small status pill used on booking cards.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.colour,
    this.icon,
  });

  final String label;
  final Color colour;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconXs, color: colour),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: colour, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
