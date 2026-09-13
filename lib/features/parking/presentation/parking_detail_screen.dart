// ─────────────────────────────────────────────────────────────────────────────
// PARKING DETAIL — a destination, not a row that expanded
//
// ─────────────────────────────────────────────────────────────────────────────
// THE HERO IS THE MAP
//
// This screen used to open with a 140px band of flat colour: a gradient
// generated from the lot's name, standing in for photos that do not exist
// (`parking_photos` has zero rows). Further down, after price and amenities,
// sat a separate "Location" section with a small map preview.
//
// So the screen spent its most valuable space on a placeholder, and buried the
// one genuinely useful image — where the place actually is — six sections later.
// The two are now one: the hero IS the map, centred on the lot, at the size the
// information deserves. The separate Location section is gone.
//
// It also carries the product's signature. Arriving from a dark map onto a
// screen led by the same dark map makes the detail page read as a place you
// zoomed into rather than a different app.
//
// The generated gradient survives as the fallback for a lot with no
// coordinates, which is a real case in this database.
//
// ─────────────────────────────────────────────────────────────────────────────
// REAL DATA ONLY
//   Every section renders only when the server actually sent its content — an
//   empty "Amenities" heading over nothing is worse than no heading. Ratings
//   appear only with a real review count. ETA is not shown: it is derived from
//   straight-line distance, not routing, and presenting it as a travel time
//   would be a fabricated claim (the distance beside it is honest).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/discovery_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/amenity_visuals.dart';
import '../../../shared/widgets/availability_badge.dart';
import '../../../shared/widgets/parking_card.dart' show parkingHeroTag;
import '../../../shared/widgets/map_canvas.dart';
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../../shared/widgets/interaction.dart';
import '../../explore/presentation/map_marker.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/states.dart';

class ParkingDetailScreen extends ConsumerWidget {
  const ParkingDetailScreen({super.key, required this.parkingId});

  final int parkingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(parkingDetailProvider(parkingId));

