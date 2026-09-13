// ─────────────────────────────────────────────────────────────────────────────
// DISCOVERY PROVIDERS
//
// Location, the shared discovery query, results, and map/list selection.
//
// One query object drives Home, Explore and Search, so changing the vehicle type on
// one surface is reflected on all of them. The old app kept three unrelated copies
// of the parking list in three screens' `setState`.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../features/parking/data/parking_repository.dart';
import '../../shared/models/parking.dart';
import '../config/app_config.dart';
import '../network/api_exception.dart';
import '../utils/location_service.dart';
import 'core_providers.dart';

/* ── location ──────────────────────────────────────────────────────────────── */

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// Device location as explicit state.
///
/// Never produces a fabricated coordinate: when location is unavailable the state
/// says so and the UI shows a banner offering to enable it.
class LocationController extends StateNotifier<LocationState> {
  LocationController(this._service) : super(const LocationState.unknown());

  final LocationService _service;

  /// Called once when the app opens. Uses the last known fix for an instant first
  /// frame, then refreshes.
  Future<void> initialise() async {
    final cached = await _service.lastKnown();
    if (cached.hasPosition && mounted) state = cached;
    await refresh(requestIfDenied: false);
  }

  Future<void> refresh({bool requestIfDenied = true}) async {
    if (state.status != LocationStatus.available) {
      state = const LocationState(status: LocationStatus.requesting);
    }
    final next = await _service.resolve(requestIfDenied: requestIfDenied);
    if (mounted) state = next;
  }

  /// Explicit user action from the location banner.
  Future<void> requestPermission() => refresh(requestIfDenied: true);

  Future<void> openSettings() => _service.openSettings();
}

final locationProvider =
    StateNotifierProvider<LocationController, LocationState>((ref) {
  return LocationController(ref.watch(locationServiceProvider));
});

/* ── the shared discovery query ────────────────────────────────────────────── */

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepository(ref.watch(apiClientProvider));
});

/// Quick-filter chips on Home. Mutually exclusive, so tapping one clears the others.
enum QuickFilter {
  nearMe,
  cheapest,
  availableNow,
  open24x7;

  String get label {
    switch (this) {
      case QuickFilter.nearMe:
        return 'Near me';
      case QuickFilter.cheapest:
        return 'Cheapest';
      case QuickFilter.availableNow:
        return 'Available now';
      case QuickFilter.open24x7:
        return 'Open 24/7';
    }
  }
}

/// Owns the query every discovery surface reads.
/// Sentinel meaning "this argument was not supplied", so that an explicit `null`
/// can mean "clear this filter".
const Object _unset = Object();

class DiscoveryQueryController extends StateNotifier<ParkingQuery> {
  DiscoveryQueryController(this._ref) : super(const ParkingQuery()) {
    // Keep the query's centre in step with the device position.
    _ref.listen<LocationState>(locationProvider, (previous, next) {
      if (next.hasPosition && next.position != previous?.position) {
        state = state.copyWith(centre: next.position);
      }
    });
  }

  final Ref _ref;

  QuickFilter? _activeQuickFilter;
  QuickFilter? get activeQuickFilter => _activeQuickFilter;

  void setVehicleType(VehicleType type) {
    if (state.vehicleType == type) return;
    state = state.copyWith(vehicleType: type);
  }

  void setWindow({DateTime? startAt, int? durationMinutes}) {
    state = state.copyWith(startAt: startAt, durationMinutes: durationMinutes);
  }

  void setSearchTerm(String? term) {
    state = (term == null || term.trim().isEmpty)
        ? state.copyWith(clearSearch: true, offset: 0)
        : state.copyWith(searchTerm: term, offset: 0);
  }

  void setSort(ParkingSort sort) => state = state.copyWith(sort: sort, offset: 0);

