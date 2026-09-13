// ─────────────────────────────────────────────────────────────────────────────
// HOME — the map IS the home screen
//
// ─────────────────────────────────────────────────────────────────────────────
// WHAT THIS REPLACES, AND WHY IT WAS WRONG
//
// The previous Home was a vertical stack of white boxes on a white page: a
// greeting ("Good evening, Aashish") taking the most valuable pixels on the
// screen, a large amber banner about location permission, a row of grey filter
// chips, then a list of tall cards each carrying its own violet Reserve button.
// The map — the single most useful object in a parking product — was reachable
// only through a small "See map" text link.
//
// That ordering states the product's priorities, and they were backwards. A
// driver opening a parking app is somewhere, in a car, now. They are not reading
// a greeting; they are looking for a space near a point on a map. So:
//
//   * The map is the screen. Full-bleed, edge to edge, behind everything.
//   * Search is the hero control, floating over the map, the largest target.
//   * Results live in a sheet the user drags between "mostly map" and "mostly
//     list". Both views are one screen, so there is no mode to lose track of.
//   * The greeting is gone. It cost a line of display type to tell the user
//     something they already knew.
//   * Location failure is a quiet inline notice, not a banner the size of a
//     card. It is a condition, not an emergency.
//   * Vehicle type is a segmented switch, visually separate from filters.
//     Car-or-bike changes what every price and count on screen MEANS; a filter
//     merely narrows a list. Rendering them as identical grey chips in one row
//     made a semantic difference invisible.
//
// THIS SCREEN ABSORBED THE EXPLORE TAB.
//   Home and Explore had become two tabs rendering the same map against the same
//   providers, differing only in what else was stacked on top. Keeping both
//   would have meant maintaining two copies of camera handling, clustering and
//   marker selection, and asking the user to learn which tab was the "real" map.
//   Explore's logic lives here — camera tweening, grid clustering, viewport
//   search, marker/list sync — and `/explore` redirects to `/home`. The nav is
//   three real destinations instead of four, one of which was a duplicate.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/discovery_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/location_service.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/map_canvas.dart';
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/parking_card.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../explore/presentation/filter_sheet.dart';
import '../../explore/presentation/map_marker.dart';
import '../../../core/network/api_exception.dart';
import '../../parking/data/parking_repository.dart' show GeoBounds, ParkingQuery, ParkingSort;


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  final MapController _map = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// Guards the camera-move handler from firing while we move the camera
  /// ourselves, which would otherwise offer "Search this area" after every
  /// programmatic recentre.
  bool _programmaticMove = false;
  Timer? _moveDebounce;

  /// Whether `FlutterMap` has actually mounted and linked its internal
  /// controller to [_map]. Set by [MapOptions.onMapReady].
  ///
  /// Needed because `_map.camera` throws until that link exists — and
  /// `_buildMarkers()` reads it synchronously while constructing `FlutterMap`'s
  /// own `children` list, i.e. strictly BEFORE `FlutterMap`'s `initState` does
  /// the linking. Every cold navigation to the map crashed with
  /// `LateInitializationError: Field '_internalController' has not been
  /// initialized` — found only by running on a device; `flutter analyze` cannot
  /// see a lifecycle ordering bug like this.
  ///
  /// (`LateInitializationError` lives in `dart:_internal` and cannot be imported
  /// or caught by name from app code, which is why this is a readiness flag
  /// rather than a try/catch.)
  bool _mapReady = false;

  // NB: no map-layers control.
  //
  // The reference shows one, and it was built and then removed. OpenStreetMap's
  // raster tiles have no label-free, satellite or terrain variant: every option
  // such a button could offer needs a tile source this app does not have and
  // cannot get without an API key and a billing account. A layers button that
  // opens a menu of one item, or that toggles something invisible, is a
  // fabricated feature — which is the one thing this product does not do.

  double get _safeZoom => _mapReady ? _map.camera.zoom : AppConfig.mapDefaultZoom;

  /// Sheet stops. Peek shows the header and the top of the first card — enough to
  /// prove there are results without covering the map.
  static const double _peek = 0.16;
  static const double _mid = 0.46;
  static const double _full = 0.92;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialise());
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _initialise() async {
    await ref.read(locationProvider.notifier).initialise();
    if (!mounted) return;

    final centre = ref.read(locationProvider).position;
    if (centre != null) _moveCamera(centre, AppConfig.mapDefaultZoom);
    await _searchVisible();
  }

  GeoBounds _visibleBounds() {
    final bounds = _map.camera.visibleBounds;
    return GeoBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
    );
  }

  Future<void> _searchVisible() async {
    if (!_mapReady) return;
    await ref.read(mapControllerProvider.notifier).searchVisibleArea(_visibleBounds());
  }

  /// Animated camera movement. `flutter_map` moves instantly, so the tween is
  /// here — an instant jump gives the user no way to keep track of where the map
  /// went, which is disorienting in a spatial interface.
  void _moveCamera(LatLng target, double zoom) {
    if (!_mapReady) return;
    _programmaticMove = true;

    final startCentre = _map.camera.center;
    final startZoom = _map.camera.zoom;

    final controller = AnimationController(vsync: this, duration: AppMotion.camera);
    final curve = CurvedAnimation(parent: controller, curve: AppMotion.decelerate);

    final latTween = Tween(begin: startCentre.latitude, end: target.latitude);
    final lngTween = Tween(begin: startCentre.longitude, end: target.longitude);
    final zoomTween = Tween(begin: startZoom, end: zoom);

    controller.addListener(() {
      _map.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoomTween.evaluate(curve),
      );
    });

    controller.forward().whenComplete(() {
      controller.dispose();
      // Released on the next frame so the final move event is still suppressed.
      WidgetsBinding.instance.addPostFrameCallback((_) => _programmaticMove = false);
    });
  }

  void _onMapEvent(MapEvent event) {
    if (_programmaticMove) return;
    if (event is! MapEventMoveEnd && event is! MapEventFlingAnimationEnd) return;

    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      ref.read(mapControllerProvider.notifier).onCameraMoved(
            centre: _map.camera.center,
            zoom: _map.camera.zoom,
          );
    });
  }

  /// Marker tap → select it and bring the sheet up far enough to show the card,
  /// without burying the marker the user just touched.
  void _selectParking(ParkingSummary parking) {
    ref.read(mapControllerProvider.notifier).selectParking(parking.id);

    final position = parking.location.latLng;
    if (position != null) _moveCamera(position, _safeZoom);

    if (_sheet.isAttached && _sheet.size < _peek + 0.02) {
      _sheet.animateTo(_mid, duration: AppMotion.normal, curve: AppMotion.standard);
    }
  }

  Future<void> _recentre() async {
    final notifier = ref.read(locationProvider.notifier);
    await notifier.requestPermission();
    if (!mounted) return;

    final position = ref.read(locationProvider).position;
    if (position != null) {
      _moveCamera(position, AppConfig.mapDefaultZoom);
      await _searchVisible();
    }
  }

  Future<void> _openFilters() async {
    await showFilterSheet(context);
    // Filters changed the shared discovery query; re-query the viewport so the
    // map shows the same results as the list.
    if (mounted) await _searchVisible();
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider);
    final location = ref.watch(locationProvider);
    final query = ref.watch(discoveryQueryProvider);
    final results = mapState.markers;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // The status bar sits over the dark map, so its icons must be light. This is
    // the payoff of committing to a dark map: the chrome above it is unambiguous.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        // Chrome floats over the map; the map must reach the very top of the
        // screen or it reads as a widget embedded in a page.
        extendBodyBehindAppBar: true,
        backgroundColor: AppMapStyle.base,
        body: Stack(
          children: [
            // ── the map ────────────────────────────────────────────────────
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: location.position ??
                    const LatLng(AppConfig.fallbackLat, AppConfig.fallbackLng),
                initialZoom: AppConfig.mapDefaultZoom,
                minZoom: AppConfig.mapMinZoom,
                maxZoom: AppConfig.mapMaxZoom,
                backgroundColor: AppMapStyle.base,
                onMapEvent: _onMapEvent,
                onTap: (_, __) =>
                    ref.read(mapControllerProvider.notifier).selectParking(null),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  setState(() => _mapReady = true);
                  _searchVisible();
                },
              ),
              children: [
                const ParqxTileLayer(),
                // Above the tiles, below the markers — tinting the markers too
                // would undo the contrast the filter exists to create.
                const ParqxMapTint(),
                if (location.hasPosition)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location.position!,
                        width: UserLocationMarker.size,
                        height: UserLocationMarker.size,
                        child: const UserLocationMarker(),
                      ),
                    ],
                  ),
                MarkerLayer(markers: _buildMarkers(results)),
              ],
            ),

            // Darkens the top of the map so chrome stays readable over whatever
            // happens to be under it, without a hard-edged bar.
            const Positioned(top: 0, left: 0, right: 0, child: FadeEdge.mapTop()),

            // ── floating chrome ────────────────────────────────────────────
            //
            // Fades with the sheet: at full extent the sheet covers the map, and
            // the header was left poking out above its rounded top edge like a
            // screen that had not finished loading. Pulling the sheet back down
            // brings it straight back.
            _FadeWithSheet(
              controller: _sheet,
              mid: _mid,
              full: _full,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      _Greeting(
                        location: location,
                        // Where the results actually are. Without a GPS fix the
                        // app still knows what it is showing, and naming that
                        // is more useful — and more honest — than a warning.
                        areaLabel: results.isEmpty
                            ? null
                            : results.first.location.city ??
                                results.first.location.locality,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ParqxSearchBar(onTap: () => context.push(Routes.search)),
                      const SizedBox(height: AppSpacing.md),
                      _ControlRow(
                        query: query,
                        activeQuickFilter:
                            ref.read(discoveryQueryProvider.notifier).activeQuickFilter,
                        onFilters: _openFilters,
                        onVehicleChanged: (type) async {
                          ref.read(discoveryQueryProvider.notifier).setVehicleType(type);
                          await _searchVisible();
                        },
                        onQuickFilter: (filter) async {
                          ref.read(discoveryQueryProvider.notifier).toggleQuickFilter(filter);
                          await _searchVisible();
                        },
                      ),
                      if (mapState.showSearchThisArea) ...[
                        const SizedBox(height: AppSpacing.md),
                        Center(
                          child: _SearchThisArea(
                            isLoading: mapState.isLoading,
                            onTap: _searchVisible,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── map controls, pinned just above the resting sheet ──────────
            AnimatedBuilder(
              animation: _sheet,
              builder: (context, child) {
                final height = MediaQuery.sizeOf(context).height;
                final extent = _sheet.isAttached ? _sheet.size : _mid;
                final sheetTop = extent * height;

                // Fade the map controls out as the sheet takes over the screen.
                //
                // They are positioned against the sheet's top edge, so at full
                // extent they ride up into the floating chrome and collide with
                // the filter button and the search bar. They are also controls
                // for a map that is, at that point, almost entirely covered —
                // so fading them is the honest behaviour as well as the tidy
                // one. `IgnorePointer` goes with it, or an invisible button
                // keeps eating taps meant for the search bar.
                final visibility = (1 - ((extent - _mid) / (_full - _mid))).clamp(0.0, 1.0);

                return Positioned(
                  right: AppSpacing.lg,
                  bottom: sheetTop + AppSpacing.md,
                  child: IgnorePointer(
                    ignoring: visibility < 0.3,
                    child: Opacity(opacity: visibility, child: child!),
                  ),
                );
                // NB: kept inline rather than using _FadeWithSheet because this
                // one also needs `extent` for its POSITION, not only its opacity.
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const MapAttribution(),
                  const SizedBox(height: AppSpacing.sm),
                  ParqxRoundControl(
                    icon: location.hasPosition
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    tooltip: 'Recentre on my location',
                    active: location.hasPosition,
                    onTap: _recentre,
                  ),
                ],
              ),
            ),

            // ── location affordance, bottom-left over the map ──────────────
            AnimatedBuilder(
              animation: _sheet,
              builder: (context, child) {
                final height = MediaQuery.sizeOf(context).height;
                final extent = _sheet.isAttached ? _sheet.size : _mid;
                final visibility =
                    (1 - ((extent - _mid) / (_full - _mid))).clamp(0.0, 1.0);
                return Positioned(
                  left: AppSpacing.pageInset,
                  bottom: extent * height + AppSpacing.md,
                  child: IgnorePointer(
                    ignoring: visibility < 0.3,
                    child: Opacity(opacity: visibility, child: child!),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!location.hasPosition)
                    _UseMyLocation(
                      resolving: location.status == LocationStatus.requesting,
                      onTap: _recentre,
                    ),
                  if (location.hasPosition)
                    const ParqxStatusLine(label: 'Showing parking near you')
                  else if (location.status != LocationStatus.requesting) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ParqxStatusLine(
                      label: 'Showing parking in this area',
                      colour: AppColors.inkMutedDark,
                    ),
                  ],
                ],
              ),
            ),

            // ── results ────────────────────────────────────────────────────
            _ResultsSheet(
              controller: _sheet,
              peek: _peek,
              mid: _mid,
              full: _full,
              results: results,
              isLoading: mapState.isLoading,
              error: mapState.error,
              selectedId: mapState.selectedId,
              truncated: mapState.truncated,
              hasLocation: location.hasPosition,
              query: query,
              bottomInset: bottomInset,
              onRetry: _searchVisible,
              onSelect: (p) {
                ref.read(mapControllerProvider.notifier).selectParking(p.id);
                final position = p.location.latLng;
                if (position != null) _moveCamera(position, _safeZoom);
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ── markers ──────────────────────────────────────────────────────────── */

  List<Marker> _buildMarkers(List<ParkingSummary> parkings) {
    final selectedId = ref.read(mapControllerProvider).selectedId;
    final zoom = _safeZoom;

    final clusters = _cluster(parkings, zoom);

    return clusters.map((cluster) {
      if (cluster.items.length == 1) {
        final parking = cluster.items.first;
        return Marker(
          point: cluster.centre,
          width: ParkingMapMarker.width,
          height: ParkingMapMarker.height,
          alignment: Alignment.topCenter,
          child: ParkingMapMarker(
            parking: parking,
            isSelected: parking.id == selectedId,
            onTap: () => _selectParking(parking),
          ),
        );
      }

      return Marker(
        point: cluster.centre,
        width: ClusterMarker.size,
        height: ClusterMarker.size,
        child: ClusterMarker(
          count: cluster.items.length,
          hasAvailability: cluster.items.any((p) => p.availability.state.isBookable),
          // Tapping a cluster zooms into it rather than opening an ambiguous list.
          onTap: () =>
              _moveCamera(cluster.centre, (zoom + 2).clamp(3, AppConfig.mapMaxZoom)),
        ),
      );
    }).toList(growable: false);
  }

  /// Grid clustering: bucket by rounded coordinate at a resolution derived from
  /// zoom. Cheap, stable, and good enough for city-scale marker counts.
  List<_Cluster> _cluster(List<ParkingSummary> parkings, double zoom) {
    final withPosition = parkings.where((p) => p.location.hasCoordinates).toList();

    // Above this zoom every lot gets its own pill.
    if (zoom >= 15 || withPosition.length <= 8) {
      return withPosition
          .map((p) => _Cluster(centre: p.location.latLng!, items: [p]))
          .toList(growable: false);
    }

    // Cell size halves with each zoom level, so clusters break apart naturally
    // as the user zooms in. Clamped so the shift can never be negative.
    final shift = (zoom.round().clamp(1, 20) - 8).clamp(0, 12);
    final cellSize = 0.6 / (1 << shift);

    final buckets = <String, List<ParkingSummary>>{};

    for (final p in withPosition) {
      final lat = p.location.lat!;
      final lng = p.location.lng!;
      final key = '${(lat / cellSize).floor()}:${(lng / cellSize).floor()}';
      buckets.putIfAbsent(key, () => []).add(p);
    }

    return buckets.values.map((items) {
      final lat = items.map((p) => p.location.lat!).reduce((a, b) => a + b) / items.length;
      final lng = items.map((p) => p.location.lng!).reduce((a, b) => a + b) / items.length;
      return _Cluster(centre: LatLng(lat, lng), items: items);
    }).toList(growable: false);
  }
}

/// Fades a map-layer child out as the results sheet takes over the screen.
///
/// One definition, used by both the chrome and the map controls, so they cannot
/// disappear at different rates and look like a bug.
class _FadeWithSheet extends StatelessWidget {
  const _FadeWithSheet({
    required this.controller,
    required this.mid,
    required this.full,
    required this.child,
  });

  final DraggableScrollableController controller;
  final double mid;
  final double full;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, inner) {
        final extent = controller.isAttached ? controller.size : mid;
        final visibility = (1 - ((extent - mid) / (full - mid))).clamp(0.0, 1.0);
        return IgnorePointer(
          // Below this the control is too faint to aim at, and an invisible
          // button that still eats taps is worse than no button.
          ignoring: visibility < 0.3,
          child: Opacity(opacity: visibility, child: inner),
        );
      },
      child: child,
    );
  }
}

class _Cluster {
  const _Cluster({required this.centre, required this.items});
  final LatLng centre;
  final List<ParkingSummary> items;
}

/* ── greeting ──────────────────────────────────────────────────────────────── */

/// Who you are, where you are, and what needs your attention.
///
/// The greeting earns its line by carrying the LOCATION with it — the one piece
/// of context that changes what every result below means. A greeting alone
/// would be a line of display type spent telling the user something they
/// already know, which is what it was before.
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.location, this.areaLabel});

  final LocationState location;
  final String? areaLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final name = user?.greetingName;
    final initial = (name?.isNotEmpty == true ? name![0] : '?').toUpperCase();

    return Row(
      children: [
        Pressable(
          onTap: () => context.go(Routes.profile),
          depth: PressDepth.firm,
          tint: false,
          borderRadius: BorderRadius.circular(AppSizes.avatarMd),
          semanticLabel: 'Your profile',
          child: Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(
              color: AppColors.brandSoftDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: context.text.titleMedium?.copyWith(
                color: AppColors.brandMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name == null ? _greeting() : '${_greeting()}, $name',
                style: context.text.titleMedium?.copyWith(color: AppColors.inkDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              _LocationLine(location: location, areaLabel: areaLabel),
            ],
          ),
        ),
      ],
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Where the results are coming from — and, when location is off, the way to
/// fix that.
///
/// This replaces a full-width amber card that occupied roughly a fifth of the
/// screen, permanently, for a condition the user may have chosen deliberately.
/// Denied location is a SETTING, not an error: the map works, the results are
/// real, and the only thing missing is distance sorting. So it is one tappable
/// line under the greeting, in the place a user already looks to find out where
/// they are.
class _LocationLine extends ConsumerWidget {
  const _LocationLine({required this.location, this.areaLabel});

  final LocationState location;

  /// The area the results are actually in, from the nearest result's own
  /// address. Not a guess about the user.
  final String? areaLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolving = location.status == LocationStatus.requesting;
    final known = location.hasPosition;

    // What this line says, in order of what is actually true:
    //
    //   resolving        "Finding you"
    //   GPS + area       "Bengaluru"        — near you, and we know where
    //   GPS, no area     "Near you"
    //   no GPS + area    "Bengaluru"        — where the MAP is looking. Still
    //                                         true, and the location icon marks
    //                                         that it is not a fix.
    //   no GPS, no area  the real reason    — the only case that needs words.
    //
    // The previous version showed "We couldn't get your location" in amber
    // whenever there was no fix. Denied location is a SETTING, not a failure:
    // the map works, the results are real, and the only thing missing is
    // distance sorting. Shouting about it on every frame was the loudest thing
    // on a screen whose job is to show parking.
    final String label;
    if (resolving) {
      label = 'Finding you';
    } else if (areaLabel != null) {
      label = areaLabel!;
    } else if (known) {
      label = 'Near you';
    } else {
      label = location.message;
    }

    final unresolved = !known && !resolving;

    return Pressable(
      enabled: !resolving,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: AppRadius.chip,
      semanticLabel: known
          ? 'Showing parking near $label'
          : '$label. ${location.actionLabel}',
      onTap: () {
        final notifier = ref.read(locationProvider.notifier);
        if (location.needsSystemSettings) {
          notifier.openSettings();
        } else {
          notifier.requestPermission();
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (resolving)
            const SizedBox(
              width: AppSizes.iconXs,
              height: AppSizes.iconXs,
              child: CircularProgressIndicator(
                  strokeWidth: 1.6, color: AppColors.inkMutedDark),
            )
          else
            Icon(
              known ? Icons.place_rounded : Icons.location_disabled_rounded,
              size: AppSizes.iconXs + 1,
              color: known ? AppColors.brandMuted : AppColors.inkMutedDark,
            ),
          const SizedBox(width: AppSpacing.xs + 2),
          Flexible(
            child: Text(
              label,
              style: context.text.bodySmall?.copyWith(
                color: AppColors.inkSecondaryDark,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 1),
          Icon(
            unresolved
                ? Icons.chevron_right_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: AppSizes.iconSm,
            color: AppColors.inkMutedDark,
          ),
        ],
      ),
    );
  }
}

/* ── vehicle switch + discovery filters ────────────────────────────────────── */

/// Vehicle on the left, discovery filters on the right, with real space between.
///
/// These were adjacent grey chips in one scrolling row separated by a 1px rule,
/// which made a semantic difference invisible: switching Car→Bike changes the
/// price, the availability count and the slot inventory of every result on
/// screen, while a quick filter merely reorders or hides some of them.
///
/// One is a segmented switch — a single setting with two positions. The others
/// are pills that toggle independently. The shapes now say which is which.
class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.query,
    required this.activeQuickFilter,
    required this.onFilters,
    required this.onVehicleChanged,
    required this.onQuickFilter,
  });

  final ParkingQuery query;
  final QuickFilter? activeQuickFilter;
  final VoidCallback onFilters;
  final ValueChanged<VehicleType> onVehicleChanged;
  final ValueChanged<QuickFilter> onQuickFilter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.chipHeight + 4,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                ParqxSegmented<VehicleType>(
                  value: query.vehicleType,
                  onChanged: onVehicleChanged,
                  height: AppSizes.chipHeight,
                  segmentWidth: 82,
                  options: const [
                    ParqxSegment(
                      value: VehicleType.car,
                      label: 'Car',
                      icon: Icons.directions_car_rounded,
                    ),
                    ParqxSegment(
                      value: VehicleType.bike,
                      label: 'Bike',
                      icon: Icons.two_wheeler_rounded,
                    ),
                  ],
                ),

                // A real gap, not a divider: the separation is the message.
                const SizedBox(width: AppSpacing.lg),

                ParqxFilterPill(
                  label: QuickFilter.nearMe.label,
                  icon: Icons.near_me_rounded,
                  selected: activeQuickFilter == QuickFilter.nearMe,
                  onTap: () => onQuickFilter(QuickFilter.nearMe),
                ),
                const SizedBox(width: AppSpacing.sm),
                ParqxFilterPill(
                  label: QuickFilter.cheapest.label,
                  icon: Icons.sell_outlined,
                  selected: activeQuickFilter == QuickFilter.cheapest,
                  onTap: () => onQuickFilter(QuickFilter.cheapest),
                ),
                const SizedBox(width: AppSpacing.sm),
                ParqxFilterPill(
                  label: QuickFilter.availableNow.label,
                  icon: Icons.check_circle_outline_rounded,
                  selected: activeQuickFilter == QuickFilter.availableNow,
                  onTap: () => onQuickFilter(QuickFilter.availableNow),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Pinned outside the scroller: the full filter sheet must be reachable
          // without scrolling a row of quick filters out of the way first.
          ParqxRoundControl(
            icon: Icons.tune_rounded,
            tooltip: 'All filters',
            active: query.hasFilters,
            badge: query.hasFilters,
            size: AppSizes.chipHeight,
            onTap: onFilters,
          ),
        ],
      ),
    );
  }
}

