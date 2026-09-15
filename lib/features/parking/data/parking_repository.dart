// ─────────────────────────────────────────────────────────────────────────────
// PARKING REPOSITORY
//
// The only place that knows the shape of /api/v1/parking*.
//
// All filtering, sorting, searching and distance calculation happens server-side.
// The old app downloaded every parking area in the system on each Home entry and
// then sorted, filtered and searched in Dart.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/availability.dart';
import '../../../shared/models/parking.dart';

/// Server-side query. Every field maps to a query parameter.
class ParkingQuery {
  const ParkingQuery({
    this.centre,
    this.radiusMetres,
    this.searchTerm,
    this.vehicleType = VehicleType.car,
    this.startAt,
    this.durationMinutes = 60,
    this.sort = ParkingSort.distance,
    this.maxPricePaise,
    this.minRating,
    this.availableOnly = false,
    this.openNow = false,
    this.open24x7 = false,
    this.amenities = const [],
    this.limit = 20,
    this.offset = 0,
  });

  final LatLng? centre;
  final int? radiusMetres;
  final String? searchTerm;
  final VehicleType vehicleType;
  final DateTime? startAt;
  final int durationMinutes;
  final ParkingSort sort;
  final int? maxPricePaise;
  final double? minRating;
  final bool availableOnly;
  final bool openNow;
  final bool open24x7;
  final List<String> amenities;
  final int limit;
  final int offset;

  /// Filters the user has actually applied — drives the "3 filters" badge.
  int get activeFilterCount {
    var n = 0;
    if (maxPricePaise != null) n++;
    if (minRating != null) n++;
    if (availableOnly) n++;
    if (openNow) n++;
    if (open24x7) n++;
    if (amenities.isNotEmpty) n++;
    if (radiusMetres != null) n++;
    return n;
  }

  bool get hasFilters => activeFilterCount > 0;

  Map<String, dynamic> toQueryParameters() => {
        if (centre != null) 'lat': centre!.latitude,
        if (centre != null) 'lng': centre!.longitude,
        if (radiusMetres != null) 'radius_m': radiusMetres,
        if (searchTerm != null && searchTerm!.trim().isNotEmpty) 'q': searchTerm!.trim(),
        'vehicle_type': vehicleType.wire,
        if (startAt != null) 'start_at': startAt!.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'sort': sort.wire,
        if (maxPricePaise != null) 'max_price_paise': maxPricePaise,
        if (minRating != null) 'min_rating': minRating,
        if (availableOnly) 'available_only': true,
        if (openNow) 'open_now': true,
        if (open24x7) 'open_24_7': true,
        if (amenities.isNotEmpty) 'amenities': amenities.join(','),
        'limit': limit,
        'offset': offset,
      };

  ParkingQuery copyWith({
    LatLng? centre,
    int? radiusMetres,
    bool clearRadius = false,
    String? searchTerm,
    bool clearSearch = false,
    VehicleType? vehicleType,
    DateTime? startAt,
    int? durationMinutes,
    ParkingSort? sort,
    int? maxPricePaise,
    bool clearMaxPrice = false,
    double? minRating,
    bool clearMinRating = false,
    bool? availableOnly,
    bool? openNow,
    bool? open24x7,
    List<String>? amenities,
    int? limit,
    int? offset,
  }) =>
      ParkingQuery(
        centre: centre ?? this.centre,
        radiusMetres: clearRadius ? null : (radiusMetres ?? this.radiusMetres),
        searchTerm: clearSearch ? null : (searchTerm ?? this.searchTerm),
        vehicleType: vehicleType ?? this.vehicleType,
        startAt: startAt ?? this.startAt,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        sort: sort ?? this.sort,
        maxPricePaise: clearMaxPrice ? null : (maxPricePaise ?? this.maxPricePaise),
        minRating: clearMinRating ? null : (minRating ?? this.minRating),
        availableOnly: availableOnly ?? this.availableOnly,
        openNow: openNow ?? this.openNow,
        open24x7: open24x7 ?? this.open24x7,
        amenities: amenities ?? this.amenities,
        limit: limit ?? this.limit,
        offset: offset ?? this.offset,
      );

  /// Clears every filter but keeps location, vehicle and window.
  ParkingQuery cleared() => ParkingQuery(
        centre: centre,
        vehicleType: vehicleType,
        startAt: startAt,
        durationMinutes: durationMinutes,
        sort: sort,
        limit: limit,
      );
}

enum ParkingSort {
  distance,
  price,
  rating,
  availability,
  popularity;

  String get wire => name;

  String get label {
    switch (this) {
      case ParkingSort.distance:
        return 'Nearest';
      case ParkingSort.price:
        return 'Cheapest';
      case ParkingSort.rating:
        return 'Top rated';
      case ParkingSort.availability:
        return 'Most available';
      case ParkingSort.popularity:
        return 'Popular';
    }
  }
}

/// A page of results plus the window they describe.
class ParkingSearchResult {
  const ParkingSearchResult({
    required this.items,
    required this.hasMore,
    this.truncated = false,
  });

  final List<ParkingSummary> items;
  final bool hasMore;

  /// True when a map-bounds query hit the result cap — the UI says "zoom in for more".
  final bool truncated;

  bool get isEmpty => items.isEmpty;
}

/// A search suggestion: either a specific lot or an area name.
class SearchSuggestion {
  const SearchSuggestion({
    required this.type,
    required this.title,
    this.subtitle,
    this.parkingId,
    this.position,
    this.distanceMetres,
    this.parkingCount,
  });

