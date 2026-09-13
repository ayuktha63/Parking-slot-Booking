// ─────────────────────────────────────────────────────────────────────────────
// PARKING CARD
//
// The discovery row on the results sheet. A white card on the sheet's white
// surface, separated by shadow rather than by an outline.
//
// ─────────────────────────────────────────────────────────────────────────────
// STRUCTURE
//
//   ┌──────────────────────────────────────────────┐
//   │ ┌──────┐  Name                        ₹45    │
//   │ │photo │  📍 Locality · 0.8 km    per hour   │
//   │ │ 96²  │  ● 11 slots available                │
//   │ └──────┘  ◷ Open 24/7            [  View  ]  │
//   │           CCTV  Security  EV                  │
//   └──────────────────────────────────────────────┘
//
// The photograph leads because it is what makes a lot read as a real place
// rather than a row in a database. Price is right-aligned so it forms a
// comparison column down the list — that comparison is the whole reason the
// list exists.
//
// ─────────────────────────────────────────────────────────────────────────────
// REAL DATA ONLY
//
//   photo       the operator's own uploaded photograph, or a generated
//               monogram. NEVER a stock image of somebody else's car park —
//               see ParqxPhoto for why that distinction is not negotiable.
//   rating      hidden entirely unless `rating_count > 0`. Never a row of grey
//               stars, never "New", never 4.5 as a placeholder.
//   distance    hidden without location permission. Not "-- km".
//   ETA         NOT SHOWN. `eta_minutes` exists on the model but the backend
//               derives it from straight-line distance, not routing. Rendering
//               it as "4 min away" would give a guess a real number's
//               confidence. The distance beside it is honest.
//   availability, price, open/closed — straight from the server, which is the
//               single authority on all three.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/parking.dart';
import 'amenity_visuals.dart';
import 'availability_badge.dart';
import 'interaction.dart';
import 'parqx_photo.dart';
import 'states.dart';
import 'surfaces.dart';

/// The shared-element tag linking a card to its detail screen.
///
/// Only the `full` variant flies. Two heroes sharing one tag on one screen is a
/// crash, not a nicer transition.
String parkingHeroTag(int parkingId) => 'parking-photo-$parkingId';

enum ParkingCardVariant {
  /// Results sheet and search results: the full decision.
  full,

  /// Fixed-width, for horizontal carousels.
  compact,

  /// Dense list row — no photograph, minimum height.
  row,
}

class ParkingCard extends StatelessWidget {
  const ParkingCard({
    super.key,
    required this.parking,
    required this.onTap,
    this.onReserve,
    this.variant = ParkingCardVariant.full,
    this.isSelected = false,
    this.width,
  });

  final ParkingSummary parking;
  final VoidCallback onTap;

  /// The "View" action. Falls back to [onTap] when not supplied, because the
  /// button and the card lead to the same place — the button exists to make
  /// that obvious, not to do something different.
  final VoidCallback? onReserve;

  final ParkingCardVariant variant;

  /// Highlighted when the matching map marker is selected.
  final bool isSelected;

  final double? width;

  bool get _closed =>
      !parking.isOpenNow || parking.availability.state == AvailabilityState.closed;

