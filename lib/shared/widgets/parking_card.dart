// ─────────────────────────────────────────────────────────────────────────────
// PARKING CARD
//
// A place to park, as an option you choose — the way a ride app lists vehicle
// options: photo, name, where, how full, and the price on the right. Selection
// is a black outline, not a colour change.
//
//   full     the discovery list row
//   compact  a floating preview over the map
//   row      a dense line for search results and summaries
//
// Everything printed comes from the server. No rating is shown without reviews,
// no distance without a location, no photo that is not the operator's.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../models/parking.dart';
import 'amenity_visuals.dart';
import 'availability_badge.dart';
import 'buttons.dart';
import 'interaction.dart';
import 'parqx_photo.dart';
import 'states.dart';

String parkingHeroTag(int parkingId) => 'parking-photo-$parkingId';

enum ParkingCardVariant { full, compact, row }

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
  final VoidCallback? onReserve;
  final ParkingCardVariant variant;
  final bool isSelected;
  final double? width;

  bool get _closed =>
      !parking.isOpenNow || parking.availability.state == AvailabilityState.closed;

  String _semanticLabel() {
    final parts = <String>[parking.name];
    if (parking.hasRating) {
      parts.add('rated ${parking.rating!.toStringAsFixed(1)} from '
          '${parking.ratingCount} review${parking.ratingCount == 1 ? '' : 's'}');
    }
    if (parking.hasDistance) parts.add('${parking.distanceLabel} away');
    final area = parking.location.shortAddress;
    if (area != null) parts.add(area);
    parts.add(availabilitySentence(parking.availability, isOpen: !_closed));
    parts.add('${parking.price.hourly.display} per hour');
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      ParkingCardVariant.full => _FullRow(card: this),
      ParkingCardVariant.compact => _CompactCard(card: this),
      ParkingCardVariant.row => _DenseRow(card: this),
    };
  }
}

/* ── full ──────────────────────────────────────────────────────────────────── */

class _FullRow extends StatelessWidget {
  const _FullRow({required this.card});

  final ParkingCard card;

  @override
  Widget build(BuildContext context) {
    final parking = card.parking;
    final closed = card._closed;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final stacked = scale > 1.3;

    final meta = <String>[
      if (parking.location.shortAddress != null)
        parking.location.locality ?? parking.location.shortAddress!,
      if (parking.hasDistance) parking.distanceLabel!,
    ];

    final price = _Price(parking: parking, dimmed: closed);

    return Pressable(
      onTap: card.onTap,
      borderRadius: AppRadius.card,
      semanticLabel: card._semanticLabel(),
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.standard,
        width: card.width,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: card.isSelected ? AppColors.ink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: parkingHeroTag(parking.id),
              child: ParqxPhoto(
                url: parking.coverPhotoUrl,
                seed: parking.name,
                width: AppSizes.rowPhoto,
                height: AppSizes.rowPhoto,
                dimmed: closed,
              ),
            ),
            const SizedBox(width: AppSpacing.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          parking.name,
                          style: context.text.titleMedium?.copyWith(
                            color: closed ? AppColors.inkTertiary : AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!stacked) ...[const SizedBox(width: AppSpacing.sm), price],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (meta.isNotEmpty || parking.hasRating)
                    Row(
                      children: [
                        if (parking.hasRating) ...[
                          const Icon(Icons.star_rounded, size: 14, color: AppColors.ink),
                          const SizedBox(width: 2),
                          Text(
                            parking.rating!.toStringAsFixed(1),
                            style: context.text.bodyMedium?.copyWith(color: AppColors.ink),
                          ),
                          if (meta.isNotEmpty)
                            Text('  ·  ', style: context.text.bodyMedium),
                        ],
                        Expanded(
                          child: Text(
                            meta.join('  ·  '),
                            style: context.text.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Row(
                    children: [
                      Flexible(
                        child: AvailabilityText(
                          availability: parking.availability,
                          isOpen: !closed,
                        ),
                      ),
                      if (parking.isOpen24x7 && !closed) ...[
                        Text('  ·  ', style: context.text.bodySmall),
                        Text('24/7', style: context.text.bodySmall),
                      ],
                    ],
                  ),
                  if (parking.amenityCodes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    AmenityLine(codes: parking.amenityCodes, limit: 3),
                  ],
                  if (stacked) ...[const SizedBox(height: AppSpacing.sm), price],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.parking, required this.dimmed});

  final ParkingSummary parking;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          parking.price.hourly.display,
          style: AppTypography.numeric(
            size: 17,
            weight: FontWeight.w700,
            color: dimmed ? AppColors.inkTertiary : AppColors.ink,
          ),
          maxLines: 1,
          softWrap: false,
        ),
        Text('/hr', style: context.text.bodySmall),
      ],
    );
  }
}

/* ── compact (map preview) ─────────────────────────────────────────────────── */

class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.card});

  final ParkingCard card;

  @override
  Widget build(BuildContext context) {
    final parking = card.parking;
    final closed = card._closed;
    final bookable = parking.availability.state.isBookable && !closed;
    return Pressable(
      onTap: card.onTap,
      borderRadius: AppRadius.card,
      semanticLabel: card._semanticLabel(),
      child: Container(
        width: card.width,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: card.isSelected ? AppColors.ink : AppColors.line,
            width: card.isSelected ? 2 : 1,
          ),
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          children: [
            ParqxPhoto(
              url: parking.coverPhotoUrl,
              seed: parking.name,
              width: 56,
              height: 56,
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
                    style: context.text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AvailabilityText(availability: parking.availability, isOpen: !closed),
                  const SizedBox(height: 2),
                  Text(
                    '${parking.price.hourly.display}/hr'
                    '${parking.hasDistance ? '  ·  ${parking.distanceLabel}' : ''}',
                    style: context.text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (card.onReserve != null) ...[
              const SizedBox(width: AppSpacing.sm),
              PillButton(
                label: 'View',
                inverted: bookable,
                onPressed: card.onReserve,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ── dense row ─────────────────────────────────────────────────────────────── */

class _DenseRow extends StatelessWidget {
  const _DenseRow({required this.card});

  final ParkingCard card;

  @override
  Widget build(BuildContext context) {
    final parking = card.parking;
    final closed = card._closed;
    return Pressable(
      onTap: card.onTap,
      borderRadius: AppRadius.card,
      semanticLabel: card._semanticLabel(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AvailabilityText(availability: parking.availability, isOpen: !closed),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              parking.price.hourly.display,
              style: AppTypography.numeric(
                size: 15,
                weight: FontWeight.w700,
                color: closed ? AppColors.inkTertiary : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── skeleton ──────────────────────────────────────────────────────────────── */

class ParkingCardSkeleton extends StatelessWidget {
  const ParkingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(
            width: AppSizes.rowPhoto,
            height: AppSizes.rowPhoto,
            borderRadius: AppRadius.photo,
          ),
          SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton.text(width: 170, height: 16),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton.text(width: 120, height: 12),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton.text(width: 90, height: 12),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          LoadingSkeleton.text(width: 40, height: 16),
        ],
      ),
    );
  }
}