  /// Applies a quick filter, or clears it when tapped again.
  void toggleQuickFilter(QuickFilter filter) {
    if (_activeQuickFilter == filter) {
      _activeQuickFilter = null;
      state = state.cleared();
      return;
    }

    _activeQuickFilter = filter;
    final base = state.cleared();

    switch (filter) {
      case QuickFilter.nearMe:
        state = base.copyWith(
          sort: ParkingSort.distance,
          radiusMetres: AppConfig.defaultSearchRadiusMetres,
        );
      case QuickFilter.cheapest:
        state = base.copyWith(sort: ParkingSort.price);
      case QuickFilter.availableNow:
        state = base.copyWith(availableOnly: true, openNow: true, sort: ParkingSort.availability);
      case QuickFilter.open24x7:
        state = base.copyWith(open24x7: true);
    }
  }

  /// Applies the full filter sheet in one update, so the results refetch once.
  void applyFilters({
    int? maxPricePaise,
    double? minRating,
    bool? availableOnly,
    bool? openNow,
    bool? open24x7,
    List<String>? amenities,
    int? radiusMetres,
    ParkingSort? sort,
  }) {
    _activeQuickFilter = null;
    state = state.copyWith(
      maxPricePaise: maxPricePaise,
      clearMaxPrice: maxPricePaise == null,
      minRating: minRating,
      clearMinRating: minRating == null,
      availableOnly: availableOnly ?? false,
      openNow: openNow ?? false,
      open24x7: open24x7 ?? false,
      amenities: amenities ?? const [],
      radiusMetres: radiusMetres,
      clearRadius: radiusMetres == null,
      sort: sort ?? state.sort,
      offset: 0,
    );
  }

  /// Applies a delta to an explicit base query.
  ///
  /// Used by the active-filter bar to remove ONE filter without disturbing the
  /// others. `applyFilters` replaces the whole filter set; this preserves it.
  void applyFiltersFrom(
    ParkingQuery base, {
    Object? maxPricePaise = _unset,
    Object? minRating = _unset,
    bool? availableOnly,
    bool? openNow,
    bool? open24x7,
    List<String>? amenities,
    Object? radiusMetres = _unset,
    ParkingSort? sort,
  }) {
    // `_unset` distinguishes "leave alone" from "clear this" — a plain null cannot,
    // and every one of these filters is legitimately nullable.
    final nextMaxPrice =
        identical(maxPricePaise, _unset) ? base.maxPricePaise : maxPricePaise as int?;
    final nextMinRating =
        identical(minRating, _unset) ? base.minRating : minRating as double?;
    final nextRadius =
        identical(radiusMetres, _unset) ? base.radiusMetres : radiusMetres as int?;

    _activeQuickFilter = null;
    state = base.copyWith(
      maxPricePaise: nextMaxPrice,
      clearMaxPrice: nextMaxPrice == null,
      minRating: nextMinRating,
      clearMinRating: nextMinRating == null,
      availableOnly: availableOnly ?? base.availableOnly,
      openNow: openNow ?? base.openNow,
      open24x7: open24x7 ?? base.open24x7,
      amenities: amenities ?? base.amenities,
      radiusMetres: nextRadius,
      clearRadius: nextRadius == null,
      sort: sort ?? base.sort,
      offset: 0,
    );
  }

  void clearFilters() {
    _activeQuickFilter = null;
    state = state.cleared();
  }
}

final discoveryQueryProvider =
    StateNotifierProvider<DiscoveryQueryController, ParkingQuery>((ref) {
  return DiscoveryQueryController(ref);
});

/* ── results ───────────────────────────────────────────────────────────────── */

/// Nearby parking for Home and the Explore list.
///
/// `AsyncValue` carries loading, data and error together, so a screen cannot render
/// an empty list when what actually happened was a network failure — which is
/// exactly what the old `catch (_) { parkingPlaces = []; }` produced.
final nearbyParkingProvider =
    FutureProvider.autoDispose<List<ParkingSummary>>((ref) async {
  final query = ref.watch(discoveryQueryProvider);
  final location = ref.watch(locationProvider);

  // Distance sorting needs a position; without one the server falls back to
  // popularity rather than returning an arbitrary order labelled "nearest".
  final effective = location.hasPosition
      ? query.copyWith(centre: location.position)
      : query.copyWith(sort: query.sort == ParkingSort.distance ? ParkingSort.popularity : query.sort);

  // Debounce rapid query changes (typing, chip taps) so one settled request runs.
  //
  // `ref.mounted` does not exist on an AutoDisposeFutureProviderRef in Riverpod 2,
  // so disposal is tracked explicitly. Without this the provider would keep
  // querying after the screen that wanted the result had gone.
  var disposed = false;
  ref.onDispose(() => disposed = true);

  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (disposed) return const [];

  final repository = ref.watch(parkingRepositoryProvider);
  final result = await repository.search(effective);
  return result.items;
});

