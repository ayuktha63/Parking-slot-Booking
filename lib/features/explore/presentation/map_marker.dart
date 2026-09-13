// ─────────────────────────────────────────────────────────────────────────────
// MAP MARKERS
//
// Custom price pills, not generic map pins.
//
// A pin tells you a lot exists. A pill tells you what it costs and whether it
// has space — which is the entire comparison a driver is making while scanning a
// map. States: available · limited · full · closed, plus a selected treatment.
//
// REDRAWN FOR THE DARK BASEMAP
//   These were designed against stock OSM tiles, where a marker had to fight
//   beige roads and green parks for attention — hence the coloured outline
//   around every pill, which was the only way to be seen.
//
//   On the near-black PARQX basemap the relationship inverts. A plain white pill
//   is already the brightest object on screen, so the outlines come off: they
//   were noise standing in for contrast that now exists for free. What replaces
//   them is a real value hierarchy —
//
//     available — bright white, full-strength ink, saturated accent dot.
//                 Comes forward.
//     limited   — the same, with the amber accent doing the warning.
//     full      — translucent dark glass, muted text. Recedes INTO the map.
//     closed    — the same, and says "Closed" instead of a price, because a
//                 price you cannot buy at is not information.
//     selected  — brand violet, lifted, glowing, and the only violet on screen.
//
//   Making unavailable lots recede is the point. The old treatment gave a full
//   lot the same white pill and the same visual weight as an empty one, so the
//   map presented six identical options of which two were usable.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/availability_badge.dart';

/// Price pill with a tail pointing at the exact location.
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

  /// Marker footprint. `flutter_map` needs a fixed size per marker, and the
  /// anchor is the bottom of the tail so the point sits on the coordinate.
  static const double width = 92;
  static const double height = 48;
  static const double selectedScale = 1.12;

  @override
  Widget build(BuildContext context) {
    final state = parking.availability.state;
    final accent = availabilityColour(state);
    final isClosed = state == AvailabilityState.closed || !parking.isOpenNow;
    final isFull = state == AvailabilityState.full;
    final recedes = isClosed || isFull;

    final Color background;
    final Color foreground;

    if (isSelected) {
      background = AppColors.brand;
      foreground = AppColors.onBrand;
    } else if (recedes) {
      // Dark glass: legible, but clearly behind the lots you can actually use.
      background = const Color(0xE6191428);
      foreground = AppColors.onMapMuted;
    } else {
      background = AppColors.white;
      foreground = AppColors.ink;
    }

    final label = isClosed ? 'Closed' : parking.price.hourly.display;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${parking.name}. '
          '${isClosed ? 'Closed' : '$label per hour'}. '
          '${parking.availability.state.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isSelected ? selectedScale : 1,
          duration: AppMotion.quick,
          curve: AppMotion.spring,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.quick,
                curve: AppMotion.standard,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 1,
                  AppSpacing.xs + 2,
                  AppSpacing.md - 1,
                  AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: AppRadius.chip,
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x805B34E8),
                            blurRadius: 18,
                            offset: Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Color(0x4D000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x59000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Availability dot: colour carries the state at a glance,
                    // the price carries the comparison.
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.white : accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      label,
                      style: AppTypography.priceCompact(color: foreground).copyWith(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _Tail(color: background, lifted: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pill's pointer.
///
/// Drawn with a rounded apex rather than a hard triangle — a sharp point reads
/// as a diagram callout, a softened one reads as part of the pill.
class _Tail extends StatelessWidget {
  const _Tail({required this.color, required this.lifted});

  final Color color;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 8),
      painter: _TailPainter(color: color, lifted: lifted),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.color, required this.lifted});

  final Color color;
  final bool lifted;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.38, size.height * 0.82)
      ..quadraticBezierTo(
        size.width / 2,
        size.height * 1.12,
        size.width * 0.62,
        size.height * 0.82,
      )
      ..lineTo(size.width, 0)
      ..close();

    if (lifted) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x665B34E8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color || old.lifted != lifted;
}

/// Cluster bubble shown when several lots overlap at low zoom.
///
/// Deliberately a different shape language from a price pill: a circle means
/// "several things here", a pill means "this thing, this price". Reusing the
/// pill shape for both would make a cluster look like a lot costing ₹12.
class ClusterMarker extends StatelessWidget {
  const ClusterMarker({
    super.key,
    required this.count,
    required this.onTap,
    this.hasAvailability = true,
  });

  final int count;
  final VoidCallback onTap;

  /// False when every lot in the cluster is full or closed.
  final bool hasAvailability;

  static const double size = 46;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count parking areas here. '
          '${hasAvailability ? 'Some have space' : 'All full or closed'}. '
          'Zoom in to see them',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hasAvailability ? AppColors.white : const Color(0xE6191428),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              count > 99 ? '99+' : '$count',
              style: AppTypography.numeric(
                size: 15,
                weight: FontWeight.w800,
                color: hasAvailability ? AppColors.ink : AppColors.onMapMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's own position.
///
/// Brand violet rather than the old system blue: this is PARQX telling you where
/// you are, and blue-dot-with-white-ring is the platform's mark, not ours.
class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({super.key});

  static const double size = 26;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your location',
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x805B34E8), blurRadius: 14, spreadRadius: 2),
            ],
          ),
        ),
      ),
    );
  }
}