/// The floating "Use my location" affordance.
///
/// Shown only when location is NOT already known — once the map is centred on
/// the user it would be a button offering to do what has already happened.
class _UseMyLocation extends StatelessWidget {
  const _UseMyLocation({required this.resolving, required this.onTap});

  final bool resolving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: resolving ? null : onTap,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: AppRadius.chip,
      semanticLabel: 'Use my location',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltDark,
          borderRadius: AppRadius.chip,
          border: Border.all(color: AppColors.borderDark),
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (resolving)
              const SizedBox(
                width: AppSizes.iconSm,
                height: AppSizes.iconSm,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.brandMuted),
              )
            else
              const Icon(Icons.near_me_rounded,
                  size: AppSizes.iconSm, color: AppColors.brandMuted),
            const SizedBox(width: AppSpacing.sm),
            Text(
              resolving ? 'Finding you' : 'Use my location',
              style: context.text.labelMedium?.copyWith(
                color: AppColors.inkDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offered after the user has panned somewhere new.
class _SearchThisArea extends StatelessWidget {
  const _SearchThisArea({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: isLoading ? null : onTap,
      depth: PressDepth.firm,
      tint: false,
      borderRadius: AppRadius.chip,
      semanticLabel: 'Search this area',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: AppRadius.chip,
          boxShadow: AppShadows.brandLift,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: AppSizes.iconXs,
                height: AppSizes.iconXs,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onBrand),
              )
            else
              const Icon(Icons.refresh_rounded,
                  size: AppSizes.iconXs, color: AppColors.onBrand),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Search this area',
              style: context.text.labelMedium?.copyWith(
                color: AppColors.onBrand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── results sheet ─────────────────────────────────────────────────────────── */

class _ResultsSheet extends ConsumerWidget {
  const _ResultsSheet({
    required this.controller,
    required this.peek,
    required this.mid,
    required this.full,
    required this.results,
    required this.isLoading,
    required this.error,
    required this.selectedId,
    required this.truncated,
    required this.hasLocation,
    required this.query,
    required this.bottomInset,
    required this.onRetry,
    required this.onSelect,
  });

  final DraggableScrollableController controller;
  final double peek;
  final double mid;
  final double full;
  final List<ParkingSummary> results;
  final bool isLoading;
  final Object? error;
  final int? selectedId;
  final bool truncated;
  final bool hasLocation;
  final ParkingQuery query;
  final double bottomInset;
  final Future<void> Function() onRetry;
  final ValueChanged<ParkingSummary> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: mid,
      minChildSize: peek,
      maxChildSize: full,
      snap: true,
      snapSizes: [peek, mid, full],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.sheet,
            boxShadow: AppShadows.sheet,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.sheet,
            // Cards scrolling under the floating nav bar were being sliced by
            // its edge. Fading the last stretch of the sheet to transparent
            // makes them dissolve instead, so the nav reads as floating above a
            // continuous surface rather than as a bar laid on top of a list.
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
                stops: [0.0, 0.075],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SheetGrabber(),
                        _SheetHeader(
                          count: results.length,
                          isLoading: isLoading,
                          hasLocation: hasLocation,
                          truncated: truncated,
                          // Named from the nearest result's own locality, so
                          // the sheet says where the results ARE rather than
                          // where the app guessed the user might be.
                          areaLabel: results.isEmpty
                              ? null
                              : results.first.location.locality ??
                                  results.first.location.city,
                        ),
                      ],
                    ),
                  ),

                  // NB: no active-session card here any more. It was the first
                  // thing on Home; it is now its own destination, because a
                  // customer who is already parked is not on this screen to
                  // discover anything. The Active tab carries a live dot instead.

                  ..._body(context, ref),

                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: AppSpacing.bottomNavClearance + bottomInset,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref) {
    if (error != null && results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorStateView(
            error: asApiException(error),
            onRetry: onRetry,
            compact: true,
          ),
        ),
      ];
    }

    if (isLoading && results.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, __) => const ParkingCardSkeleton(),
          ),
        ),
      ];
    }

    if (results.isEmpty) {
      return [SliverToBoxAdapter(child: _EmptyResults(query: query))];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
        sliver: SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final parking = results[index];
            return EntranceFade(
              index: index,
              child: ParkingCard(
                parking: parking,
                isSelected: parking.id == selectedId,
                // No Reserve button. The whole card is the target, and the
                // decision it leads to — which slot, for how long — cannot be
                // made from a list row anyway.
                onTap: () {
                  onSelect(parking);
                  context.push(Routes.parkingDetail(parking.id));
                },
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _SheetHeader extends ConsumerWidget {
  const _SheetHeader({
    required this.count,
    required this.isLoading,
    required this.hasLocation,
    required this.truncated,
    required this.areaLabel,
  });

  final int count;
  final bool isLoading;
  final bool hasLocation;
  final bool truncated;

  /// Where the results actually are, from the nearest result's own locality —
  /// never a hardcoded city.
  final String? areaLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title;
    if (isLoading && count == 0) {
      title = 'Looking for parking';
    } else if (count == 0) {
      // Deliberately not "No parking here": the empty state directly below says
      // that, and saying it twice in adjacent blocks reads as a bug.
      title = 'Parking';
    } else {
      title = '$count place${count == 1 ? '' : 's'} to park';
    }

    final String subtitle;
    if (count == 0) {
      subtitle = 'Nothing in the area you are looking at';
    } else if (truncated) {
      subtitle = 'Showing the closest — zoom in for more';
    } else if (areaLabel != null) {
      subtitle = hasLocation ? 'Near $areaLabel' : 'In $areaLabel';
    } else {
      subtitle = hasLocation ? 'Nearest first' : 'In this area';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageInset,
        0,
        AppSpacing.pageInset,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.text.headlineMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isLoading && count > 0)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: SizedBox(
                width: AppSizes.iconSm,
                height: AppSizes.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (count > 1) _SortControl(current: ref.watch(discoveryQueryProvider).sort),
        ],
      ),
    );
  }
}

