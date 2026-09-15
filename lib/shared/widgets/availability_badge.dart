// ─────────────────────────────────────────────────────────────────────────────
// AVAILABILITY
//
// One vocabulary for how full a place is, used by markers, rows and the detail
// screen alike. Numbers come from the server; nothing here estimates.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../models/parking.dart';

/// The dot colour for an availability state.
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
      return AppColors.inkDisabled;
  }
}

/// The readable text colour for an availability state.
Color availabilityTextColour(AvailabilityState state) {
  switch (state) {
    case AvailabilityState.available:
      return AppColors.positive;
    case AvailabilityState.limited:
      return AppColors.warning;
    case AvailabilityState.full:
      return AppColors.negative;
    case AvailabilityState.closed:
    case AvailabilityState.unavailable:
      return AppColors.inkTertiary;
  }
}

/// "11 spots free", "2 spots left", "Full", "Closed".
String availabilitySentence(ParkingAvailability availability, {required bool isOpen}) {
  if (!isOpen || availability.state == AvailabilityState.closed) return 'Closed now';
  if (availability.totalSlots == 0) return 'No spots listed';
  final free = availability.availableSlots;
  if (free == 0) return 'Full';
  if (availability.state == AvailabilityState.limited) {
    return free == 1 ? 'Last spot' : '$free spots left';
  }
  return '$free spot${free == 1 ? '' : 's'} free';
}

/// A coloured dot with the availability sentence.
class AvailabilityText extends StatelessWidget {
  const AvailabilityText({
    super.key,
    required this.availability,
    required this.isOpen,
    this.style,
  });

  final ParkingAvailability availability;
  final bool isOpen;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final state = isOpen ? availability.state : AvailabilityState.closed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: availabilityColour(state), shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Flexible(
          child: Text(
            availabilitySentence(availability, isOpen: isOpen),
            style: (style ?? context.text.labelMedium)?.copyWith(
              color: availabilityTextColour(state),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
