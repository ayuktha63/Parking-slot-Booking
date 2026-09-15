// ─────────────────────────────────────────────────────────────────────────────
// HOME — the map
//
// A ride-app home: the whole screen is the map, and a white sheet rises from the
// bottom holding the question ("Where do you want to park?") and the answers —
// the places in view, as options you can compare and pick.
//
//   · The map searches what the camera shows. Moving it offers "Search this area".
//   · A typed search is not limited to the camera: it searches the city and the
//     map frames what it found.
//   · Tapping a price pill selects that place: the map centres on it and it moves
//     to the top of the sheet with a black outline.
//
// Every number on screen — price, spots free, distance — is the server's.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/booking_providers.dart';
import '../../../core/providers/discovery_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/location_service.dart';
import '../../../shared/models/parking.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/interaction.dart';
import '../../../shared/widgets/map_canvas.dart';
import '../../../shared/widgets/parking_card.dart';
import '../../../shared/widgets/parqx_controls.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/surfaces.dart';
import '../../explore/presentation/filter_sheet.dart';
import '../../explore/presentation/map_marker.dart';
import '../../parking/data/parking_repository.dart' show GeoBounds, ParkingQuery, ParkingSort;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  final MapController _map = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();
  ScrollController? _listController;

  bool _programmaticMove = false;
  Timer? _moveDebounce;
  bool _mapReady = false;

  double get _safeZoom => _mapReady ? _map.camera.zoom : AppConfig.mapDefaultZoom;

  /// The same list for the same sizes. The sheet compares snap sizes by
  /// identity, and a fresh list on every rebuild makes it re-settle to a snap
  /// point each time — cutting off a drag in progress when results arrive.
  List<double> _snapSizes = const [];

  List<double> _snapSizesFor(double peek, double mid, double full) {
    if (listEquals(_snapSizes, [peek, mid, full])) return _snapSizes;
    return _snapSizes = List.unmodifiable([peek, mid, full]);
  }

  /// Height of the sheet's always-visible part: grabber, search and chips.
  static const double _peekContent = 150;

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
    if (centre != null) _focus(centre, AppConfig.mapDefaultZoom);
    await _search();
  }

  /* ── searching ─────────────────────────────────────────────────────────── */

  /// Searches by the typed term when there is one, otherwise by the viewport.
  Future<void> _search() async {
    if (!_mapReady) return;
    final term = ref.read(discoveryQueryProvider).searchTerm;
    if (term != null && term.trim().isNotEmpty) {
      final positions = await ref.read(mapControllerProvider.notifier).searchText();
      if (mounted) _frame(positions);
      return;
    }
    await ref.read(mapControllerProvider.notifier).searchVisibleArea(_visibleBounds());
  }

  /// "Search this area": the viewport wins over a previous typed term.
  Future<void> _searchThisArea() async {
    ref.read(discoveryQueryProvider.notifier).setSearchTerm(null);
    await ref.read(mapControllerProvider.notifier).searchVisibleArea(_visibleBounds());
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

  /* ── camera ────────────────────────────────────────────────────────────── */

  /// Where the camera must centre so that [target] lands in the middle of the
  /// map that is actually visible — between the status bar and the sheet —
  /// rather than behind the sheet.
  LatLng _centreFor(LatLng target, double zoom, {double? sheetExtent}) {
    if (!_mapReady) return target;
    final media = MediaQuery.of(context);
    final height = media.size.height;
    final extent = sheetExtent ?? (_sheet.isAttached ? _sheet.size : 0.52);
    final visibleMiddle = (media.padding.top + height * (1 - extent)) / 2;
    final shift = height / 2 - visibleMiddle;
    final crs = _map.camera.crs;
    final point = crs.latLngToPoint(target, zoom);
    return crs.pointToLatLng(math.Point(point.x, point.y + shift), zoom);
  }

  /// Moves so [target] sits in the visible part of the map.
  void _focus(LatLng target, double zoom, {double? sheetExtent}) {
    _moveCamera(_centreFor(target, zoom, sheetExtent: sheetExtent), zoom);
  }

  void _moveCamera(LatLng target, double zoom) {
    if (!_mapReady) return;
    _programmaticMove = true;
    final startCentre = _map.camera.center;
    final startZoom = _map.camera.zoom;
    final controller = AnimationController(vsync: this, duration: AppMotion.camera);
    final curve = CurvedAnimation(parent: controller, curve: AppMotion.decelerate);
    final lat = Tween(begin: startCentre.latitude, end: target.latitude);
    final lng = Tween(begin: startCentre.longitude, end: target.longitude);
    final z = Tween(begin: startZoom, end: zoom);
    controller.addListener(() {
      _map.move(LatLng(lat.evaluate(curve), lng.evaluate(curve)), z.evaluate(curve));
    });
    controller.forward().whenComplete(() {
      controller.dispose();
      WidgetsBinding.instance.addPostFrameCallback((_) => _programmaticMove = false);
    });
  }

  /// Fits the camera around search results, leaving room for the sheet.
  void _frame(List<LatLng> positions) {
    if (!_mapReady || positions.isEmpty) return;
    if (positions.length == 1) {
      _focus(positions.first, 15.5);
      return;
    }
    _programmaticMove = true;
    final size = MediaQuery.sizeOf(context);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(positions),
        padding: EdgeInsets.fromLTRB(56, 120, 56, size.height * 0.5),
        maxZoom: 16,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _programmaticMove = false);
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

  void _selectFromMap(ParkingSummary parking) {
    Haptics.selection();
    ref.read(mapControllerProvider.notifier).selectParking(parking.id);
    final position = parking.location.latLng;
    final targetExtent = _sheet.isAttached && _sheet.size < 0.45 ? 0.5 : null;
    if (position != null) {
      _focus(position, math.max(_safeZoom, 15), sheetExtent: targetExtent);
    }
    if (targetExtent != null) {
      _sheet.animateTo(targetExtent, duration: AppMotion.normal, curve: AppMotion.standard);
    }
    final list = _listController;
    if (list != null && list.hasClients && list.offset > 0) {
      list.animateTo(0, duration: AppMotion.normal, curve: AppMotion.standard);
    }
  }

  Future<void> _recentre() async {
    await ref.read(locationProvider.notifier).requestPermission();
    if (!mounted) return;
    final position = ref.read(locationProvider).position;
    if (position != null) {
      _focus(position, AppConfig.mapDefaultZoom);
      await Future<void>.delayed(AppMotion.camera);
      if (mounted) await _searchThisArea();
    } else {
      final location = ref.read(locationProvider);
      if (mounted && location.message.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(location.message),
            action: location.needsSystemSettings
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: () => ref.read(locationProvider.notifier).openSettings(),
                  )
                : null,
          ));
      }
    }
  }

  Future<void> _openFilters() async {
    await showFilterSheet(context);
    if (mounted) await _search();
  }

  Future<void> _openSearch() async {
    await context.push(Routes.search);
    // The search screen applies a term (or opens a place) itself; whatever the
    // term is now is what the map should show.
    if (mounted) await _search();
  }

  /* ── build ─────────────────────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider);
    final location = ref.watch(locationProvider);
    final query = ref.watch(discoveryQueryProvider);

    // Spot counts and prices on the map are a snapshot. When the customer's own
    // booking changes — booked, parked, checked out — a spot somewhere just
    // changed hands, so the snapshot is refreshed rather than left stale.
    ref.listen(currentBookingProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (before?.id != after?.id || before?.status != after?.status) _search();
    });

    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final bottomInset = media.padding.bottom;
    final peek = ((_peekContent + bottomInset) / screenHeight).clamp(0.18, 0.5);
    final mid = math.max(peek + 0.14, 0.52);
    const full = 0.93;

    final ordered = _ordered(mapState.markers, query.sort, mapState.selectedId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        backgroundColor: AppMapStyle.base,
        // Nothing on this screen takes typing. Resizing for a keyboard that
        // belongs to the search screen on top shrank the map underneath, and the
        // search run on the way back used that smaller viewport — dropping lots
        // near the edge until the next search.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
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
                onTap: (_, __) => ref.read(mapControllerProvider.notifier).selectParking(null),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  setState(() => _mapReady = true);
                  final start = ref.read(locationProvider).position ??
                      const LatLng(AppConfig.fallbackLat, AppConfig.fallbackLng);
                  _programmaticMove = true;
                  _map.move(_centreFor(start, AppConfig.mapDefaultZoom), AppConfig.mapDefaultZoom);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _programmaticMove = false;
                    _search();
                  });
                },
              ),
              children: [
                const ParqxTileLayer(),
                if (location.hasPosition)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location.position!,
                        width: UserLocationDot.size,
                        height: UserLocationDot.size,
                        child: const UserLocationDot(),
                      ),
                    ],
                  ),
                MarkerLayer(markers: _buildMarkers(mapState.markers, mapState.selectedId)),
              ],
            ),

            // Keeps the status bar legible over busy tiles.
            const Positioned(top: 0, left: 0, right: 0, child: FadeEdge(height: 120, strength: 0.95)),

            Positioned(
              top: media.padding.top + AppSpacing.xs,
              right: AppSpacing.sm,
              child: const MapAttribution(),
            ),

            if (mapState.showSearchThisArea)
              Positioned(
                top: media.padding.top + AppSpacing.xxxl,
                left: 0,
                right: 0,
                child: Center(
                  child: _SearchThisAreaPill(
                    isLoading: mapState.isLoading,
                    onTap: _searchThisArea,
                  ),
                ),
              ),

            // Controls that ride just above the sheet and fade as it expands.
            AnimatedBuilder(
              animation: _sheet,
              builder: (context, child) {
                final extent = _sheet.isAttached ? _sheet.size : mid;
                final visibility = (1 - ((extent - mid) / (full - mid))).clamp(0.0, 1.0);
                return Positioned(
                  left: AppSpacing.pageInset,
                  right: AppSpacing.pageInset,
                  bottom: extent * screenHeight + AppSpacing.md,
                  child: IgnorePointer(
                    ignoring: visibility < 0.3,
                    child: Opacity(opacity: visibility, child: child),
                  ),
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Spacer(),
                  if (location.status == LocationStatus.requesting)
                    // Finding a fix can take several seconds; without this the
                    // button looks like it ignored the tap.
                    Semantics(
                      label: 'Finding your location',
                      child: Container(
                        width: AppSizes.mapControl,
                        height: AppSizes.mapControl,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.floating,
                        ),
                        padding: const EdgeInsets.all(14),
                        child: const CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    )
                  else
                    CircleButton(
                      icon: location.hasPosition
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      tooltip: 'Show parking near me',
                      floating: true,
                      onPressed: _recentre,
                    ),
                ],
              ),
            ),

            _DiscoverySheet(
              // No key tied to the insets: re-keying rebuilt the sheet around the
              // same controller before the old sheet let go of it — an assertion
              // on every frame of the session bar sliding in, or of a keyboard
              // opening. The sheet adopts new sizes in place.
              controller: _sheet,
              peek: peek,
              mid: mid,
              full: full,
              snapSizes: _snapSizesFor(peek, mid, full),
              results: ordered,
              isLoading: mapState.isLoading,
              error: mapState.error,
              selectedId: mapState.selectedId,
              truncated: mapState.truncated,
              location: location,
              query: query,
              bottomInset: bottomInset,
              onScrollController: (c) => _listController = c,
              onRetry: _search,
              onOpenSearch: _openSearch,
              onClearSearch: () {
                ref.read(discoveryQueryProvider.notifier).setSearchTerm(null);
                _search();
              },
              onOpenFilters: _openFilters,
              onClearFilters: () {
                ref.read(discoveryQueryProvider.notifier).clearFilters();
                _search();
              },
              onVehicleChanged: (type) {
                ref.read(discoveryQueryProvider.notifier).setVehicleType(type);
                _search();
              },
              onQuickFilter: (filter) {
                ref.read(discoveryQueryProvider.notifier).toggleQuickFilter(filter);
                _search();
              },
              onSort: (sort) => ref.read(discoveryQueryProvider.notifier).setSort(sort),
              onOpen: (parking) {
                ref.read(mapControllerProvider.notifier).selectParking(parking.id);
                context.push(Routes.parkingDetail(parking.id));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Results in the chosen order, with the selected place first.
  ///
  /// The bounds query does not take a sort, so ordering happens here — on the
  /// server's own numbers.
  List<ParkingSummary> _ordered(List<ParkingSummary> items, ParkingSort sort, int? selectedId) {
    final list = [...items];
    int bookableFirst(ParkingSummary a, ParkingSummary b) {
      final ab = a.availability.state.isBookable && a.isOpenNow ? 0 : 1;
      final bb = b.availability.state.isBookable && b.isOpenNow ? 0 : 1;
      return ab.compareTo(bb);
    }

    switch (sort) {
      case ParkingSort.distance:
        list.sort((a, b) {
          final byOpen = bookableFirst(a, b);
          if (byOpen != 0) return byOpen;
          return (a.distanceMetres ?? 1 << 30).compareTo(b.distanceMetres ?? 1 << 30);
        });
      case ParkingSort.price:
        list.sort((a, b) {
          final byOpen = bookableFirst(a, b);
          if (byOpen != 0) return byOpen;
          return a.price.hourly.paise.compareTo(b.price.hourly.paise);
        });
      case ParkingSort.availability:
        list.sort((a, b) => b.availability.availableSlots.compareTo(a.availability.availableSlots));
      case ParkingSort.rating:
      case ParkingSort.popularity:
        list.sort(bookableFirst);
    }
    if (selectedId != null) {
      final index = list.indexWhere((p) => p.id == selectedId);
      if (index > 0) list.insert(0, list.removeAt(index));
    }
    return list;
  }

  /* ── markers ───────────────────────────────────────────────────────────── */

  List<Marker> _buildMarkers(List<ParkingSummary> parkings, int? selectedId) {
    final zoom = _safeZoom;
    final clusters = _cluster(parkings, zoom);
    // Selected marker last so it draws above its neighbours.
    clusters.sort((a, b) {
      final as = a.items.length == 1 && a.items.first.id == selectedId ? 1 : 0;
      final bs = b.items.length == 1 && b.items.first.id == selectedId ? 1 : 0;
      return as.compareTo(bs);
    });
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
            onTap: () => _selectFromMap(parking),
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
          onTap: () => _moveCamera(cluster.centre, (zoom + 2).clamp(3, AppConfig.mapMaxZoom)),
        ),
      );
    }).toList(growable: false);
  }

  List<_Cluster> _cluster(List<ParkingSummary> parkings, double zoom) {
    final withPosition = parkings.where((p) => p.location.hasCoordinates).toList();
    if (zoom >= 14 || withPosition.length <= 8) {
      return withPosition
          .map((p) => _Cluster(centre: p.location.latLng!, items: [p]))
          .toList();
    }
    final shift = (zoom.round().clamp(1, 20) - 8).clamp(0, 12);
    final cellSize = 0.6 / (1 << shift);
    final buckets = <String, List<ParkingSummary>>{};
    for (final p in withPosition) {
      final key = '${(p.location.lat! / cellSize).floor()}:${(p.location.lng! / cellSize).floor()}';
      buckets.putIfAbsent(key, () => []).add(p);
    }
    return buckets.values.map((items) {
      final lat = items.map((p) => p.location.lat!).reduce((a, b) => a + b) / items.length;
      final lng = items.map((p) => p.location.lng!).reduce((a, b) => a + b) / items.length;
      return _Cluster(centre: LatLng(lat, lng), items: items);
    }).toList();
  }
}