/// Reorders the results.
///
/// Only rendered when there is more than one result — a sort control over a
/// single row is a control that cannot do anything.
///
/// The options are the server's own `ParkingSort` values, so the ordering is
/// computed where the data is rather than re-sorted in Dart against a field the
/// client may not have (distance, for one, does not exist without location).
class _SortControl extends ConsumerWidget {
  const _SortControl({required this.current});

  final ParkingSort current;

  static const _offered = [
    ParkingSort.distance,
    ParkingSort.price,
    ParkingSort.availability,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLocation = ref.watch(locationProvider).hasPosition;

    return PopupMenuButton<ParkingSort>(
      initialValue: current,
      tooltip: 'Sort results',
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.field),
      onSelected: (sort) {
        Haptics.selection();
        ref.read(discoveryQueryProvider.notifier).setSort(sort);
      },
      itemBuilder: (context) => [
        for (final sort in _offered)
          PopupMenuItem(
            value: sort,
            // Sorting by distance needs a position to measure from. Offering it
            // without one would produce an order the server cannot honour.
            enabled: sort != ParkingSort.distance || hasLocation,
            child: Row(
              children: [
                Icon(
                  sort == current ? Icons.check_rounded : null,
                  size: AppSizes.iconSm,
                  color: AppColors.brand,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  sort.label,
                  style: context.text.bodyMedium?.copyWith(
                    color: sort == ParkingSort.distance && !hasLocation
                        ? AppColors.inkSubtle
                        : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadius.chip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert_rounded,
                size: AppSizes.iconSm, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpacing.xs + 2),
            Text(
              'Sort',
              style: context.text.labelMedium?.copyWith(
                color: AppColors.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends ConsumerWidget {
  const _EmptyResults({required this.query});

  final ParkingQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // With filters applied, the actionable next step is removing them — not
    // searching somewhere else.
    if (query.hasFilters) {
      return EmptyStateView(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matches here',
        message: 'No parking in this area matches all '
            '${query.activeFilterCount} '
            'filter${query.activeFilterCount == 1 ? '' : 's'}.',
        compact: true,
        action: TextButton.icon(
          onPressed: () => ref.read(discoveryQueryProvider.notifier).clearFilters(),
          icon: const Icon(Icons.filter_alt_off_rounded, size: AppSizes.iconSm),
          label: const Text('Clear filters'),
        ),
      );
    }

    return const EmptyStateView(
      icon: Icons.travel_explore_rounded,
      title: 'Try another area',
      message: 'Move the map, or search for a place to see parking there.',
      compact: true,
    );
  }
}
