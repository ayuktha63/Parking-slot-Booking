// ─────────────────────────────────────────────────────────────────────────────
// PARKING MODELS
//
// Typed models mirroring GET /api/v1/parking*.
//
// The old app passed raw `Map<String, dynamic>` everywhere, which is precisely how
// it came to read `popularity_score`, `photo_url`, `image`, `address`, `city` and
// `state` from responses that never contained them — silently, as nulls, forever.
//
// DATA HONESTY: every field the server may genuinely lack is nullable here, and the
// UI is required to branch on it. There are no defaults that manufacture content.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'money.dart';

/// Four availability states, matching the backend's single definition.
enum AvailabilityState {
  available,
  limited,
  full,
  closed,
  unavailable;

  static AvailabilityState parse(String? raw) {
    switch (raw) {
      case 'available':
        return AvailabilityState.available;
      case 'limited':
        return AvailabilityState.limited;
      case 'full':
        return AvailabilityState.full;
      case 'closed':
        return AvailabilityState.closed;
      default:
        return AvailabilityState.unavailable;
    }
  }

  bool get isBookable => this == AvailabilityState.available || this == AvailabilityState.limited;

  String get label {
    switch (this) {
      case AvailabilityState.available:
        return 'Available';
      case AvailabilityState.limited:
        return 'Filling up';
      case AvailabilityState.full:
        return 'Full';
      case AvailabilityState.closed:
        return 'Closed';
      case AvailabilityState.unavailable:
        return 'Unavailable';
    }
  }
}

enum VehicleType {
  car,
  bike;

  static VehicleType parse(String? raw) => raw == 'bike' ? VehicleType.bike : VehicleType.car;

  String get wire => name;
  String get label => this == VehicleType.car ? 'Car' : 'Bike';
}

/// "KL 01 AB 1234" — plates are stored normalised and shown grouped. Anything
/// that does not look like an Indian registration is shown as entered.
String formatPlate(String plate) {
  final p = plate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  if (p.length < 8) return p;
  final match = RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{0,3})(\d{1,4})$').firstMatch(p);
  if (match == null) return p;
  return [match.group(1), match.group(2), match.group(3), match.group(4)]
      .where((g) => g != null && g.isNotEmpty)
      .join(' ');
}

@immutable
class ParkingLocation {
  const ParkingLocation({
    this.lat,
    this.lng,
    this.addressLine,
    this.locality,
    this.city,
    this.landmark,
    this.postalCode,
  });

  factory ParkingLocation.fromJson(Map<String, dynamic> json) => ParkingLocation(
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        addressLine: json['address_line'] as String?,
        locality: json['locality'] as String?,
        city: json['city'] as String?,
        landmark: json['landmark'] as String?,
        postalCode: json['postal_code'] as String?,
      );

  final double? lat;
  final double? lng;
  final String? addressLine;
  final String? locality;
  final String? city;
  final String? landmark;
  final String? postalCode;

  bool get hasCoordinates => lat != null && lng != null;
  LatLng? get latLng => hasCoordinates ? LatLng(lat!, lng!) : null;

  /// Best available one-line description.
  ///
  /// Returns null rather than an empty or comma-only string when nothing is known —
  /// the old Home screen rendered the literal text ", " under every greeting because
  /// it joined two absent fields.
  String? get shortAddress {
    final parts = [locality, city].where((p) => p != null && p.trim().isNotEmpty).toList();
    if (parts.isEmpty) return addressLine?.trim().isNotEmpty == true ? addressLine : null;
    return parts.join(', ');
  }

  String? get fullAddress {
    final parts = [addressLine, locality, city, postalCode]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}

@immutable
class ParkingAvailability {
  const ParkingAvailability({
    required this.vehicleType,
    required this.totalSlots,
    required this.availableSlots,
    required this.state,
  });

  factory ParkingAvailability.fromJson(Map<String, dynamic> json) => ParkingAvailability(
        vehicleType: VehicleType.parse(json['vehicle_type'] as String?),
        totalSlots: (json['total_slots'] as num?)?.toInt() ?? 0,
        availableSlots: (json['available_slots'] as num?)?.toInt() ?? 0,
        state: AvailabilityState.parse(json['state'] as String?),
      );

  final VehicleType vehicleType;
  final int totalSlots;
  final int availableSlots;
  final AvailabilityState state;

  /// "12 slots" / "1 slot" / "Full"
  String get summary {
    if (state == AvailabilityState.closed) return 'Closed';
    if (totalSlots == 0) return 'No slots';
    if (availableSlots == 0) return 'Full';
    return '$availableSlots slot${availableSlots == 1 ? '' : 's'}';
  }
}

@immutable
class ParkingPrice {
  const ParkingPrice({required this.hourly, required this.currency});