  /// One spoken sentence for the whole card.
  ///
  /// Without this a screen reader reads a pile of disconnected fragments — name,
  /// then "0.8 km", then "₹49", then "5 slots" — with no indication they
  /// describe the same place or that the thing is tappable.
  String _semanticLabel() {
    final parts = <String>[parking.name];

    if (parking.hasRating) {
      parts.add('rated ${parking.rating!.toStringAsFixed(1)} from '
          '${parking.ratingCount} review${parking.ratingCount == 1 ? '' : 's'}');
    }
    if (parking.hasDistance) parts.add('${parking.distanceLabel} away');

    final area = parking.location.shortAddress;
    if (area != null) parts.add(area);

    parts.add(parking.isOpenNow ? 'open now' : 'closed');
    parts.add(parking.availability.summary);
    parts.add('from ${parking.price.hourly.display} per hour');

    if (parking.amenityCodes.isNotEmpty) {
      parts.add(parking.amenityCodes.map(AmenityVisuals.labelFor).join(', '));
    }

    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    if (variant == ParkingCardVariant.row) {
      return Pressable(
        onTap: onTap,
        borderRadius: AppRadius.card,
        semanticLabel: _semanticLabel(),
        child: _RowBody(parking: parking, closed: _closed),
      );
    }

    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.card,
      semanticLabel: _semanticLabel(),
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.standard,
        width: width,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          // The selected state earns an outline, because it is the one piece of
          // information a shadow cannot carry.
          border: Border.all(
            color: isSelected ? AppColors.brand : Colors.transparent,
            width: 1.75,
          ),
          boxShadow: isSelected ? AppShadows.lg : AppShadows.md,
        ),
        child: _CardBody(
          parking: parking,
          closed: _closed,
          isSelected: isSelected,
          onReserve: onReserve ?? onTap,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.parking,
    required this.closed,
    required this.isSelected,
    required this.onReserve,
  });

  final ParkingSummary parking;
  final bool closed;
  final bool isSelected;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    // At large system text the three columns stop fitting; the card reflows
    // rather than shrinking type a user has explicitly asked to enlarge.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final stacked = scale > 1.3;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: parkingHeroTag(parking.id),
          // A Hero's child is re-parented mid-flight into an overlay with
          // different constraints; materialising it flat avoids the unbounded
          // assert a Row inside a Hero otherwise hits.
          flightShuttleBuilder: (_, __, ___, ____, toContext) =>
              Material(color: Colors.transparent, child: toContext.widget),
          child: ParqxPhoto(
            url: parking.coverPhotoUrl,
            seed: parking.name,
            width: AppSizes.cardPhoto,
            height: AppSizes.cardPhoto,
            dimmed: closed,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Details(
            parking: parking,
            closed: closed,
            isSelected: isSelected,
            onReserve: onReserve,
            stacked: stacked,
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.parking,
    required this.closed,
    required this.isSelected,
    required this.onReserve,
    required this.stacked,
  });

  final ParkingSummary parking;
  final bool closed;
  final bool isSelected;
  final VoidCallback onReserve;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    // Each part appears only if the server gave it: no "Unknown area", no
    // "-- km".
    final meta = <String>[
      if (parking.location.shortAddress != null) parking.location.shortAddress!,
      if (parking.hasDistance) parking.distanceLabel!,
    ];

    final price = _Price(parking: parking, dimmed: closed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          parking.name,
                          style: context.text.titleLarge?.copyWith(
                            color: closed ? AppColors.inkMuted : AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Rendered only when reviews genuinely exist.
                      if (parking.hasRating) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _Rating(rating: parking.rating!),
                      ],
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: AppSizes.iconXs, color: AppColors.inkSubtle),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            meta.join(' · '),
                            style: context.text.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!stacked) ...[
              const SizedBox(width: AppSpacing.sm),
              price,
            ],
          ],
        ),

        const SizedBox(height: AppSpacing.sm),
        _StatusLine(parking: parking, closed: closed),

        if (parking.amenityCodes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AmenityIconRow(codes: parking.amenityCodes, limit: 3, withLabels: true),
        ],

        if (stacked) ...[
          const SizedBox(height: AppSpacing.sm),
          price,
        ],

        const SizedBox(height: AppSpacing.sm + 2),
        Align(
          alignment: Alignment.centerRight,
          child: _ViewButton(emphasised: isSelected, onTap: onReserve),
        ),
      ],
    );
  }
}