/* ── map ───────────────────────────────────────────────────────────────────── */

/// Camera and marker state for Explore.
@immutable
class MapViewState {
  const MapViewState({
    this.centre,
    this.zoom = AppConfig.mapDefaultZoom,
    this.markers = const [],
    this.selectedId,
    this.isLoading = false,
    this.error,
    this.showSearchThisArea = false,
    this.truncated = false,
    this.lastQueriedCentre,
  });

  final LatLng? centre;
  final double zoom;
  final List<ParkingSummary> markers;
  final int? selectedId;
  final bool isLoading;
  final ApiException? error;

  /// Shown once the camera has moved far enough from the last query.
  final bool showSearchThisArea;

  /// True when the viewport held more lots than the cap.
  final bool truncated;

  final LatLng? lastQueriedCentre;

  ParkingSummary? get selected {
    if (selectedId == null) return null;
    for (final m in markers) {
      if (m.id == selectedId) return m;
    }
    return null;
  }

  MapViewState copyWith({
    LatLng? centre,
    double? zoom,
    List<ParkingSummary>? markers,
    int? selectedId,
    bool clearSelection = false,
    bool? isLoading,
    ApiException? error,
    bool clearError = false,
    bool? showSearchThisArea,
    bool? truncated,
    LatLng? lastQueriedCentre,
  }) =>
      MapViewState(
        centre: centre ?? this.centre,
        zoom: zoom ?? this.zoom,
        markers: markers ?? this.markers,
        selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        showSearchThisArea: showSearchThisArea ?? this.showSearchThisArea,
        truncated: truncated ?? this.truncated,
        lastQueriedCentre: lastQueriedCentre ?? this.lastQueriedCentre,
      );
}

/// Drives the Explore map: viewport queries, selection, and map/list sync.
///
/// Named `ExploreMapController` rather than `MapController` because `flutter_map`
/// exports a `MapController` of its own, and any screen using both would have an
/// ambiguous unprefixed reference.
class ExploreMapController extends StateNotifier<MapViewState> {
  ExploreMapController(this._ref) : super(const MapViewState());

  final Ref _ref;
  Timer? _debounce;

  /// Called once when Explore opens.
  Future<void> initialise() async {
    final location = _ref.read(locationProvider);
    final centre = location.position;
    if (centre != null) {
      state = state.copyWith(centre: centre);
      await searchVisibleArea(_boundsAround(centre, state.zoom));
    }
  }

  /// Reacts to camera movement. Offers "Search this area" once the user has panned
  /// meaningfully away from the last query, rather than refetching on every frame.
  void onCameraMoved({required LatLng centre, required double zoom}) {
    final last = state.lastQueriedCentre;
    final moved = last == null
        ? true
        : LocationService.distanceBetween(last, centre) >
            _viewportSpanMetres(zoom) * AppConfig.searchThisAreaThreshold;

    state = state.copyWith(centre: centre, zoom: zoom, showSearchThisArea: moved);
  }