  factory ParkingPrice.fromJson(Map<String, dynamic> json) => ParkingPrice(
        hourly: Money.fromJson(json['hourly_paise']),
        currency: json['currency'] as String? ?? 'INR',
      );

  final Money hourly;
  final String currency;

  String get display => hourly.perHour();
}

@immutable
class Amenity {
  const Amenity({required this.code, required this.label, this.icon});

  factory Amenity.fromJson(Map<String, dynamic> json) => Amenity(
        code: json['code'] as String? ?? '',
        label: json['label'] as String? ?? '',
        icon: json['icon'] as String?,
      );

  final String code;
  final String label;
  final String? icon;
}

@immutable
class ParkingPhoto {
  const ParkingPhoto({required this.id, required this.url, this.caption, this.isCover = false});

  factory ParkingPhoto.fromJson(Map<String, dynamic> json) => ParkingPhoto(
        id: (json['id'] as num?)?.toInt() ?? 0,
        url: json['url'] as String? ?? '',
        caption: json['caption'] as String?,
        isCover: json['is_cover'] == true,
      );

  final int id;
  final String url;
  final String? caption;
  final bool isCover;
}

@immutable
class OpeningHours {
  const OpeningHours({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
    this.closesNextDay = false,
  });

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours(
        dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
        opensAt: json['opens_at'] as String? ?? '',
        closesAt: json['closes_at'] as String? ?? '',
        closesNextDay: json['closes_next_day'] == true,
      );

  final int dayOfWeek; // 0 = Sunday
  final String opensAt;
  final String closesAt;
  final bool closesNextDay;

  static const _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  String get dayName => _days[dayOfWeek.clamp(0, 6)];

  String get range => '${_short(opensAt)} – ${_short(closesAt)}${closesNextDay ? ' (next day)' : ''}';

  static String _short(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final suffix = h >= 12 ? 'pm' : 'am';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return m == '00' ? '$h12$suffix' : '$h12:$m$suffix';
  }
}

/// A parking area as it appears in a list or on a map marker.
@immutable
class ParkingSummary {
  const ParkingSummary({
    required this.id,
    required this.name,
    required this.location,
    required this.availability,
    required this.price,
    this.slug,
    this.distanceMetres,
    this.etaMinutes,
    this.rating,
    this.ratingCount = 0,
    this.isOpenNow = true,
    this.isOpen24x7 = false,
    this.coverPhotoUrl,
    this.amenityCodes = const [],
  });

