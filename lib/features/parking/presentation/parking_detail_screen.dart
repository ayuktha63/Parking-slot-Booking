// ─────────────────────────────────────────────────────────────────────────────
// PARKING DETAIL
//
// Everything needed to decide, in the order people decide it: what it looks
// like, what it costs, whether there is space, when it is open, what it has,
// and where exactly it is. Then one black button.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/discovery_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/directions.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/amenity_visuals.dart';
import '../../../shared/widgets/availability_badge.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/map_canvas.dart';
import '../../../shared/widgets/parking_card.dart' show parkingHeroTag;
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/parqx_photo.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';

class ParkingDetailScreen extends ConsumerWidget {
  const ParkingDetailScreen({super.key, required this.parkingId});

  final int parkingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(parkingDetailProvider(parkingId));
    final vehicleType = ref.watch(discoveryQueryProvider.select((q) => q.vehicleType));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: detail.when(
          skipLoadingOnReload: true,
          loading: () => const _DetailSkeleton(),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorStateView(
              error: asApiException(error),
              onRetry: () => ref.invalidate(parkingDetailProvider(parkingId)),
            ),
          ),
          data: (parking) => _Content(parking: parking, vehicleType: vehicleType),
        ),
        bottomNavigationBar: detail.maybeWhen(
          skipLoadingOnReload: true,
          data: (parking) => _BookBar(parking: parking, vehicleType: vehicleType),
          orElse: () => null,
        ),
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({required this.parking, required this.vehicleType});

  final ParkingDetail parking;
  final VehicleType vehicleType;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  /// Whether the photo header has scrolled away. Over the photo the status bar
  /// icons are light; over the white pinned bar they are dark.
  bool _collapsed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final threshold = _Hero.expandedHeight - kToolbarHeight - MediaQuery.paddingOf(context).top;
    final collapsed = notification.metrics.pixels > threshold;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final parking = widget.parking;
    final vehicleType = widget.vehicleType;
    final summary = parking.summary;
    final position = summary.location.latLng;
    final address = summary.location.fullAddress ?? summary.location.shortAddress;
    final offersBoth = parking.carSlots > 0 && parking.bikeSlots > 0;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
      slivers: [
        _Hero(parking: parking, collapsed: _collapsed),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageInset,
              AppSpacing.xl,
              AppSpacing.pageInset,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.name, style: context.text.displaySmall),
                const SizedBox(height: AppSpacing.xs + 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (summary.hasRating)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: AppColors.ink),
                          const SizedBox(width: 2),
                          Text(
                            '${summary.rating!.toStringAsFixed(1)} (${summary.ratingCount})',
                            style: context.text.bodyMedium?.copyWith(color: AppColors.ink),
                          ),
                        ],
                      ),
                    if (summary.location.shortAddress != null)
                      Text(summary.location.shortAddress!, style: context.text.bodyMedium),
                    if (summary.hasDistance)
                      Text('·  ${summary.distanceLabel} away', style: context.text.bodyMedium),
                  ],
                ),
                if (offersBoth) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Segmented<VehicleType>(
                    value: vehicleType,
                    semanticLabel: 'Vehicle type',
                    onChanged: (type) =>
                        ref.read(discoveryQueryProvider.notifier).setVehicleType(type),
                    options: const [
                      SegmentOption(
                        value: VehicleType.car,
                        label: 'Car',
                        icon: Icons.directions_car_filled_rounded,
                      ),
                      SegmentOption(
                        value: VehicleType.bike,
                        label: 'Bike',
                        icon: Icons.two_wheeler_rounded,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _StatStrip(parking: parking),
                if (parking.pricing.surgeReason != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  InlineBanner(
                    message: parking.pricing.surgeReason!,
                    icon: Icons.trending_up_rounded,
                    tone: BannerTone.warning,
                  ),
                ],
                if (parking.instructions != null && parking.instructions!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  InlineBanner(
                    title: 'Getting in',
                    message: parking.instructions!,
                    icon: Icons.directions_walk_rounded,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (parking.hasAmenities)
          SliverToBoxAdapter(
            child: _Section(
              title: 'What this place offers',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cell = (constraints.maxWidth - AppSpacing.lg) / 2;
                  return Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      for (final amenity in parking.amenities)
                        SizedBox(
                          width: cell,
                          child: AmenityTile(
                            code: amenity.code,
                            label: amenity.label.isEmpty ? null : amenity.label,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        if (parking.hasDescription)
          SliverToBoxAdapter(
            child: _Section(
              title: 'About',
              child: Text(
                parking.description!,
                style: context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: _Section(title: 'Opening hours', child: _OpeningHours(parking: parking)),
        ),
        if (position != null)
          SliverToBoxAdapter(
            child: _Section(
              title: 'Location',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.card,
                    child: SizedBox(
                      height: 170,
                      child: StaticPlaceMap(position: position, zoom: 15.5),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address ?? summary.name,
                          style: context.text.bodyLarge,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      PillButton(
                        label: 'Directions',
                        icon: Icons.near_me_rounded,
                        onPressed: () => openDirectionsTo(context, position, summary.name),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
      ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.parking, required this.collapsed});

  final ParkingDetail parking;
  final bool collapsed;

  static const double expandedHeight = 260;

  @override
  Widget build(BuildContext context) {
    final summary = parking.summary;
    final photoUrl = summary.hasPhoto
        ? summary.coverPhotoUrl
        : (parking.hasPhotos ? parking.photos.first.url : null);
    final position = summary.location.latLng;
    final topInset = MediaQuery.paddingOf(context).top;

    final overPhoto = photoUrl != null && !collapsed;
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      systemOverlayStyle: overPhoto
          ? AppTheme.overlay.copyWith(
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : AppTheme.overlay,
      titleSpacing: 0,
      title: _CollapsingTitle(name: summary.name),
      leading: const Padding(
        padding: EdgeInsets.only(left: AppSpacing.md),
        child: Center(child: CollapsingBackButton()),
      ),
      leadingWidth: 64,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrl != null)
              Hero(
                tag: parkingHeroTag(summary.id),
                child: ParqxPhoto(
                  url: photoUrl,
                  seed: summary.name,
                  borderRadius: BorderRadius.zero,
                ),
              )
            else if (position != null)
              StaticPlaceMap(position: position, zoom: 16, showAttribution: false)
            else
              ParqxPhoto(url: null, seed: summary.name, borderRadius: BorderRadius.zero),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 72,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x59000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            if (parking.photos.length > 1)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: StatusBadge(
                  label: '${parking.photos.length} photos',
                  icon: Icons.photo_library_outlined,
                  tone: BadgeTone.dark,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The name fades into the pinned bar once the photo has scrolled away.
class _CollapsingTitle extends StatelessWidget {
  const _CollapsingTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final delta = (settings?.maxExtent ?? 0) - (settings?.minExtent ?? 0);
    final t = delta <= 0
        ? 0.0
        : (1 - ((settings!.currentExtent - settings.minExtent) / delta)).clamp(0.0, 1.0);
    return Opacity(
      opacity: ((t - 0.7) / 0.3).clamp(0.0, 1.0),
      child: Text(
        name,
        style: context.text.titleLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Price · Spots · Hours — the three facts that decide it.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.parking});

  final ParkingDetail parking;

  @override
  Widget build(BuildContext context) {
    final summary = parking.summary;
    final quote = parking.pricing;
    final open = summary.isOpenNow;
    final state = open ? summary.availability.state : AvailabilityState.closed;

    final free = quote.totalSlots > 0 ? quote.availableSlots : summary.availability.availableSlots;
    final total = quote.totalSlots > 0 ? quote.totalSlots : summary.availability.totalSlots;

    return AppSurface(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                value: quote.hourly.isZero ? summary.price.hourly.display : quote.hourly.display,
                label: 'per hour',
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.lineStrong),
            Expanded(
              child: _Stat(
                value: open ? '$free' : '—',
                valueColor: open ? availabilityTextColour(state) : AppColors.inkTertiary,
                label: open ? 'of $total spots free' : 'closed now',
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.lineStrong),
            Expanded(
              child: _Stat(
                value: summary.isOpen24x7 ? '24/7' : (open ? 'Open' : 'Closed'),
                valueColor: open ? AppColors.ink : AppColors.negative,
                label: summary.isOpen24x7 ? 'always open' : 'right now',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.valueColor});

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.numeric(
            size: 22,
            weight: FontWeight.w700,
            color: valueColor ?? AppColors.ink,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.text.bodySmall,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, AppSpacing.xl, AppSpacing.pageInset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Hairline(),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _OpeningHours extends StatelessWidget {
  const _OpeningHours({required this.parking});

  final ParkingDetail parking;

  @override
  Widget build(BuildContext context) {
    if (parking.summary.isOpen24x7) {
      return Row(
        children: [
          const Icon(Icons.schedule_rounded, size: AppSizes.iconMd),
          const SizedBox(width: AppSpacing.md),
          Text('Open 24 hours, every day', style: context.text.bodyLarge),
        ],
      );
    }
    if (!parking.hasOpeningHours) {
      return Text('Hours not listed by the operator', style: context.text.bodyLarge);
    }
    final today = DateTime.now().weekday % 7; // Dart Mon=1..Sun=7 → 0=Sunday
    return Column(
      children: [
        for (final h in parking.openingHours)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    h.dayOfWeek == today ? '${h.dayName} (today)' : h.dayName,
                    style: h.dayOfWeek == today
                        ? context.text.titleMedium
                        : context.text.bodyLarge?.copyWith(color: AppColors.inkSecondary),
                  ),
                ),
                Text(
                  h.range,
                  style: h.dayOfWeek == today ? context.text.titleMedium : context.text.bodyLarge,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BookBar extends ConsumerWidget {
  const _BookBar({required this.parking, required this.vehicleType});

  final ParkingDetail parking;
  final VehicleType vehicleType;

  void _chooseSpot(BuildContext context, WidgetRef ref) {
    final query = ref.read(discoveryQueryProvider);
    final args = SlotSelectionArgs(
      parkingId: parking.summary.id,
      parkingName: parking.summary.name,
      vehicleType: query.vehicleType,
      startAt: query.startAt ?? DateTime.now(),
      durationMinutes: query.durationMinutes,
    );
    context.push(args.location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = parking.summary;
    final bookable = summary.availability.state.isBookable && summary.isOpenNow;
    final hourly = parking.pricing.hourly.isZero ? summary.price.hourly : parking.pricing.hourly;

    final String label;
    if (bookable) {
      label = 'Choose a spot';
    } else if (!summary.isOpenNow) {
      label = 'Closed right now';
    } else {
      label = 'No spots free';
    }

    return BottomActionBar(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    hourly.display,
                    style: AppTypography.numeric(size: 22, weight: FontWeight.w700),
                  ),
                  Text(' /hr', style: context.text.bodyMedium),
                ],
              ),
              Text(
                '${vehicleType.label} · from now',
                style: context.text.bodySmall,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: PrimaryButton(
              label: label,
              onPressed: bookable ? () => _chooseSpot(context, ref) : null,
            ),
          ),
        ],
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
        LoadingSkeleton(height: 260, borderRadius: BorderRadius.zero),
        Padding(
          padding: EdgeInsets.all(AppSpacing.pageInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.sm),
              LoadingSkeleton.text(width: 230, height: 28),
              SizedBox(height: AppSpacing.md),
              LoadingSkeleton.text(width: 160),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(height: 84, borderRadius: AppRadius.card),
              SizedBox(height: AppSpacing.xxl),
              LoadingSkeleton.text(width: 140, height: 18),
              SizedBox(height: AppSpacing.lg),
              LoadingSkeleton(height: 60),
            ],
          ),
        ),
      ],
    );
  }
}
