// ─────────────────────────────────────────────────────────────────────────────
// MAP CANVAS — the product's signature surface
//
// PARQX renders OpenStreetMap tiles through a colour matrix that turns them into
// a near-monochrome, violet-black basemap. Same tiles, same attribution, same
// zero-API-key arrangement — art-directed.
//
// WHY THIS IS WORTH DOING
//   A stock OSM basemap is beige roads, green parks, blue water, pink motorways
//   and black labels. It is excellent cartography and terrible product surface:
//   every price marker placed on it becomes one more coloured object in an
//   already crowded field, and the user's eye has to search for the thing the
//   whole screen exists to show. Darkened and desaturated, the basemap recedes
//   to context, and the availability markers become the only saturated objects
//   on screen — which is the entire job of a parking app's map.
//
//   It is also the single most recognisable thing about the product. Two parking
//   apps showing the same OSM tiles look like the same app. This one does not.
//
// HOW
//   One `ColorFiltered` wrapping the whole tile layer, not flutter_map's
//   per-tile `tileBuilder`. Per-tile filtering allocates a saveLayer for every
//   tile on screen — sixteen or more during a pan — where this allocates one for
//   the layer. On a mid-range Android device that difference is visible in the
//   frame graph while panning.
//
//   A dark base colour sits underneath so the gap before tiles arrive is part of
//   the design rather than a white flash, and a low-opacity violet wash sits on
//   top to seat the map in the brand.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// The styled basemap. Use as the first child of every `FlutterMap` in the app,
/// so the map looks identical on Home, Explore and the detail preview.
class ParqxTileLayer extends StatelessWidget {
  const ParqxTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(AppMapStyle.desaturateDarken),
      child: TileLayer(
        urlTemplate: AppConfig.mapTileUrl,
        userAgentPackageName: AppConfig.mapUserAgentPackageName,
        maxZoom: AppConfig.mapMaxZoom,
        // Keeps tiles from being re-fetched while panning back and forth.
        panBuffer: 1,
        // NB: the pre-tile background colour lives on `MapOptions.backgroundColor`
        // in flutter_map 6+, not here. Every FlutterMap in the app sets it to
        // `AppMapStyle.base` so the instant before tiles paint is part of the
        // design rather than a flash of white.
        tileDisplay: const TileDisplay.fadeIn(
          duration: AppMotion.normal,
          startOpacity: 0,
        ),
      ),
    );
  }
}

/// The violet wash painted over the filtered tiles.
///
/// Separate from [ParqxTileLayer] because it must sit ABOVE the tiles but BELOW
/// the markers — tinting the markers too would undo the contrast the filter was
/// applied to create.
class ParqxMapTint extends StatelessWidget {
  const ParqxMapTint({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppMapStyle.tint),
        child: SizedBox.expand(),
      ),
    );
  }
}

/// OpenStreetMap attribution.
///
/// Required by the OSM tile usage policy, and not negotiable regardless of how
/// the tiles are styled — restyling is not authorship. Styled to sit quietly on
/// the dark map rather than removed or hidden.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, this.alignment = Alignment.bottomLeft});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.mapOverlayInk.withValues(alpha: 0.55),
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          AppConfig.mapAttribution,
          style: context.text.labelSmall?.copyWith(
            color: AppColors.onMapMuted,
            fontSize: 9.5,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

/// The user's own position on the dark map.
///
/// A brand-violet core inside a soft halo, with a white ring so it stays visible
/// over both dark road fill and light water. Deliberately NOT the same shape
/// language as a parking marker: this is where you are, not somewhere you can go.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({super.key});

  static const double size = 26;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your location',
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x665B34E8), blurRadius: 12, spreadRadius: 2),
            ],
          ),
        ),
      ),
    );
  }
}