  factory ParkingSummary.fromJson(Map<String, dynamic> json) => ParkingSummary(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Parking',
        slug: json['slug'] as String?,
        location: ParkingLocation.fromJson(
          (json['location'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        distanceMetres: (json['distance_metres'] as num?)?.toInt(),
        etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
        availability: ParkingAvailability.fromJson(
          (json['availability'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        price: ParkingPrice.fromJson(
          (json['price'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        isOpenNow: json['is_open_now'] != false,
        isOpen24x7: json['is_open_24_7'] == true,
        coverPhotoUrl: json['cover_photo_url'] as String?,
        amenityCodes: ((json['amenities'] as List?) ?? const [])
            .map((a) => a.toString())
            .toList(growable: false),
      );

  final int id;
  final String name;
  final String? slug;
  final ParkingLocation location;

  /// Null when the app has no location permission. The UI omits distance entirely
  /// rather than showing a placeholder like "-".
  final int? distanceMetres;
  final int? etaMinutes;

  final ParkingAvailability availability;
  final ParkingPrice price;

  /// Null when the lot has no reviews. The UI hides the rating row.
  final double? rating;
  final int ratingCount;

  final bool isOpenNow;
  final bool isOpen24x7;

  /// Null when the lot has no photo. The UI draws a deterministic gradient built
  /// from the name — never a stock image of an unrelated place.
  final String? coverPhotoUrl;

  final List<String> amenityCodes;

  bool get hasRating => rating != null && ratingCount > 0;
  bool get hasDistance => distanceMetres != null;
  bool get hasPhoto => coverPhotoUrl != null && coverPhotoUrl!.isNotEmpty;

  /// "800 m" / "2.4 km"
  String? get distanceLabel {
    final d = distanceMetres;
    if (d == null) return null;
    if (d < 1000) return '${(d / 10).round() * 10} m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  /// "4 min" — explicitly an estimate; the UI labels it as such.
  String? get etaLabel => etaMinutes == null ? null : '$etaMinutes min';
}

/// Full detail for the parking page.
@immutable
class ParkingDetail {
  const ParkingDetail({
    required this.summary,
    required this.pricing,
    this.description,
    this.instructions,
    this.contactPhone,
    this.photos = const [],
    this.amenities = const [],
    this.openingHours = const [],
    this.maxDurationMinutes = 1440,
    this.carSlots = 0,
    this.bikeSlots = 0,
  });

  factory ParkingDetail.fromJson(Map<String, dynamic> json) {
    final capacity = (json['capacity'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ParkingDetail(
      summary: ParkingSummary.fromJson(json),
      pricing: PriceQuote.fromJson(
        (json['pricing'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      contactPhone: json['contact_phone'] as String?,
      photos: ((json['photos'] as List?) ?? const [])
          .map((p) => ParkingPhoto.fromJson((p as Map).cast<String, dynamic>()))
          .toList(growable: false),
      amenities: ((json['amenities'] as List?) ?? const [])
          .map((a) => Amenity.fromJson((a as Map).cast<String, dynamic>()))
          .toList(growable: false),
      openingHours: ((json['opening_hours'] as List?) ?? const [])
          .map((h) => OpeningHours.fromJson((h as Map).cast<String, dynamic>()))
          .toList(growable: false),
      maxDurationMinutes: (json['max_duration_minutes'] as num?)?.toInt() ?? 1440,
      carSlots: ((capacity['car'] as Map?)?['total_slots'] as num?)?.toInt() ?? 0,
      bikeSlots: ((capacity['bike'] as Map?)?['total_slots'] as num?)?.toInt() ?? 0,
    );
  }

  final ParkingSummary summary;
  final PriceQuote pricing;
  final String? description;
  final String? instructions;
  final String? contactPhone;
  final List<ParkingPhoto> photos;
  final List<Amenity> amenities;
  final List<OpeningHours> openingHours;
  final int maxDurationMinutes;
  final int carSlots;
  final int bikeSlots;

  // Section visibility. The detail page renders a section only when it has content,
  // rather than showing an empty "Amenities" heading.
  bool get hasPhotos => photos.isNotEmpty;
  bool get hasAmenities => amenities.isNotEmpty;
  bool get hasOpeningHours => openingHours.isNotEmpty;
  bool get hasDescription => description != null && description!.trim().isNotEmpty;
  bool get hasContact => contactPhone != null && contactPhone!.trim().isNotEmpty;
}

/// A server-calculated price. The client never computes one.
@immutable
class PriceQuote {
  const PriceQuote({
    required this.hourly,
    required this.subtotal,
    required this.total,
    this.basePrice = Money.zero,
    this.platformFee = Money.zero,
    this.advancePayable = Money.zero,
    this.billedHours = 1,
    this.slotCount = 1,
    this.multiplier = 1.0,
    this.isSurge = false,
    this.demandLevel = 'low',
    this.availableSlots = 0,
    this.totalSlots = 0,
    this.startsAt,
    this.endsAt,
    this.durationMinutes = 60,
    this.currency = 'INR',
  });

  factory PriceQuote.fromJson(Map<String, dynamic> json) {
    final occupancy = (json['occupancy'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PriceQuote(
      basePrice: Money.fromJson(json['base_price_paise']),
      hourly: Money.fromJson(json['hourly_price_paise']),
      subtotal: Money.fromJson(json['subtotal_paise']),
      platformFee: Money.fromJson(json['platform_fee_paise']),
      total: Money.fromJson(json['total_paise']),
      advancePayable: Money.fromJson(json['advance_payable_paise']),
      billedHours: (json['billed_hours'] as num?)?.toInt() ?? 1,
      slotCount: (json['slot_count'] as num?)?.toInt() ?? 1,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      isSurge: json['is_surge'] == true,
      demandLevel: json['demand_level'] as String? ?? 'low',
      availableSlots: (occupancy['available_slots'] as num?)?.toInt() ?? 0,
      totalSlots: (occupancy['total_slots'] as num?)?.toInt() ?? 0,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      currency: json['currency'] as String? ?? 'INR',
    );
  }

  final Money basePrice;
  final Money hourly;
  final Money subtotal;
  final Money platformFee;
  final Money total;
  final Money advancePayable;
  final int billedHours;
  final int slotCount;
  final double multiplier;
  final bool isSurge;
  final String demandLevel;
  final int availableSlots;
  final int totalSlots;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int durationMinutes;
  final String currency;

  bool get hasPlatformFee => !platformFee.isZero;

  /// Shown next to the price when demand has pushed it up, so a surge is explained
  /// rather than merely applied.
  String? get surgeReason {
    if (!isSurge) return null;
    final pct = ((multiplier - 1) * 100).round();
    return 'Prices are $pct% higher — this lot is filling up';
  }
}
