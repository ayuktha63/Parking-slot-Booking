// ─────────────────────────────────────────────────────────────────────────────
// MAP MARKERS
//
// A price pill per place: white with black text, black when selected. Places that
// cannot take you right now (full, closed) stay on the map but step back — grey
// text, no availability dot — so the eye lands on the ones that can.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/availability_badge.dart';

class ParkingMapMarker extends StatelessWidget {
  const ParkingMapMarker({
    super.key,
    required this.parking,
    required this.isSelected,
    required this.onTap,
  });

  final ParkingSummary parking;
  final bool isSelected;
  final VoidCallback onTap;

  static const double width = 96;
  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    final state = parking.availability.state;
    final isClosed = state == AvailabilityState.closed || !parking.isOpenNow;
    final isFull = state == AvailabilityState.full;
    final recedes = isClosed || isFull;

    final background = isSelected ? AppColors.ink : AppColors.surface;
    final foreground = isSelected
        ? AppColors.onInk
        : recedes
            ? AppColors.inkTertiary
            : AppColors.ink;
    final label = isClosed ? 'Closed' : parking.price.hourly.display;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${parking.name}. ${isClosed ? 'Closed' : '$label per hour'}. '
          '${availabilitySentence(parking.availability, isOpen: !isClosed)}',
      // Restated here: excludeSemantics also removes the detector's tap action.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isSelected ? 1.12 : 1,
          duration: AppMotion.quick,
          curve: AppMotion.spring,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.quick,
                curve: AppMotion.standard,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: AppRadius.chip,
                  border: Border.all(
                    color: isSelected ? AppColors.ink : const Color(0x14000000),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x29000000), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!recedes) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: availabilityColour(state),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.white, width: 1)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: AppTypography.numeric(
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(12, 6),
                painter: _TailPainter(color: background),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

/// Several places too close to separate at this zoom.
class ClusterMarker extends StatelessWidget {
  const ClusterMarker({
    super.key,
    required this.count,
    required this.onTap,
    this.hasAvailability = true,
  });

  final int count;
  final VoidCallback onTap;
  final bool hasAvailability;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count parking places here. '
          '${hasAvailability ? 'Some have space' : 'All full or closed'}. Zoom in to see them',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hasAvailability ? AppColors.ink : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            count > 99 ? '99+' : '$count',
            style: AppTypography.numeric(
              size: 14,
              weight: FontWeight.w700,
              color: hasAvailability ? AppColors.onInk : AppColors.inkTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