  final String type; // 'parking' | 'locality' | 'recent'
  final String title;
  final String? subtitle;
  final int? parkingId;
  final LatLng? position;
  final int? distanceMetres;
  final int? parkingCount;

  bool get isParking => type == 'parking';
  bool get isRecent => type == 'recent';
}

class ParkingRepository {
  ParkingRepository(this._api);

  final ApiClient _api;

  Future<ParkingSearchResult> search(ParkingQuery query) async {
    final response = await _api.raw.get<dynamic>(
      '/parking',
      queryParameters: query.toQueryParameters(),
    );

    final body = (response.data as Map).cast<String, dynamic>();
    final items = ((body['data'] as List?) ?? const [])
        .map((j) => ParkingSummary.fromJson((j as Map).cast<String, dynamic>()))
        .toList(growable: false);
    final page = ((body['meta'] as Map?)?['page'] as Map?)?.cast<String, dynamic>();

    return ParkingSearchResult(items: items, hasMore: page?['has_more'] == true);
  }

  /// Markers for the current map viewport — powers "Search this area".
  Future<ParkingSearchResult> searchBounds({
    required GeoBounds bounds,
    required ParkingQuery query,
    int limit = 100,
  }) async {
    final params = <String, dynamic>{
      ...query.toQueryParameters(),
      'north': bounds.north,
      'south': bounds.south,
      'east': bounds.east,
      'west': bounds.west,
      'limit': limit,
    }
      // A viewport query is bounded by the rectangle, not by a radius or an offset.
      ..remove('radius_m')
      ..remove('offset')
      ..remove('sort');

    final response = await _api.raw.get<dynamic>('/parking/bounds', queryParameters: params);
    final body = (response.data as Map).cast<String, dynamic>();

    final items = ((body['data'] as List?) ?? const [])
        .map((j) => ParkingSummary.fromJson((j as Map).cast<String, dynamic>()))
        .toList(growable: false);
    final meta = (body['meta'] as Map?)?.cast<String, dynamic>();

    return ParkingSearchResult(
      items: items,
      hasMore: false,
      truncated: meta?['truncated'] == true,
    );
  }

  Future<List<SearchSuggestion>> suggest({
    required String term,
    LatLng? centre,
    int limit = 8,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/parking/suggest',
      query: {
        'q': term,
        if (centre != null) 'lat': centre.latitude,
        if (centre != null) 'lng': centre.longitude,
        'limit': limit,
      },
      parse: (d) => (d as Map).cast<String, dynamic>(),
    );

    final parking = ((data['parking'] as List?) ?? const []).map((j) {
      final m = (j as Map).cast<String, dynamic>();
      final loc = (m['location'] as Map?)?.cast<String, dynamic>();
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      return SearchSuggestion(
        type: 'parking',
        title: m['name'] as String? ?? '',
        subtitle: m['subtitle'] as String?,
        parkingId: (m['id'] as num?)?.toInt(),
        position: (lat != null && lng != null) ? LatLng(lat, lng) : null,
        distanceMetres: (m['distance_metres'] as num?)?.toInt(),
      );
    });

    final localities = ((data['localities'] as List?) ?? const []).map((j) {
      final m = (j as Map).cast<String, dynamic>();
      return SearchSuggestion(
        type: 'locality',
        title: m['name'] as String? ?? '',
        subtitle: m['subtitle'] as String?,
        parkingCount: (m['parking_count'] as num?)?.toInt(),
      );
    });

    return [...parking, ...localities];
  }

  Future<ParkingDetail> getDetail({
    required int id,
    required VehicleType vehicleType,
    DateTime? startAt,
    int durationMinutes = 60,
    LatLng? centre,
  }) async {
    return _api.get<ParkingDetail>(
      '/parking/$id',
      query: {
        'vehicle_type': vehicleType.wire,
        if (startAt != null) 'start_at': startAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        if (centre != null) 'lat': centre.latitude,
        if (centre != null) 'lng': centre.longitude,
      },
      parse: (data) => ParkingDetail.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// A fresh server-calculated quote. Called whenever the user changes the window.
  Future<PriceQuote> getPricing({
    required int id,
    required VehicleType vehicleType,
    required DateTime startAt,
    required int durationMinutes,
    int slotCount = 1,
  }) async {
    return _api.get<PriceQuote>(
      '/parking/$id/pricing',
      query: {
        'vehicle_type': vehicleType.wire,
        'start_at': startAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'slot_count': slotCount,
      },
      parse: (data) => PriceQuote.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<SlotLayout> getAvailability({
    required int id,
    required VehicleType vehicleType,
    required DateTime startAt,
    required int durationMinutes,
  }) async {
    return _api.get<SlotLayout>(
      '/parking/$id/availability',
      query: {
        'vehicle_type': vehicleType.wire,
        'start_at': startAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
      },
      parse: (data) => SlotLayout.fromJson((data as Map).cast<String, dynamic>()),
    );
  }
}

/// Simple lat/lng rectangle.
///
/// Named `GeoBounds`, not `LatLngBounds`, precisely because `flutter_map` exports a
/// `LatLngBounds`: a screen importing both would have an ambiguous reference. The
/// repository also stays free of any map-package dependency this way.
class GeoBounds {
  const GeoBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  LatLng get centre => LatLng((north + south) / 2, (east + west) / 2);

  double get latSpan => (north - south).abs();
  double get lngSpan => (east - west).abs();

  /// Rough diagonal in metres — used to decide when the camera has moved far enough
  /// to offer "Search this area".
  double get approximateSpanMetres => LocationDistanceHelper.distance(
        LatLng(south, west),
        LatLng(north, east),
      );
}

class LocationDistanceHelper {
  static double distance(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b);
}