/// Availability and hours on one line.
///
/// A `Wrap` rather than a `Row`: at 360px with large system text these do not
/// fit side by side, and the previous `Row` overflowed — caught by the render
/// harness, not by reading the code.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.parking, required this.closed});

  final ParkingSummary parking;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final availability = parking.availability;
    final accent = closed ? AppColors.inkMuted : availabilityColour(availability.state);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Count first: it decides whether the rest matters.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            // Flexible, not bare.
            //
            // A `Row` inside a `Wrap` is handed the Wrap's width as a LOOSE
            // constraint, so a Row with mainAxisSize.min sizes to its
            // children's intrinsic width and an unconstrained Text simply
            // overruns it. Measured at 33px on a 360px card, and 267px at 200%
            // text — invisible to the analyser, caught by the render harness.
            Flexible(
              child: Text(
                closed
                    ? 'Closed'
                    : '${availability.availableSlots} slot'
                        '${availability.availableSlots == 1 ? '' : 's'} available',
                style: context.text.labelMedium?.copyWith(
                  color: closed ? AppColors.inkMuted : AppColors.successDeep,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded,
                size: AppSizes.iconXs, color: AppColors.inkSubtle),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                parking.isOpen24x7
                    ? 'Open 24/7'
                    : (closed ? 'Closed now' : 'Limited hours'),
                style: context.text.labelMedium?.copyWith(color: AppColors.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.parking, required this.dimmed});

  final ParkingSummary parking;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parking.price.hourly.display,
          style: AppTypography.numeric(
            size: 20,
            weight: FontWeight.w800,
            color: dimmed ? AppColors.inkMuted : AppColors.ink,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'per hour',
          style: context.text.labelSmall?.copyWith(
            color: AppColors.inkSubtle,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

/// The card's supporting action.
///
/// The whole card is already tappable and leads to the same screen; this makes
/// that obvious to anyone scanning for a control. It is deliberately NOT a
/// full-width filled "Reserve": a list of those is a column of identical shouts,
/// and the decision it implies — which slot, for how long — cannot be made from
/// a list row anyway.
class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.emphasised, required this.onTap});

  final bool emphasised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: AppRadius.chip,
      semanticLabel: 'View',
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.standard,
        height: 38,
        width: 104,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Filled only for the selected card, so the sheet echoes the map:
          // exactly one row is emphasised, and it is the one whose marker is lit.
          color: emphasised ? AppColors.brand : AppColors.brandSoft,
          borderRadius: AppRadius.chip,
          boxShadow: emphasised ? AppShadows.brandLift : AppShadows.none,
        ),
        child: Text(
          'View',
          style: context.text.labelMedium?.copyWith(
            color: emphasised ? AppColors.onBrand : AppColors.brandStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A real rating, or nothing at all.
class _Rating extends StatelessWidget {
  const _Rating({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded,
            size: AppSizes.iconXs, color: AppColors.warningBright),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: AppTypography.numeric(
            size: 12.5,
            weight: FontWeight.w700,
            color: AppColors.inkSecondary,
          ),
        ),
      ],
    );
  }
}

/* ── dense row ─────────────────────────────────────────────────────────────── */

class _RowBody extends StatelessWidget {
  const _RowBody({required this.parking, required this.closed});

  final ParkingSummary parking;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final accent =
        closed ? AppColors.inkMuted : availabilityColour(parking.availability.state);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          ParqxPhoto(
            url: parking.coverPhotoUrl,
            seed: parking.name,
            width: 44,
            height: 44,
            borderRadius: AppRadius.tile,
            dimmed: closed,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  parking.name,
                  style: context.text.titleMedium?.copyWith(color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  closed ? 'Closed' : parking.availability.summary,
                  style: context.text.bodySmall?.copyWith(color: accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            parking.price.hourly.display,
            style: AppTypography.numeric(
              size: 15,
              weight: FontWeight.w700,
              color: closed ? AppColors.inkMuted : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── skeleton ──────────────────────────────────────────────────────────────── */

/// Co-located with the card so the two cannot drift apart.
///
/// A skeleton that does not match the shape it stands in for is worse than a
/// spinner: the layout visibly rearranges when real content lands.
class ParkingCardSkeleton extends StatelessWidget {
  const ParkingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingSkeleton(
            width: AppSizes.cardPhoto,
            height: AppSizes.cardPhoto,
            borderRadius: AppRadius.photo,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                LoadingSkeleton(height: 16, width: 160),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(height: 12, width: 110),
                SizedBox(height: AppSpacing.md),
                LoadingSkeleton(height: 12, width: 140),
                SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: LoadingSkeleton(height: 38, width: 104),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