  /// Explicit "Search this area".
  Future<void> searchVisibleArea(GeoBounds bounds) async {
    _debounce?.cancel();
    state = state.copyWith(isLoading: true, clearError: true, showSearchThisArea: false);

    try {
      final repository = _ref.read(parkingRepositoryProvider);
      final query = _ref.read(discoveryQueryProvider);
      final result = await repository.searchBounds(bounds: bounds, query: query);

      if (!mounted) return;
      state = state.copyWith(
        markers: result.items,
        isLoading: false,
        truncated: result.truncated,
        lastQueriedCentre: bounds.centre,
        // Drop a selection that is no longer on screen.
        clearSelection: state.selectedId != null &&
            !result.items.any((m) => m.id == state.selectedId),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Tapping a marker selects it; the sheet scrolls to the matching card.
  void selectParking(int? id) {
    state = id == null
        ? state.copyWith(clearSelection: true)
        : state.copyWith(selectedId: id);
  }

  /// Swiping the card carousel moves the camera to that lot.
  LatLng? centreOn(int parkingId) {
    for (final m in state.markers) {
      if (m.id == parkingId) {
        final position = m.location.latLng;
        if (position != null) {
          state = state.copyWith(selectedId: parkingId, centre: position);
        }
        return position;
      }
    }
    return null;
  }

  void recentre(LatLng position) {
    state = state.copyWith(centre: position, zoom: AppConfig.mapDefaultZoom);
  }

  /// Approximate metres visible across the viewport at a zoom level.
  /// Web-Mercator ground resolution at the equator, which is close enough for a
  /// "has the user panned far?" heuristic.
  static double _viewportSpanMetres(double zoom) {
    const equatorMetres = 40075016.686;
    final metresPerTile = equatorMetres / (1 << zoom.round().clamp(1, 22));
    return metresPerTile * 2;
  }

  /// Bounds for an initial query when the real viewport is not yet known.
  static GeoBounds _boundsAround(LatLng centre, double zoom) {
    final span = _viewportSpanMetres(zoom);
    final latDelta = span / 111320 / 2;
    final lngDelta = latDelta / (1 + centre.latitude.abs() / 90);
    return GeoBounds(
      north: centre.latitude + latDelta,
      south: centre.latitude - latDelta,
      east: centre.longitude + lngDelta,
      west: centre.longitude - lngDelta,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final mapControllerProvider =
    StateNotifierProvider.autoDispose<ExploreMapController, MapViewState>((ref) {
  return ExploreMapController(ref);
});

/* ── search ────────────────────────────────────────────────────────────────── */

/// Recent searches, kept in memory for the session.
///
/// Not persisted: the honest position is that a recents list is a convenience, and
/// storing search history deserves an explicit product decision rather than being
/// introduced as a side effect.
final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesController, List<String>>((ref) {
  return RecentSearchesController();
});

class RecentSearchesController extends StateNotifier<List<String>> {
  RecentSearchesController() : super(const []);

  static const _max = 6;

  void add(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    final next = [t, ...state.where((s) => s.toLowerCase() != t.toLowerCase())];
    state = next.take(_max).toList(growable: false);
  }

  void remove(String term) =>
      state = state.where((s) => s != term).toList(growable: false);

  void clear() => state = const [];
}

/// Search-as-you-type suggestions, debounced.
final searchSuggestionsProvider =
    FutureProvider.autoDispose.family<List<SearchSuggestion>, String>((ref, term) async {
  if (term.trim().length < 2) return const [];

  var disposed = false;
  ref.onDispose(() => disposed = true);

  await Future<void>.delayed(const Duration(milliseconds: 220));
  if (disposed) return const [];

  final repository = ref.watch(parkingRepositoryProvider);
  final location = ref.watch(locationProvider);

  return repository.suggest(term: term, centre: location.position);
});

/* ── detail ────────────────────────────────────────────────────────────────── */

/// Full detail for one lot. `family` keyed by id so two lots cache independently.
final parkingDetailProvider =
    FutureProvider.autoDispose.family<ParkingDetail, int>((ref, id) async {
  final repository = ref.watch(parkingRepositoryProvider);
  final query = ref.watch(discoveryQueryProvider);
  final location = ref.watch(locationProvider);

  // Detail is worth keeping briefly: going back and forth between the list and a
  // lot should not refetch every time.
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 2), link.close);

  return repository.getDetail(
    id: id,
    vehicleType: query.vehicleType,
    startAt: query.startAt,
    durationMinutes: query.durationMinutes,
    centre: location.position,
  );
});