class _Cluster {
  const _Cluster({required this.centre, required this.items});

  final LatLng centre;
  final List<ParkingSummary> items;
}

class _SearchThisAreaPill extends StatelessWidget {
  const _SearchThisAreaPill({required this.isLoading, required this.onTap});

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
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: AppRadius.chip,
          boxShadow: AppShadows.floating,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
              )
            else
              const Icon(Icons.refresh_rounded, size: 16, color: AppColors.white),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Search this area',
              style: context.text.labelMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ── the sheet ─────────────────────────────────────────────────────────────── */

class _DiscoverySheet extends StatelessWidget {
  const _DiscoverySheet({
    required this.controller,
    required this.peek,
    required this.mid,
    required this.full,
    required this.snapSizes,
    required this.results,
    required this.isLoading,
    required this.error,
    required this.selectedId,
    required this.truncated,
    required this.location,
    required this.query,
    required this.bottomInset,
    required this.onScrollController,
    required this.onRetry,
    required this.onOpenSearch,
    required this.onClearSearch,
    required this.onOpenFilters,
    required this.onClearFilters,
    required this.onVehicleChanged,
    required this.onQuickFilter,
    required this.onSort,
    required this.onOpen,
  });

  final DraggableScrollableController controller;
  final double peek;
  final double mid;
  final double full;
  final List<double> snapSizes;
  final List<ParkingSummary> results;
  final bool isLoading;
  final ApiException? error;
  final int? selectedId;
  final bool truncated;
  final LocationState location;
  final ParkingQuery query;
  final double bottomInset;
  final ValueChanged<ScrollController> onScrollController;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;
  final ValueChanged<VehicleType> onVehicleChanged;
  final ValueChanged<QuickFilter> onQuickFilter;
  final ValueChanged<ParkingSort> onSort;
  final ValueChanged<ParkingSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: mid,
      minChildSize: peek,
      maxChildSize: full,
      snap: true,
      snapSizes: snapSizes,
      builder: (context, scrollController) {
        onScrollController(scrollController);
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.sheet,
            boxShadow: AppShadows.sheet,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.sheet,
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SheetGrabber(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageInset,
                          AppSpacing.xs,
                          AppSpacing.pageInset,
                          AppSpacing.md,
                        ),
                        child: SearchPill(
                          term: query.searchTerm,
                          onTap: onOpenSearch,
                          onClear: onClearSearch,
                        ),
                      ),
                      _ChipsRow(
                        query: query,
                        hasLocation: location.hasPosition,
                        onOpenFilters: onOpenFilters,
                        onVehicleChanged: onVehicleChanged,
                        onQuickFilter: onQuickFilter,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ResultsHeader(
                        count: results.length,
                        isLoading: isLoading,
                        truncated: truncated,
                        searchTerm: query.searchTerm,
                        hasLocation: location.hasPosition,
                        sort: query.sort,
                        onSort: onSort,
                        areaLabel: results.isEmpty
                            ? null
                            : results.first.location.locality ?? results.first.location.city,
                      ),
                    ],
                  ),
                ),
                ..._body(context),
                SliverToBoxAdapter(child: SizedBox(height: bottomInset + AppSpacing.xl)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context) {
    if (error != null && results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorStateView(error: error!, onRetry: onRetry, compact: true),
        ),
      ];
    }
    if (isLoading && results.isEmpty) {
      return [
        SliverList.builder(itemCount: 3, itemBuilder: (_, __) => const ParkingCardSkeleton()),
      ];
    }
    if (results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _EmptyResults(
            query: query,
            onClearSearch: onClearSearch,
            onClearFilters: onClearFilters,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        sliver: SliverList.separated(
          itemCount: results.length,
          separatorBuilder: (_, index) => Padding(
            padding: const EdgeInsets.only(left: 94, right: AppSpacing.pageInset),
            child: (results[index].id == selectedId || results[index + 1].id == selectedId)
                ? const SizedBox(height: 1)
                : const Hairline(),
          ),
          itemBuilder: (context, index) {
            final parking = results[index];
            return EntranceFade(
              key: ValueKey(parking.id),
              index: index,
              offset: 6,
              child: ParkingCard(
                parking: parking,
                isSelected: parking.id == selectedId,
                onTap: () => onOpen(parking),
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.query,
    required this.hasLocation,
    required this.onOpenFilters,
    required this.onVehicleChanged,
    required this.onQuickFilter,
  });

  final ParkingQuery query;
  final bool hasLocation;
  final VoidCallback onOpenFilters;
  final ValueChanged<VehicleType> onVehicleChanged;
  final ValueChanged<QuickFilter> onQuickFilter;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final active = ref.read(discoveryQueryProvider.notifier).activeQuickFilter;
        final quick = [
          if (hasLocation) (QuickFilter.nearMe, Icons.near_me_outlined),
          (QuickFilter.availableNow, Icons.check_circle_outline_rounded),
          (QuickFilter.cheapest, Icons.sell_outlined),
          (QuickFilter.open24x7, Icons.schedule_rounded),
        ];
        return SizedBox(
          height: AppSizes.chipHeight + 4,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageInset),
            children: [
              Segmented<VehicleType>(
                value: query.vehicleType,
                onChanged: onVehicleChanged,
                segmentWidth: 76,
                semanticLabel: 'Vehicle type',
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
              const SizedBox(width: AppSpacing.sm),
              Center(
                child: AppFilterChip(
                  label: 'Filters',
                  icon: Icons.tune_rounded,
                  selected: query.hasFilters,
                  badgeCount: query.activeFilterCount,
                  onTap: onOpenFilters,
                ),
              ),
              for (final (filter, icon) in quick) ...[
                const SizedBox(width: AppSpacing.sm),
                Center(
                  child: AppFilterChip(
                    label: filter.label,
                    icon: icon,
                    selected: active == filter,
                    onTap: () => onQuickFilter(filter),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.isLoading,
    required this.truncated,
    required this.searchTerm,
    required this.hasLocation,
    required this.sort,
    required this.onSort,
    required this.areaLabel,
  });

  final int count;
  final bool isLoading;
  final bool truncated;
  final String? searchTerm;
  final bool hasLocation;
  final ParkingSort sort;
  final ValueChanged<ParkingSort> onSort;
  final String? areaLabel;

  static const _offered = [ParkingSort.distance, ParkingSort.price, ParkingSort.availability];

  @override
  Widget build(BuildContext context) {
    final hasTerm = searchTerm != null && searchTerm!.trim().isNotEmpty;
    final String title;
    if (isLoading && count == 0) {
      title = 'Finding parking';
    } else if (count == 0) {
      title = 'No parking here';
    } else if (hasTerm) {
      title = '$count result${count == 1 ? '' : 's'}';
    } else {
      title = '$count place${count == 1 ? '' : 's'} to park';
    }

    final String? subtitle;
    if (count == 0) {
      subtitle = null;
    } else if (hasTerm) {
      subtitle = 'For "${searchTerm!.trim()}"';
    } else if (truncated) {
      subtitle = 'Showing the closest. Zoom in for more.';
    } else if (areaLabel != null) {
      subtitle = hasLocation ? 'Near $areaLabel' : 'Around $areaLabel';
    } else {
      subtitle = null;
    }

    final effectiveSort = !hasLocation && sort == ParkingSort.distance ? null : sort;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageInset, 0, AppSpacing.sm, AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isLoading && count > 0)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (count > 1)
            PopupMenuButton<ParkingSort>(
              tooltip: 'Sort',
              initialValue: effectiveSort,
              position: PopupMenuPosition.under,
              onSelected: (value) {
                Haptics.selection();
                onSort(value);
              },
              itemBuilder: (context) => [
                for (final option in _offered)
                  if (option != ParkingSort.distance || hasLocation)
                    PopupMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: option == effectiveSort
                                ? const Icon(Icons.check_rounded, size: 18)
                                : null,
                          ),
                          Text(option.label),
                        ],
                      ),
                    ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.ink),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      effectiveSort?.label ?? 'Sort',
                      style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({
    required this.query,
    required this.onClearSearch,
    required this.onClearFilters,
  });

  final ParkingQuery query;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (query.searchTerm != null && query.searchTerm!.trim().isNotEmpty) {
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'Nothing for "${query.searchTerm!.trim()}"',
        message: 'Try an area or landmark nearby, or clear the search to browse the map.',
        compact: true,
        action: PillButton(
          label: 'Clear search',
          icon: Icons.close_rounded,
          onPressed: onClearSearch,
        ),
      );
    }
    if (query.hasFilters) {
      return EmptyStateView(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matches here',
        message: 'Nothing in this area matches your '
            '${query.activeFilterCount} filter${query.activeFilterCount == 1 ? '' : 's'}.',
        compact: true,
        action: PillButton(
          label: 'Clear filters',
          icon: Icons.close_rounded,
          onPressed: onClearFilters,
        ),
      );
    }
    return const EmptyStateView(
      icon: Icons.travel_explore_rounded,
      title: 'Try another area',
      message: 'Move the map or search for a place to see parking there.',
      compact: true,
    );
  }
}
