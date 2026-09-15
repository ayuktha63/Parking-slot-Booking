// ─────────────────────────────────────────────────────────────────────────────
// MAP CANVAS
//
// A quiet light basemap — grey land, white roads, soft labels — so that the
// price markers and your location are the only strong things on it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

class ParqxTileLayer extends StatelessWidget {
  const ParqxTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final layer = TileLayer(
      urlTemplate: AppConfig.mapTileUrl,
      subdomains: AppConfig.mapTileSubdomains,
      userAgentPackageName: AppConfig.mapUserAgentPackageName,
      maxZoom: AppConfig.mapMaxZoom,
      // Only providers that serve real @2x tiles; simulating retina would
      // quadruple requests to a volunteer-run tile server.
      retinaMode: AppConfig.mapTileUrl.contains('{r}') && RetinaMode.isHighDensity(context),
      panBuffer: 1,
      tileDisplay: const TileDisplay.fadeIn(duration: AppMotion.quick, startOpacity: 0),
    );
    if (!AppConfig.mapUsesDefaultTiles) return layer;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(AppMapStyle.silver),
      child: layer,
    );
  }
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.8),
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          AppConfig.mapAttribution,
          style: context.text.labelSmall?.copyWith(
            color: AppColors.inkSecondary,
            fontSize: 9.5,
          ),
        ),
      ),
    );
  }
}

/// You are here: a blue dot with a white ring and a soft halo.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({super.key});

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your location',
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A destination pin: a black circle with a white P on a short stem.
class ParkingPin extends StatelessWidget {
  const ParkingPin({super.key});

  static const double width = 40;
  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 3),
              boxShadow: AppShadows.floating,
            ),
            alignment: Alignment.center,
            child: const Text(
              'P',
              style: TextStyle(
                fontFamily: 'InterDisplay',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
                height: 1,
              ),
            ),
          ),
          Container(width: 3, height: 12, color: AppColors.ink),
        ],
      ),
    );
  }
}

/// A non-interactive map centred on one place. Used as the header of booking
/// and session screens, where "where is it" is the first question.
class StaticPlaceMap extends StatelessWidget {
  const StaticPlaceMap({
    super.key,
    required this.position,
    this.zoom = 16,
    this.showAttribution = true,
    this.lift = 0,
  });

  final LatLng position;
  final double zoom;
  final bool showAttribution;

  /// Raises the pin this many logical pixels above the centre of the visible
  /// box, so content overlapping the bottom of the map does not cover it. Done
  /// by extending the map above the clip — the pin still marks the true point.
  final double lift;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -2 * lift,
          bottom: 0,
          child: IgnorePointer(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: position,
                initialZoom: zoom,
                backgroundColor: AppMapStyle.base,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                const ParqxTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: position,
                      width: ParkingPin.width,
                      height: ParkingPin.height,
                      alignment: Alignment.topCenter,
                      child: const ParkingPin(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showAttribution)
          const Positioned(right: AppSpacing.sm, bottom: AppSpacing.sm, child: MapAttribution()),
      ],
    );
  }
}