    return Scaffold(
      body: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorStateView(
            error: asApiException(error),
            onRetry: () => ref.invalidate(parkingDetailProvider(parkingId)),
          ),
        ),
        data: (parking) => _DetailContent(parking: parking),
      ),
      bottomNavigationBar: detail.maybeWhen(
        data: (parking) => _BottomBar(parking: parking),
        orElse: () => null,
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.parking});

  final ParkingDetail parking;

  @override
  Widget build(BuildContext context) {
    final summary = parking.summary;

    return CustomScrollView(
      slivers: [
        _MapHero(parking: parking),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.xl,
            AppSpacing.pageInset,
            AppSpacing.xxl,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Name and address are set over the hero; repeating them here
              // would be the same two lines twice within one screenful.
              if (summary.hasRating) ...[
                _RatingBlock(rating: summary.rating!, count: summary.ratingCount),
                const SizedBox(height: AppSpacing.lg),
              ],

              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AvailabilityBadge(availability: summary.availability),

                  // A lot that is open 24/7 is, necessarily, open now. Showing
                  // both chips stated one fact twice in two different colours
                  // and made the row look like three unrelated claims.
                  if (summary.isOpen24x7)
                    const StatusChip(
                      label: 'Open 24/7',
                      colour: AppColors.success,
                      icon: Icons.access_time_rounded,
                    )
                  else
                    StatusChip(
                      label: summary.isOpenNow ? 'Open now' : 'Closed',
                      colour: summary.isOpenNow ? AppColors.success : AppColors.inkMuted,
                      icon: summary.isOpenNow
                          ? Icons.check_circle_outline_rounded
                          : Icons.schedule_rounded,
                    ),

                  // Distance only. `etaLabel` is derived from straight-line
                  // distance at a fixed assumed speed — not routing, not
                  // traffic — so rendering it as "~4 min" would dress a guess
                  // up as a travel time.
                  if (summary.hasDistance)
                    StatusChip(
                      label: summary.distanceLabel!,
                      colour: AppColors.brand,
                      icon: Icons.near_me_rounded,
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── price ─────────────────────────────────────────────────
              _AvailabilityCard(quote: parking.pricing),

              if (parking.hasDescription) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('About', style: context.text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(parking.description!, style: context.text.bodyMedium),
              ],

              if (parking.hasAmenities) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Amenities', style: context.text.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final amenity in parking.amenities) AmenityChip.fromAmenity(amenity),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
              Text('Opening hours', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              _OpeningHours(parking: parking),

              if (parking.instructions != null && parking.instructions!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                InlineBanner(
                  message: parking.instructions!,
                  icon: Icons.info_outline_rounded,
                  tone: BannerTone.info,
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

/* ── hero ──────────────────────────────────────────────────────────────────── */

/// The lot, on the map, at the top of its own page.
///
/// Collapses to a compact bar as the page scrolls, keeping the back control and
/// the name available without a separate app bar appearing from nowhere.
class _MapHero extends StatelessWidget {
  const _MapHero({required this.parking});

  final ParkingDetail parking;

  static const double _expanded = 320;

  @override
  Widget build(BuildContext context) {
    final summary = parking.summary;
    final position = summary.location.latLng;

    return SliverAppBar(
      expandedHeight: _expanded,
      pinned: true,
      stretch: true,
      backgroundColor: AppMapStyle.base,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.onMap,
      leading: const _CircleBack(),
      // Light status-bar glyphs: the hero behind them is the dark basemap.
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: _CollapsedTitle(name: summary.name),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Hero(
          tag: parkingHeroTag(summary.id),
          flightShuttleBuilder: (_, __, ___, ____, toContext) =>
              Material(color: Colors.transparent, child: toContext.widget),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── what leads the screen, in order of what exists ──────────
              //
              //   photograph   the operator's own. Flies in from the discovery
              //                card, so the transition is continuous.
              //   map          no photo, but real coordinates: where the place
              //                IS, which is the next most useful picture of it.
              //   monogram     neither. Generated from the name — decoration
              //                that claims nothing.
              //
              // Never a stock photograph of somebody else's car park: that is a
              // lie about a place the customer is about to drive to, and it
              // looks exactly like the truth.
              if (summary.hasPhoto || parking.hasPhotos)
                ParqxPhoto(
                  url: summary.hasPhoto
                      ? summary.coverPhotoUrl
                      : parking.photos.first.url,
                  seed: summary.name,
                  borderRadius: BorderRadius.zero,
                  showMonogramInitials: false,
                )
              else if (position != null)
                _StaticMap(position: position, parking: summary)
              else
                ParqxPhoto(
                  url: null,
                  seed: summary.name,
                  borderRadius: BorderRadius.zero,
                  showMonogramInitials: false,
                ),

              // A scrim over the whole hero, not just its edges: a caption over
              // an arbitrary user-uploaded photograph is unreadable roughly half
              // the time, and which half is not knowable in advance.
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppGradients.photoScrim),
              ),
              const Positioned(
                top: 0, left: 0, right: 0,
                child: FadeEdge.mapTop(height: 150),
              ),

              Positioned(
                left: AppSpacing.pageInset,
                right: AppSpacing.pageInset,
                bottom: AppSpacing.lg,
                child: _HeroCaption(summary: summary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A non-interactive map centred on the lot.
///
/// Interaction is off deliberately: this is a picture of where the place is, and
/// a map that pans inside a scrolling page fights the page for every gesture.
/// "Directions" in the bottom bar is the real affordance for going there.
class _StaticMap extends StatelessWidget {
  const _StaticMap({required this.position, required this.parking});

  final LatLng position;
  final ParkingSummary parking;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: position,
          initialZoom: 16,
          backgroundColor: AppMapStyle.base,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          const ParqxTileLayer(),
          const ParqxMapTint(),
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: ParkingMapMarker.width,
                height: ParkingMapMarker.height,
                alignment: Alignment.topCenter,
                child: ParkingMapMarker(
                  parking: parking,
                  isSelected: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Name and address, set over the hero.
class _HeroCaption extends StatelessWidget {
  const _HeroCaption({required this.summary});

  final ParkingSummary summary;

  @override
  Widget build(BuildContext context) {
    final address = summary.location.fullAddress ?? summary.location.shortAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          summary.name,
          style: context.text.displaySmall?.copyWith(color: AppColors.onMap),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (address != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.place_rounded,
                  size: AppSizes.iconXs, color: AppColors.onMapMuted),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  address,
                  style: context.text.bodySmall?.copyWith(color: AppColors.onMapMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Appears only once the hero has collapsed, so the name is never shown twice.
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final deltaExtent = (settings?.maxExtent ?? 0) - (settings?.minExtent ?? 0);
    final t = deltaExtent <= 0
        ? 0.0
        : (1 - ((settings!.currentExtent - settings.minExtent) / deltaExtent))
            .clamp(0.0, 1.0);

    // Fades in only over the last third of the collapse, so it never overlaps
    // the large name still visible in the hero.
    final opacity = ((t - 0.65) / 0.35).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Text(
        name,
        style: context.text.titleLarge?.copyWith(color: AppColors.onMap),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Pressable(
        onTap: () => Navigator.of(context).maybePop(),
        depth: PressDepth.firm,
        tint: false,
        borderRadius: BorderRadius.circular(40),
        semanticLabel: 'Back',
        child: GlassPanel(
          onDark: true,
          opacity: 0.5,
          borderRadius: BorderRadius.circular(40),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.arrow_back_rounded,
                size: AppSizes.iconMd, color: AppColors.onMap),
          ),
        ),
      ),
    );
  }
}

/* ── price ─────────────────────────────────────────────────────────────────── */

/// Availability for the window the customer is browsing with, and the reason
/// the price is what it is.
///
/// This was a "Price" card, and it made the detail screen state the same number
/// three times within one screenful: on the map marker, in this card, and in the
/// sticky bottom bar beside the button. The bottom bar is the right place for it
/// — it travels with the action it applies to — so this card keeps what the bar
/// has no room for: how many slots are actually free, and any surge.
class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.quote});

  final PriceQuote quote;

  @override
  Widget build(BuildContext context) {
    final free = quote.availableSlots;
    final total = quote.totalSlots;
    final ratio = total == 0 ? 0.0 : (free / total).clamp(0.0, 1.0);
    final accent = free == 0
        ? AppColors.availabilityFull
        : ratio < 0.25
            ? AppColors.availabilityLimited
            : AppColors.availabilityPlenty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Free for your time',
                style: context.text.labelSmall?.copyWith(color: AppColors.inkMuted),
              ),
              const Spacer(),
              if (quote.isSurge)
                const StatusChip(
                  label: 'High demand',
                  colour: AppColors.warning,
                  icon: Icons.trending_up_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$free',
                style: AppTypography.numeric(
                  size: 30,
                  weight: FontWeight.w800,
                  color: accent,
                ),
              ),
              Text(
                ' of $total slot${total == 1 ? '' : 's'}',
                style: context.text.bodyMedium,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // A proportion bar rather than a second sentence. It answers "is this
          // place filling up?" faster than any wording can.
          ClipRRect(
            borderRadius: AppRadius.chip,
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  // Dark track. `surfaceSunken` is the light-surface well and
                  // rendered as a solid white bar on this card — the fill was
                  // invisible against it at high availability.
                  const Positioned.fill(
                    child: ColoredBox(color: AppColors.surfaceAltDark),
                  ),
                  FractionallySizedBox(
                    widthFactor: ratio == 0 ? 0.02 : ratio,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: AppRadius.chip,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Surge is explained rather than merely applied.
          if (quote.surgeReason != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(quote.surgeReason!, style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _RatingBlock extends StatelessWidget {
  const _RatingBlock({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: AppSizes.iconMd, color: AppColors.warning),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1), style: context.text.headlineSmall),
          ],
        ),
        Text('$count review${count == 1 ? '' : 's'}', style: context.text.bodySmall),
      ],
    );
  }
}

class _OpeningHours extends StatelessWidget {
  const _OpeningHours({required this.parking});

  final ParkingDetail parking;

  @override
  Widget build(BuildContext context) {
    if (parking.summary.isOpen24x7) {
      return Text('Open 24 hours, every day', style: context.text.bodyMedium);
    }

    // No hours recorded: say so, rather than implying always open.
    if (!parking.hasOpeningHours) {
      return Text('Hours not listed', style: context.text.bodyMedium);
    }

    final today = DateTime.now().weekday % 7; // Dart: Mon=1..Sun=7 → 0=Sunday

    return Column(
      children: [
        for (final h in parking.openingHours)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    h.dayName,
                    style: h.dayOfWeek == today
                        ? context.text.titleSmall
                        : context.text.bodyMedium,
                  ),
                ),
                Text(
                  h.range,
                  style: h.dayOfWeek == today
                      ? context.text.titleSmall
                      : context.text.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.parking});

  final ParkingDetail parking;

  Future<void> _openDirections(BuildContext context) async {
    final position = parking.summary.location.latLng;
    if (position == null) return;

    // Platform-neutral geo URI, with a web fallback so it works everywhere.
    final label = Uri.encodeComponent(parking.summary.name);
    final geo = Uri.parse('geo:${position.latitude},${position.longitude}?q='
        '${position.latitude},${position.longitude}($label)');
    final web = Uri.parse('https://www.google.com/maps/search/?api=1&query='
        '${position.latitude},${position.longitude}');

    if (await canLaunchUrl(geo)) {
      await launchUrl(geo);
    } else {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens Slot & Time, carrying the window the customer has been browsing with.
  ///
  /// Passing the window through means the slots they see are the ones free for the
  /// time they were already looking at — not a fresh "now" that quietly changes
  /// what is available between one screen and the next.
  void _chooseSlot(BuildContext context, WidgetRef ref) {
    final query = ref.read(discoveryQueryProvider);

    context.push(
      Routes.slotSelection,
      extra: SlotSelectionArgs(
        parkingId: parking.summary.id,
        parkingName: parking.summary.name,
        vehicleType: query.vehicleType,
        startAt: query.startAt ?? DateTime.now(),
        durationMinutes: query.durationMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = parking.summary;
    final bookable = summary.availability.state.isBookable && summary.isOpenNow;

    // Says WHY it cannot be booked instead of a flat "Not available". The
    // difference between "this lot is shut" and "this lot is full" is the
    // difference between coming back later and looking somewhere else.
    final String label;
    if (bookable) {
      label = 'Choose a slot';
    } else if (!summary.isOpenNow) {
      label = 'Closed right now';
    } else {
      label = 'No slots free';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.borderDark)),
        // Thrown upward, so the bar reads as floating above the page rather
        // than being ruled off from it.
        boxShadow: AppShadows.sheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageInset,
            AppSpacing.md,
            AppSpacing.pageInset,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              // The price travels with the action. Someone at the bottom of a
              // long page should not have to scroll back up to remember what
              // they are about to commit to.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'From',
                    style: context.text.labelSmall
                        ?.copyWith(color: AppColors.inkMutedDark),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        parking.pricing.hourly.display,
                        style: AppTypography.numeric(
                          size: 22,
                          weight: FontWeight.w700,
                          color: AppColors.inkDark,
                        ),
                      ),
                      Text(
                        ' /hr',
                        style: context.text.bodySmall
                            ?.copyWith(color: AppColors.inkMutedDark),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              if (summary.location.hasCoordinates) ...[
                // `onDark` so it takes a raised surface and a border, instead
                // of a dark circle disappearing into a dark bar.
                ParqxRoundControl(
                  icon: Icons.navigation_rounded,
                  tooltip: 'Directions',
                  size: AppSizes.buttonHeight,
                  onTap: () => _openDirections(context),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: PrimaryButton(
                  label: label,
                  onPressed: bookable ? () => _chooseSlot(context, ref) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        LoadingSkeleton(height: 240, borderRadius: BorderRadius.zero),
        Padding(
          padding: EdgeInsets.all(AppSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LoadingSkeleton.text(width: 220, height: 26),
              SizedBox(height: AppSpacing.md),
              LoadingSkeleton.text(width: 160),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(height: 96),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(height: 140),
            ],
          ),
        ),
      ],
    );
  }
}
